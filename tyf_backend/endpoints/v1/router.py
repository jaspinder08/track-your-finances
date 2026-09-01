from fastapi import APIRouter

from endpoints.v1.health.router import router as health
from endpoints.v1.auth.user import router as user_auth

api_router = APIRouter()
api_router.include_router(health, prefix="/health", tags=["health"])
api_router.include_router(user_auth, prefix="/user", tags=["auth"])
