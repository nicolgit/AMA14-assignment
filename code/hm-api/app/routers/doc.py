from fastapi import APIRouter, HTTPException
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel, Field
from sqlalchemy import text

from app.blob import get_blob_service_client
from app.db import get_engine

router = APIRouter()

_DOC_COLUMNS = "document_id, title, type, revision, date, storage_uri, status"


class UpdateDocumentBlob(BaseModel):
    content: str = Field(description="New markdown content for the document blob.")
    title: str | None = Field(
        default=None, description="Optional new title for the document."
    )
    status: str | None = Field(
        default=None,
        description="Optional new status. Only 'published' is accepted here.",
    )


@router.get("/doc")
def list_documents():
    """Return all documents (metadata) from the ``document`` table."""
    query = text(
        f"""
        SELECT {_DOC_COLUMNS}
        FROM document
        ORDER BY document_id
        """
    )
    try:
        engine = get_engine()
        with engine.connect() as conn:
            rows = conn.execute(query).mappings().all()
    except Exception as exc:  # surface a clean 503 instead of a 500 stack trace
        raise HTTPException(status_code=503, detail=f"database unavailable: {exc}") from exc
    return [dict(row) for row in rows]


@router.get("/doc/{docid}")
def get_document(docid: str):
    """Return one document (metadata only) from the ``document`` table by id."""
    query = text(
        f"""
        SELECT {_DOC_COLUMNS}
        FROM document
        WHERE document_id = :document_id
        """
    )
    try:
        engine = get_engine()
        with engine.connect() as conn:
            row = conn.execute(query, {"document_id": docid}).mappings().first()
    except Exception as exc:  # surface a clean 503 instead of a 500 stack trace
        raise HTTPException(status_code=503, detail=f"database unavailable: {exc}") from exc

    if not row:
        raise HTTPException(status_code=404, detail=f"document {docid} not found")

    return dict(row)


@router.get("/doc/{docid}/blob", response_class=PlainTextResponse)
def get_document_blob(docid: str):
    """Return the raw markdown content of a document from Azure Blob Storage.

    The ``storage_uri`` metadata holds a path relative to the account blob
    endpoint in the form ``<container>/<blob-path>``; it is resolved against
    ``BLOB_STORAGE_URL`` to fetch the actual content.
    """
    query = text(
        """
        SELECT storage_uri
        FROM document
        WHERE document_id = :document_id
        """
    )
    try:
        engine = get_engine()
        with engine.connect() as conn:
            row = conn.execute(query, {"document_id": docid}).mappings().first()
    except Exception as exc:  # surface a clean 503 instead of a 500 stack trace
        raise HTTPException(status_code=503, detail=f"database unavailable: {exc}") from exc

    if not row:
        raise HTTPException(status_code=404, detail=f"document {docid} not found")

    storage_uri = (row["storage_uri"] or "").strip().lstrip("/")
    container, _, blob_name = storage_uri.partition("/")
    if not container or not blob_name:
        raise HTTPException(
            status_code=422,
            detail=f"document {docid} has an invalid storage_uri: {row['storage_uri']!r}",
        )

    from azure.core.exceptions import ResourceNotFoundError

    try:
        client = get_blob_service_client()
        blob_client = client.get_blob_client(container=container, blob=blob_name)
        content = blob_client.download_blob().readall()
    except ResourceNotFoundError as exc:
        raise HTTPException(
            status_code=404,
            detail=f"blob not found for document {docid}: {storage_uri}",
        ) from exc
    except Exception as exc:  # surface a clean 503 instead of a 500 stack trace
        raise HTTPException(status_code=503, detail=f"blob storage unavailable: {exc}") from exc

    return PlainTextResponse(
        content=content.decode("utf-8"),
        media_type="text/markdown; charset=utf-8",
    )


@router.put("/doc/{docid}/blob", response_class=PlainTextResponse)
def update_document_blob(docid: str, payload: UpdateDocumentBlob):
    """Overwrite the markdown content of a *draft* document in Blob Storage.

    Editing is restricted to documents whose ``status`` is ``draft`` so that
    published, human-approved data cannot be altered through this endpoint.
    """
    query = text(
        """
        SELECT storage_uri, status
        FROM document
        WHERE document_id = :document_id
        """
    )
    try:
        engine = get_engine()
        with engine.connect() as conn:
            row = conn.execute(query, {"document_id": docid}).mappings().first()
    except Exception as exc:  # surface a clean 503 instead of a 500 stack trace
        raise HTTPException(status_code=503, detail=f"database unavailable: {exc}") from exc

    if not row:
        raise HTTPException(status_code=404, detail=f"document {docid} not found")

    if (row["status"] or "").strip().lower() != "draft":
        raise HTTPException(
            status_code=409,
            detail=f"document {docid} is not a draft and cannot be edited",
        )

    storage_uri = (row["storage_uri"] or "").strip().lstrip("/")
    container, _, blob_name = storage_uri.partition("/")
    if not container or not blob_name:
        raise HTTPException(
            status_code=422,
            detail=f"document {docid} has an invalid storage_uri: {row['storage_uri']!r}",
        )

    try:
        client = get_blob_service_client()
        blob_client = client.get_blob_client(container=container, blob=blob_name)
        blob_client.upload_blob(
            payload.content.encode("utf-8"),
            overwrite=True,
            content_type="text/markdown; charset=utf-8",
        )
    except Exception as exc:  # surface a clean 503 instead of a 500 stack trace
        raise HTTPException(status_code=503, detail=f"blob storage unavailable: {exc}") from exc

    # Persist an optional title change alongside the content update.
    new_title = (payload.title or "").strip()
    if new_title:
        try:
            with engine.begin() as conn:
                conn.execute(
                    text(
                        """
                        UPDATE document
                        SET title = :title
                        WHERE document_id = :document_id
                        """
                    ),
                    {"title": new_title, "document_id": docid},
                )
        except Exception as exc:  # surface a clean 503 instead of a 500 stack trace
            raise HTTPException(status_code=503, detail=f"database unavailable: {exc}") from exc

    # Optional draft -> published transition.
    new_status = (payload.status or "").strip().lower()
    if new_status:
        if new_status != "published":
            raise HTTPException(
                status_code=422,
                detail=f"unsupported status transition: {payload.status!r}",
            )
        try:
            with engine.begin() as conn:
                conn.execute(
                    text(
                        """
                        UPDATE document
                        SET status = :status
                        WHERE document_id = :document_id
                        """
                    ),
                    {"status": "published", "document_id": docid},
                )
        except Exception as exc:  # surface a clean 503 instead of a 500 stack trace
            raise HTTPException(status_code=503, detail=f"database unavailable: {exc}") from exc

    return PlainTextResponse(
        content=payload.content,
        media_type="text/markdown; charset=utf-8",
    )
