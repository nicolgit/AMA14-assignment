"""Engineering Copilot API.

A chat endpoint that lets an engineer interact with an EASA documentation
assistant. The reasoning happens server-side: an Azure OpenAI chat model runs a
function-calling loop over tools exposed here.

Capabilities (mapped to tools):
- ``search_knowledge_base`` — retrieve task cards and maintenance manuals
  (AMM/SRM/CMM/AD/SB) from the Azure AI Search RAG index (hybrid search).
- ``generate_task_card`` — build a pre-filled DRAFT task card (JSON + markdown)
  from user-provided info and cited references.

Regulatory boundary: the AI *proposes*; a human engineer must validate. Nothing
here is an approval or a Certificate of Release to Service.
"""

import json
import logging
from datetime import date, datetime

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import text

from app.ai import get_openai_client, get_search_client
from app.blob import get_blob_service_client
from app.config import get_settings
from app.db import get_engine

logger = logging.getLogger(__name__)

router = APIRouter()

MAX_TOOL_ITERATIONS = 5
SEARCH_TOP_DEFAULT = 5
VECTOR_K = 50

# Draft task cards created from the Engineering Copilot land in the same
# ADLS Gen2 container as the seeded documents, under a dedicated ``drafts/``
# path so they are easy to tell apart from published, human-authored data.
DRAFT_CONTAINER = "engineering-docs"
DRAFT_PATH = "drafts"

SYSTEM_PROMPT = (
    "You are the Engineering Copilot for an EASA Part-145 aircraft maintenance "
    "organisation. You help engineers retrieve technical documentation and draft "
    "task cards.\n\n"
    "You can ONLY:\n"
    "1. Retrieve historical task cards from the knowledge base.\n"
    "2. Search maintenance manuals (AMM, SRM, CMM, AD, SB) in the knowledge base.\n"
    "3. Generate a pre-filled DRAFT task card from information the user provides.\n\n"
    "STRICT GROUNDING RULES:\n"
    "- Answer maintenance/documentation questions ONLY with information returned "
    "by the search_knowledge_base tool. Always call the tool before answering; "
    "never rely on prior/general knowledge.\n"
    "- Never invent task references, revisions, limits, torque values, part "
    "numbers or procedures. If the knowledge base does not contain the answer, "
    "say clearly that the information is not available in the knowledge base and "
    "do not guess.\n"
    "- Cite the source file names for every fact you provide.\n\n"
    "SCOPE RULES:\n"
    "- You must refuse any request outside aircraft maintenance documentation and "
    "task cards (e.g. jokes, general knowledge, coding, personal opinions, "
    "chit-chat). Do not answer them even partially.\n"
    "- When a request is out of scope, briefly reply that you cannot help with "
    "that and restate what you can do (the three capabilities above). Keep it to "
    "one short sentence plus the capability list.\n\n"
    "TASK CARD RULES:\n"
    "- Before generating a task card, gather the essential info (what work, on "
    "which aircraft/engine, the finding/measurements) and search for the "
    "applicable procedure. Only call generate_task_card when you have enough.\n"
    "- You PROPOSE drafts only. A human engineer validates, corrects or rejects. "
    "Never state that a card is approved or airworthy.\n\n"
    "Be concise and precise. Reply in the user's language."
)

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "search_knowledge_base",
            "description": (
                "Search the engineering knowledge base (task cards and "
                "maintenance manuals) with hybrid semantic + vector search. "
                "Use it to retrieve task cards or to find procedures in "
                "AMM/SRM/CMM/AD/SB manuals."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Natural-language search query.",
                    },
                    "category": {
                        "type": "string",
                        "enum": ["task_card", "manual", "any"],
                        "description": (
                            "Restrict results to task cards, to manuals, or "
                            "search everything (default)."
                        ),
                    },
                    "top": {
                        "type": "integer",
                        "description": "Number of results to return (1-10).",
                    },
                },
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "generate_task_card",
            "description": (
                "Generate a pre-filled DRAFT task card (routine or non-routine) "
                "from user-provided info and cited references. AI proposes; a "
                "human engineer must validate. Call only once enough info is "
                "gathered."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "card_type": {"type": "string", "enum": ["routine", "non_routine"]},
                    "title": {"type": "string"},
                    "work_order": {"type": "string"},
                    "aircraft_registration": {"type": "string"},
                    "engine_msn": {"type": "string"},
                    "ata_reference": {
                        "type": "string",
                        "description": "AMM/SRM task reference, e.g. '72-30-00-300-002 (Rev. 13)'.",
                    },
                    "finding": {
                        "type": "string",
                        "description": "Description of the work/finding, including measurements.",
                    },
                    "tooling": {"type": "array", "items": {"type": "string"}},
                    "safety": {"type": "array", "items": {"type": "string"}},
                    "steps": {"type": "array", "items": {"type": "string"}},
                    "acceptance_limits": {"type": "array", "items": {"type": "string"}},
                    "references": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "source": {"type": "string"},
                                "task_id": {"type": "string"},
                                "revision": {"type": "string"},
                                "applicability": {"type": "string"},
                            },
                        },
                    },
                },
                "required": ["card_type", "title", "finding"],
            },
        },
    },
]


