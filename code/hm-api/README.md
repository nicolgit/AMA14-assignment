# Hangar Mind API

Backend API service built with **FastAPI** (Python).

## Prerequisites

- Python 3.11+ installed (`winget install -e --id Python.Python.3.12 --source winget --accept-package-agreements --accept-source-agreements`)
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

# Start with hot-reload
uvicorn app.main:app --reload --port 8080
```

API available at: `http://localhost:8080`  
Swagger docs at: `http://localhost:8080/docs`

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
