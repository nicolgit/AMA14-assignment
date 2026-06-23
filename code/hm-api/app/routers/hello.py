from fastapi import APIRouter

router = APIRouter()


@router.get("/hello")
def hello():
    return {"message": "Hello from Hangar Mind API!"}
