"""Alerts API — list, update, and manage triage alerts."""

from fastapi import APIRouter, Request, Query
from pydantic import BaseModel

from src.config import settings

router = APIRouter()


class AlertUpdate(BaseModel):
    status: str | None = None
    severity: str | None = None
    analyst_notes: str | None = None


@router.get("")
async def list_alerts(
    request: Request,
    severity: str | None = Query(None),
    status: str | None = Query(None),
    host: str | None = Query(None),
    time_from: str = Query("now-24h"),
    size: int = Query(50, le=200),
):
    """List alerts with optional filters."""
    es = request.app.state.es
    must_clauses: list[dict] = [
        {"range": {"created_at": {"gte": time_from}}}
    ]
    if severity:
        must_clauses.append({"term": {"severity.keyword": severity}})
    if status:
        must_clauses.append({"term": {"status.keyword": status}})
    if host:
        must_clauses.append({"term": {"hosts.keyword": host.upper()}})

    resp = await es.search(
        index=settings.alerts_index,
        query={"bool": {"must": must_clauses}},
        size=size,
        sort=[{"created_at": {"order": "desc"}}],
        ignore=[404],
    )
    hits = resp.get("hits", {}).get("hits", [])
    return [h["_source"] | {"id": h["_id"]} for h in hits]


@router.get("/{alert_id}")
async def get_alert(request: Request, alert_id: str):
    """Get a single alert by ID."""
    es = request.app.state.es
    resp = await es.get(index=settings.alerts_index, id=alert_id)
    return resp["_source"] | {"id": resp["_id"]}


@router.put("/{alert_id}")
async def update_alert(request: Request, alert_id: str, update: AlertUpdate):
    """Update alert status, severity, or notes."""
    es = request.app.state.es
    doc = {k: v for k, v in update.model_dump().items() if v is not None}
    await es.update(index=settings.alerts_index, id=alert_id, doc=doc)
    return {"id": alert_id, "updated": list(doc.keys())}
