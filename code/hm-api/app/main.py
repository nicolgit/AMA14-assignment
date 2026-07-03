import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import hello
from app.routers import db
from app.routers import aircraft
from app.routers import engine
from app.routers import predictions
from app.routers import evaluations

app = FastAPI(
    title="Hangar Mind API",
    version="0.1.0",
    description="Backend API for Hangar Mind MRO platform.",
)

# Comma-separated list of allowed SPA origins, e.g.
# "https://hm-app.prod,https://staging.hm-app". Defaults to the local Vite dev server.
cors_origins = [
    o.strip()
    for o in os.getenv("CORS_ORIGINS", "http://localhost:5173").split(",")
    if o.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(hello.router, prefix="/v1")
app.include_router(db.router, prefix="/v1")
app.include_router(aircraft.router, prefix="/v1")
app.include_router(engine.router, prefix="/v1")
app.include_router(predictions.router, prefix="/v1")
app.include_router(evaluations.router, prefix="/v1")


@app.get("/health")
def health():
    return {"status": "ok"}
