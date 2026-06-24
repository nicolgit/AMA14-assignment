from fastapi import FastAPI
from app.routers import hello
from app.routers import db

app = FastAPI(
    title="Hangar Mind API",
    version="0.1.0",
    description="Backend API for Hangar Mind MRO platform.",
)

app.include_router(hello.router, prefix="/v1")
app.include_router(db.router, prefix="/v1")


@app.get("/health")
def health():
    return {"status": "ok"}
