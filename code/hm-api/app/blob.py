import logging
from functools import lru_cache

from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient

from app.config import get_settings

logger = logging.getLogger(__name__)


@lru_cache
def get_blob_service_client() -> BlobServiceClient:
    """Return a process-wide singleton Blob client authenticated with Entra.

    The account blob endpoint comes from ``BLOB_STORAGE_URL`` (e.g.
    ``https://lakexxxx.blob.core.windows.net``). Locally this resolves to the
    developer's ``az login`` identity; in production to the container's managed
    identity (selected by ``AZURE_CLIENT_ID`` when several are available).
    """
    settings = get_settings()
    if not settings.blob_storage_url:
        raise RuntimeError("BLOB_STORAGE_URL is not configured.")

    credential = DefaultAzureCredential(
        managed_identity_client_id=settings.azure_client_id
    )
    logger.info("Configuring Blob client for %s.", settings.blob_storage_url)
    return BlobServiceClient(
        account_url=settings.blob_storage_url, credential=credential
    )
