# Hangar Mind API

Backend API service built with **FastAPI** (Python).

## Prerequisites

- Python 3.11+ amd64 installed 
- During installation, check **"Add Python to PATH"**

## Setup (first time or after pulling new dependencies)

```powershell
cd code/hm-api

# Create virtual environment
python -m venv .venv

# Activate it (PowerShell)
.\.venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt
```

> **Tip:** when the venv is active you'll see `(.venv)` at the start of your prompt.

## Run the server

```powershell
# Activate venv (if not already active)
.\.venv\Scripts\Activate.ps1

# Start with hot-reload - DEVELOPMENT
$env:CORS_ORIGINS = "http://localhost:5173"
$env:DATABASE_URL = "postgresql://nicola:PassGres123!@pg-amamrodeve0703.postgres.database.azure.com:5432/hangarmind"

uvicorn app.main:app --reload --port 8080
```

API available at: `http://localhost:8080`  
Swagger docs at: `http://localhost:8080/docs`

## Database connectivity (PostgreSQL)

The API connects to PostgreSQL in two mutually exclusive modes, selected purely by environment variables. Check the connection with `GET /v1/db/ping`.

### Local development — explicit connection string

Set a single `DATABASE_URL` with embedded credentials:

The `postgresql://` prefix is automatically routed to the installed `psycopg` (v3) driver.

### Production — Entra auth via managed identity

When `DATABASE_URL` is **not** set, the app authenticates to Azure Database for PostgreSQL using the container's managed identity (no passwords). It acquires a short-lived Entra token and uses it as the connection password on every new connection. These variables are injected by the Container Apps deployment:

| Variable | Purpose |
|----------|---------|
| `POSTGRES_HOST` | Server FQDN (e.g. `pg-xxx.postgres.database.azure.com`) |
| `POSTGRES_DATABASE` | Database name |
| `POSTGRES_USER` | Entra principal name (the managed identity name) |
| `AZURE_CLIENT_ID` | Client ID of the user-assigned identity to use |
| `POSTGRES_PORT` | Optional, defaults to `5432` |

`sslmode=require` is enforced automatically in this mode.

## CORS (frontend access)

The SPA (`hm-app`) runs on a different origin, so cross-origin requests must be allowed. Configure the allowed origins via the `CORS_ORIGINS` environment variable (comma-separated). It defaults to the local Vite dev server.

| Variable | Purpose |
|----------|---------|
| `CORS_ORIGINS` | Comma-separated allowed origins. Defaults to `http://localhost:5173` |


## Run in debug mode (VS Code)

1. Open the `hm-api` folder in VS Code
2. Install the **Python** extension (if not already)
3. Select the interpreter: `Ctrl+Shift+P` → "Python: Select Interpreter" → choose `.venv`
4. Create/use this launch config (`.vscode/launch.json`):

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug API",
      "type": "debugpy",
      "request": "launch",
      "module": "uvicorn",
      "args": ["app.main:app", "--reload", "--port", "8080"],
      "cwd": "${workspaceFolder}",
      "env": { "PYTHONDONTWRITEBYTECODE": "1" }
    }
  ]
}
```

5. Press `F5` to start debugging (breakpoints work!)

## Project structure

```
hm-api/
├── app/
│   ├── __init__.py
│   ├── main.py            ← FastAPI app entry point
│   └── routers/
│       ├── __init__.py
│       └── hello.py       ← GET /v1/hello
├── requirements.txt
└── README.md
```

## Useful commands

| Action | Command |
|--------|---------|
| Activate venv | `.\.venv\Scripts\Activate.ps1` |
| Deactivate venv | `deactivate` |
| Add a package | `pip install <pkg>` then `pip freeze > requirements.txt` |
| Check running server | `curl http://localhost:8080/health` |
