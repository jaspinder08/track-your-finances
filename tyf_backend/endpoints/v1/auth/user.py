from fastapi import APIRouter

router = APIRouter()


@router.get("/check-email")
def check_email():
    return 'jaspinderkaurjk08@gmail.com'


@router.get("/login")
def login():
    return 'jaspinderkaurjk08@gmail.com'
