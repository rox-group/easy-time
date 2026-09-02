"""Error response schema."""

from typing import Optional

from pydantic import BaseModel, Field


class ErrorResponse(BaseModel):
    """Standard error response payload."""

    detail: str = Field(..., description="Human-readable error explanation.")
    code: Optional[str] = Field(default=None, description="Optional machine-readable error code.")
