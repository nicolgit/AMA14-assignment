from fastapi import APIRouter, HTTPException
from fastapi.responses import PlainTextResponse
from sqlalchemy import text

from app.blob import get_blob_service_client
from app.db import get_engine

router = APIRouter()

_DOC_COLUMNS = "document_id, title, type, revision, date, storage_uri, status"


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