class ChatMessage(BaseModel):
    role: str = Field(description="One of: user, assistant.")
    content: str


class ChatRequest(BaseModel):
    messages: list[ChatMessage] = Field(min_length=1)


class Reference(BaseModel):
    source: str
    path: str | None = None
    snippet: str | None = None


class ChatResponse(BaseModel):
    reply: str
    references: list[Reference] = []
    task_card_draft: dict | None = None
    tools_used: list[str] = []


class CreateTaskCardRequest(BaseModel):
    title: str = Field(min_length=1, description="Task card title.")
    markdown: str = Field(min_length=1, description="Rendered task card markdown.")


class CreateTaskCardResponse(BaseModel):
    document_id: str
    storage_uri: str
    status: str


# ---------------------------------------------------------------------------
# Tool implementations
# ---------------------------------------------------------------------------


def _search_knowledge_base(query: str, category: str = "any", top: int = SEARCH_TOP_DEFAULT):
    """Run hybrid (BM25 + vector) search on the RAG index and return chunks."""
    from azure.search.documents.models import VectorizableTextQuery

    top = max(1, min(int(top or SEARCH_TOP_DEFAULT), 10))

    # The dataset names task cards as ``task-card-*.md`` and manuals otherwise.
    search_filter = None
    if category == "task_card":
        search_filter = "search.ismatch('task-card', 'metadata_storage_name')"
    elif category == "manual":
        search_filter = "not search.ismatch('task-card', 'metadata_storage_name')"

    client = get_search_client()
    results = client.search(
        search_text=query,
        vector_queries=[
            VectorizableTextQuery(
                text=query, k_nearest_neighbors=VECTOR_K, fields="content_vector"
            )
        ],
        filter=search_filter,
        select=["content", "metadata_storage_name", "metadata_storage_path"],
        top=top,
    )

    items = []
    for r in results:
        items.append(
            {
                "source": r.get("metadata_storage_name"),
                "path": r.get("metadata_storage_path"),
                "content": r.get("content"),
                "score": r.get("@search.score"),
            }
        )
    return items


def _build_task_card(args: dict) -> dict:
    """Turn structured task-card fields into a draft JSON + rendered markdown."""
    card_type = args.get("card_type", "routine")
    title = args.get("title", "Untitled task card")
    references = args.get("references") or []

    draft = {
        "type": "task_card" if card_type == "routine" else "non_routine_card",
        "status": "pending_review",
        "title": title,
        "work_order": args.get("work_order"),
        "aircraft_registration": args.get("aircraft_registration"),
        "engine_msn": args.get("engine_msn"),
        "ata_reference": args.get("ata_reference"),
        "finding": args.get("finding"),
        "tooling": args.get("tooling") or [],
        "safety": args.get("safety") or [],
        "steps": args.get("steps") or [],
        "acceptance_limits": args.get("acceptance_limits") or [],
        "references": references,
    }
    draft["markdown"] = _render_task_card_markdown(draft)
    return draft


