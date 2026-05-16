from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.db.sqlite import get_db
from app.db import crud
from app.schemas.user import UserCreateRequest, UserResponse, UserStatsResponse

router = APIRouter(prefix="/api/user", tags=["user"])


@router.post("", response_model=UserResponse, status_code=201)
def create_user(request: UserCreateRequest, db: Session = Depends(get_db)):
    user = crud.create_user(db, display_name=request.display_name, email=request.email)
    return UserResponse(user_id=user.id, display_name=user.display_name, email=user.email)


@router.get("/stats", response_model=UserStatsResponse)
def get_user_stats(user_id: int = Query(1), db: Session = Depends(get_db)):
    crud.get_or_create_user(db, user_id)
    stats = crud.get_user_stats(db, user_id)
    return UserStatsResponse(user_id=user_id, **stats)
