import logging
from functools import lru_cache

from azure.identity import DefaultAzureCredential, get_bearer_token_provider

from app.config import get_settings

logger = logging.getLogger(__name__)

# Entra scope for Azure OpenAI / Cognitive Services data-plane calls.
COGNITIVE_SERVICES_SCOPE = "https://cognitiveservices.azure.com/.default"


@lru_cache
def _get_credential() -> DefaultAzureCredential:
    settings = get_settings()
    return DefaultAzureCredential(
        managed_identity_client_id=settings.azure_client_id
    )


@lru_cache
def get_openai_client():
    """Return a singleton Azure OpenAI client authenticated with Entra.

    The AI Services account has ``disableLocalAuth: true``, so only Entra token
    auth is supported (no API keys). Locally this resolves to the developer's
    ``az login`` identity; in production to the container's managed identity.
    """
    from openai import AzureOpenAI

    settings = get_settings()
    if not settings.azure_openai_endpoint:
        raise RuntimeError("AZURE_OPENAI_ENDPOINT is not configured.")

    token_provider = get_bearer_token_provider(
        _get_credential(), COGNITIVE_SERVICES_SCOPE
    )
    logger.info("Configuring Azure OpenAI client for %s.", settings.azure_openai_endpoint)
    return AzureOpenAI(
        azure_endpoint=settings.azure_openai_endpoint,
        azure_ad_token_provider=token_provider,
        api_version=settings.azure_openai_api_version,
    )


@lru_cache
def get_search_client():
    """Return a singleton Azure AI Search client authenticated with Entra."""
    from azure.search.documents import SearchClient

    settings = get_settings()
    if not settings.azure_search_endpoint:
        raise RuntimeError("AZURE_SEARCH_ENDPOINT is not configured.")

    logger.info(
        "Configuring Azure AI Search client for %s (index=%s).",
        settings.azure_search_endpoint,
        settings.azure_search_index,
    )
    return SearchClient(
        endpoint=settings.azure_search_endpoint,
        index_name=settings.azure_search_index,
        credential=_get_credential(),
    )
