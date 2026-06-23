from fastapi import FastAPI
from app.routers import hello

app = FastAPI(
    title="Hangar Mind API",
    version="0.1.0",
    description="Backend API for Hangar Mind MRO platform.",
)

app.include_router(hello.router, prefix="/v1")


@app.get("/health")
def health():
    return {"status": "ok"}
