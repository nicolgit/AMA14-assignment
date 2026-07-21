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

    @property
    def use_entra_auth(self) -> bool:
        """Use Entra token auth whenever no explicit connection string is set."""
        return not self.database_url


@lru_cache
def get_settings() -> Settings:
    return Settings()