def _render_task_card_markdown(d: dict) -> str:
    kind = "Non-Routine Card (NRC)" if d["type"] == "non_routine_card" else "Routine"
    lines: list[str] = []
    lines.append(f"# DRAFT Task Card — {d['title']}")
    lines.append("")
    lines.append(
        "> **DRAFT — PENDING HUMAN REVIEW.** AI-generated proposal. Not approved "
        "data. A certifying engineer must validate, correct or reject before use."
    )
    lines.append("")
    lines.append("| Field | Value |")
    lines.append("|-------|-------|")
    lines.append(f"| Card type | {kind} |")
    lines.append(f"| Work order | {d.get('work_order') or '—'} |")
    lines.append(f"| Aircraft registration | {d.get('aircraft_registration') or '—'} |")
    lines.append(f"| Engine MSN | {d.get('engine_msn') or '—'} |")
    lines.append(f"| AMM reference | {d.get('ata_reference') or '—'} |")
    lines.append("")
    lines.append("## Finding / scope")
    lines.append(d.get("finding") or "—")
    lines.append("")

    if d.get("safety"):
        lines.append("## Safety")
        lines.extend(f"- {s}" for s in d["safety"])
        lines.append("")
    if d.get("tooling"):
        lines.append("## Required tooling")
        lines.extend(f"- {t}" for t in d["tooling"])
        lines.append("")
    if d.get("steps"):
        lines.append("## Work steps")
        lines.extend(f"{i}. {s}" for i, s in enumerate(d["steps"], start=1))
        lines.append("")
    if d.get("acceptance_limits"):
        lines.append("## Acceptance limits")
        lines.extend(f"- {a}" for a in d["acceptance_limits"])
        lines.append("")
    if d.get("references"):
        lines.append("## References")
        for ref in d["references"]:
            parts = [
                ref.get("source"),
                ref.get("task_id"),
                ref.get("revision"),
                ref.get("applicability"),
            ]
            lines.append("- " + " · ".join(p for p in parts if p))
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


# ---------------------------------------------------------------------------
# Chat endpoint (function-calling agent loop)
# ---------------------------------------------------------------------------


@router.post("/engineering/chat", response_model=ChatResponse)
def engineering_chat(payload: ChatRequest):
    settings = get_settings()

    messages: list[dict] = [{"role": "system", "content": SYSTEM_PROMPT}]
    for m in payload.messages:
        role = m.role if m.role in ("user", "assistant") else "user"
        messages.append({"role": role, "content": m.content})

    references_by_source: dict[str, Reference] = {}
    task_card_draft: dict | None = None
    tools_used: list[str] = []
    has_searched = False

    try:
        client = get_openai_client()

        for _ in range(MAX_TOOL_ITERATIONS):
            # Grounding guard: force a knowledge-base search before the model is
            # allowed to produce any free-text answer. This makes it impossible
            # to reply from the model's own knowledge without consulting the RAG.
            if has_searched:
                tool_choice = "auto"
            else:
                tool_choice = {
                    "type": "function",
                    "function": {"name": "search_knowledge_base"},
                }

            completion = client.chat.completions.create(
                model=settings.azure_openai_chat_deployment,
                messages=messages,
                tools=TOOLS,
                tool_choice=tool_choice,
            )
            choice = completion.choices[0].message
            tool_calls = choice.tool_calls or []

            if not tool_calls:
                return ChatResponse(
                    reply=choice.content or "",
                    references=list(references_by_source.values()),
                    task_card_draft=task_card_draft,
                    tools_used=tools_used,
                )

            # Record the assistant turn that requested the tool calls.
            messages.append(
                {
                    "role": "assistant",
                    "content": choice.content,
                    "tool_calls": [
                        {
                            "id": tc.id,
                            "type": "function",
                            "function": {
                                "name": tc.function.name,
                                "arguments": tc.function.arguments,
                            },
                        }
                        for tc in tool_calls
                    ],
                }
            )

            for tc in tool_calls:
                name = tc.function.name
                tools_used.append(name)
                try:
                    args = json.loads(tc.function.arguments or "{}")
                except json.JSONDecodeError:
                    args = {}

                if name == "search_knowledge_base":
                    has_searched = True
                    hits = _search_knowledge_base(
                        query=args.get("query", ""),
                        category=args.get("category", "any"),
                        top=args.get("top", SEARCH_TOP_DEFAULT),
                    )
                    for h in hits:
                        src = h.get("source")
                        if src and src not in references_by_source:
                            references_by_source[src] = Reference(
                                source=src,
                                path=h.get("path"),
                                snippet=(h.get("content") or "")[:300],
                            )
                    tool_result = json.dumps(hits, ensure_ascii=False)

                elif name == "generate_task_card":
                    task_card_draft = _build_task_card(args)
                    tool_result = json.dumps(task_card_draft, ensure_ascii=False)

                else:
                    tool_result = json.dumps({"error": f"unknown tool {name}"})

                messages.append(
                    {
                        "role": "tool",
                        "tool_call_id": tc.id,
                        "content": tool_result,
                    }
                )

        # Loop budget exhausted without a final assistant message.
        raise HTTPException(
            status_code=504,
            detail="engineering copilot did not converge within the tool budget",
        )

    except HTTPException:
        raise
    except Exception as exc:  # surface a clean 503 instead of a 500 stack trace
        logger.exception("engineering chat failed")
        raise HTTPException(status_code=503, detail=f"engineering copilot unavailable: {exc}") from exc


