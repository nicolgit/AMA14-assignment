import os
from functools import lru_cache


class Settings:
    """Runtime configuration resolved from environment variables.

    Two connection modes are supported:

    - Local development: set ``DATABASE_URL`` to a full connection string
      (e.g. ``postgresql://user:password@localhost:5432/hangarmind``).
    - Production (Azure Container Apps): leave ``DATABASE_URL`` unset and provide
      ``POSTGRES_HOST`` / ``POSTGRES_DATABASE`` / ``POSTGRES_USER``. The app then
      authenticates to Azure Database for PostgreSQL with the container's managed
      identity (Entra auth). ``AZURE_CLIENT_ID`` selects a specific user-assigned
      identity when more than one is available.
    """

    def __init__(self) -> None:
        self.database_url = os.getenv("DATABASE_URL")
        self.postgres_host = os.getenv("POSTGRES_HOST")
        self.postgres_database = os.getenv("POSTGRES_DATABASE")
        self.postgres_user = os.getenv("POSTGRES_USER")
        self.postgres_port = int(os.getenv("POSTGRES_PORT", "5432"))
        self.azure_client_id = os.getenv("AZURE_CLIENT_ID")
        # Account blob endpoint used to resolve document `storage_uri` values,
        # e.g. "https://lakexxxx.blob.core.windows.net".
        self.blob_storage_url = os.getenv("BLOB_STORAGE_URL")
        # Engineering Copilot: Azure OpenAI (chat) + Azure AI Search (RAG).
        # Both authenticate with Entra (no keys; the accounts have local auth off).
        self.azure_openai_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
        self.azure_openai_chat_deployment = os.getenv(
            "AZURE_OPENAI_CHAT_DEPLOYMENT", "gpt-5-6-sol"
        )
        self.azure_openai_api_version = os.getenv(
            "AZURE_OPENAI_API_VERSION", "2024-10-21"
        )
        self.azure_search_endpoint = os.getenv("AZURE_SEARCH_ENDPOINT")
        self.azure_search_index = os.getenv("AZURE_SEARCH_INDEX", "engineering-docs")
        self.azure_speech_endpoint = os.getenv("AZURE_SPEECH_ENDPOINT")
        self.azure_speech_resource_id = os.getenv("AZURE_SPEECH_RESOURCE_ID")
        self.azure_speech_languages = [
            language.strip()
            for language in os.getenv(
                "AZURE_SPEECH_LANGUAGES", "it-IT,en-US,fr-FR,de-DE"
            ).split(",")
            if language.strip()
        ][:4]

    @property
    def use_entra_auth(self) -> bool:
        """Use Entra token auth whenever no explicit connection string is set."""
        return not self.database_url


@lru_cache
def get_settings() -> Settings:
    return Settings()
