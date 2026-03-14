"""Investigations API — correlated incident management."""

from fastapi import APIRouter, Request, Query
from pydantic import BaseModel

from src.config import settings

router = APIRouter()


class InvestigationUpdate(BaseModel):
    status: str | None = None
    analyst_notes: str | None = None


@router.get("")
async def list_investigations(
    request: Request,
    status: str | None = Query(None),
    size: int = Query(20, le=100),
):
    """List investigations, optionally filtered by status."""
    es = request.app.state.es
    query: dict = {"match_all": {}}
    if status:
        query = {"term": {"status.keyword": status}}

    try:
        resp = await es.search(
            index=settings.investigations_index,
            query=query,
            size=size,
            sort=[{"created_at": {"order": "desc"}}],
        )
        hits = resp.get("hits", {}).get("hits", [])
        return [h["_source"] | {"id": h["_id"]} for h in hits]
    except Exception:
        return []


@router.get("/{investigation_id}")
async def get_investigation(request: Request, investigation_id: str):
    """Get a single investigation."""
    es = request.app.state.es
    resp = await es.get(index=settings.investigations_index, id=investigation_id)
    return resp["_source"] | {"id": resp["_id"]}


@router.put("/{investigation_id}")
async def update_investigation(
    request: Request, investigation_id: str, update: InvestigationUpdate
):
    """Update investigation status or notes."""
    es = request.app.state.es
    doc = {k: v for k, v in update.model_dump().items() if v is not None}
    await es.update(index=settings.investigations_index, id=investigation_id, doc=doc)
    return {"id": investigation_id, "updated": list(doc.keys())}