# ---------------------------------------------------------------------------
# Task-card creation (promote a draft into a reviewable document)
# ---------------------------------------------------------------------------


def _unique_document_id(conn, base_id: str) -> str:
    """Return ``base_id`` or, if it already exists, a suffixed variant.

    The requested naming scheme (``task-YYYY-MM-DD-HH-MM``) has minute
    resolution, so two cards created within the same minute would collide on the
    primary key. We append ``-2``, ``-3``, … until we find a free id.
    """
    check = text("SELECT 1 FROM document WHERE document_id = :id")
    candidate = base_id
    suffix = 2
    while conn.execute(check, {"id": candidate}).first() is not None:
        candidate = f"{base_id}-{suffix}"
        suffix += 1
    return candidate


@router.post("/engineering/task-card", response_model=CreateTaskCardResponse)
def create_task_card(payload: CreateTaskCardRequest):
    """Persist a draft task card as a document.

    Writes the markdown to Blob Storage and inserts a matching row in the
    ``document`` table with ``status = 'draft'``. The new ``document_id`` lets
    the SPA open the card in the document detail view straight away.
    """
    now = datetime.now()
    base_id = f"task-{now:%Y-%m-%d-%H-%M}"

    try:
        engine = get_engine()
        with engine.begin() as conn:
            document_id = _unique_document_id(conn, base_id)
            blob_name = f"{DRAFT_PATH}/{document_id}.md"
            storage_uri = f"{DRAFT_CONTAINER}/{blob_name}"

            # Upload the markdown first; if the DB insert fails the transaction
            # rolls back. The blob is written with overwrite so it stays
            # idempotent even on a retry.
            try:
                client = get_blob_service_client()
                blob_client = client.get_blob_client(
                    container=DRAFT_CONTAINER, blob=blob_name
                )
                blob_client.upload_blob(
                    payload.markdown.encode("utf-8"),
                    overwrite=True,
                    content_type="text/markdown; charset=utf-8",
                )
            except HTTPException:
                raise
            except Exception as exc:
                logger.exception("task card blob upload failed")
                raise HTTPException(
                    status_code=503, detail=f"blob storage unavailable: {exc}"
                ) from exc

            conn.execute(
                text(
                    """
                    INSERT INTO document
                        (document_id, title, type, revision, date, storage_uri, status)
                    VALUES
                        (:document_id, :title, :type, :revision, :date, :storage_uri, :status)
                    """
                ),
                {
                    "document_id": document_id,
                    "title": payload.title,
                    "type": "Task Card",
                    "revision": "Draft",
                    "date": date.today(),
                    "storage_uri": storage_uri,
                    "status": "draft",
                },
            )
    except HTTPException:
        raise
    except Exception as exc:  # surface a clean 503 instead of a 500 stack trace
        logger.exception("task card creation failed")
        raise HTTPException(status_code=503, detail=f"database unavailable: {exc}") from exc

    return CreateTaskCardResponse(
        document_id=document_id, storage_uri=storage_uri, status="draft"
    )
