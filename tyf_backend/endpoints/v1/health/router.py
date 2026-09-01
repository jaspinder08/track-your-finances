from fastapi import APIRouter

from schemas.health import HealthCheck

router = APIRouter()


@router.get("", response_model=HealthCheck)
def get_health() -> HealthCheck:
    return HealthCheck(
        status="ok",
        version="1.0.0",
        description="tyfbackend server is running"
    )
