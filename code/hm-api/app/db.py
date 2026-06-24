import logging
from functools import lru_cache

from sqlalchemy import create_engine, event
from sqlalchemy.engine import Engine, URL

from app.config import get_settings

logger = logging.getLogger(__name__)

# Scope used to request an Entra access token for Azure Database for PostgreSQL.
AZURE_POSTGRES_SCOPE = "https://ossrdbms-aad.database.windows.net/.default"


def _build_engine() -> Engine:
    settings = get_settings()

    if not settings.use_entra_auth:
        # Local development: use the provided connection string as-is.
        # Accept the plain "postgresql://" prefix and route it to the psycopg
        # (v3) driver that is actually installed.
        url = settings.database_url
        if url.startswith("postgresql://"):
            url = url.replace("postgresql://", "postgresql+psycopg://", 1)
        logger.info("Configuring PostgreSQL engine from DATABASE_URL (local mode).")
        return create_engine(url, pool_pre_ping=True)

    # Production: connect to Azure Database for PostgreSQL with Entra auth.
    # The container runs with a managed identity; we acquire a short-lived
    # access token and use it as the connection password on every new
    # connection. DefaultAzureCredential caches and refreshes tokens internally.
    from azure.identity import DefaultAzureCredential

    if not (settings.postgres_host and settings.postgres_database and settings.postgres_user):
        raise RuntimeError(
            "Entra auth mode requires POSTGRES_HOST, POSTGRES_DATABASE and POSTGRES_USER."
        )

    credential = DefaultAzureCredential(
        managed_identity_client_id=settings.azure_client_id
    )

    url = URL.create(
        drivername="postgresql+psycopg",
        username=settings.postgres_user,
        host=settings.postgres_host,
        port=settings.postgres_port,
        database=settings.postgres_database,
        query={"sslmode": "require"},
    )

    engine = create_engine(url, pool_pre_ping=True)

    @event.listens_for(engine, "do_connect")
    def _provide_entra_token(dialect, conn_rec, cargs, cparams):  # noqa: ANN001
        token = credential.get_token(AZURE_POSTGRES_SCOPE)
        cparams["password"] = token.token

    logger.info(
        "Configuring PostgreSQL engine for %s with Entra auth (production mode).",
        settings.postgres_host,
    )
    return engine


@lru_cache
def get_engine() -> Engine:
    """Return a process-wide singleton SQLAlchemy engine."""
    return _build_engine()
