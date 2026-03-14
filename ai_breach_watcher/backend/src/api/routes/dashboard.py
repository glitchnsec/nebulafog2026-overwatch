"""Dashboard API — aggregated stats for the UI home screen."""

from fastapi import APIRouter, Request

from src.config import settings

router = APIRouter()


async def _safe_search(es, **kwargs) -> dict:
    try:
        return await es.search(**kwargs)
    except Exception:
        return {}


async def _safe_count(es, **kwargs) -> int:
    try:
        resp = await es.count(**kwargs)
        return resp.get("count", 0)
    except Exception:
        return 0


@router.get("")
async def get_dashboard(request: Request):
    """Return overview stats: alert counts by severity, agent run status."""
    es = request.app.state.es

    alert_agg = await _safe_search(
        es,
        index=settings.alerts_index,
        query={"match_all": {}},
        aggs={
            "by_severity": {"terms": {"field": "severity.keyword", "size": 10}},
            "by_status": {"terms": {"field": "status.keyword", "size": 10}},
        },
        size=0,
    )

    severity_buckets = (
        alert_agg.get("aggregations", {}).get("by_severity", {}).get("buckets", [])
    )
    status_buckets = (
        alert_agg.get("aggregations", {}).get("by_status", {}).get("buckets", [])
    )

    inv_count = await _safe_count(
        es,
        index=settings.investigations_index,
        query={"term": {"status.keyword": "open"}},
    )

    event_count = await _safe_count(
        es,
        index=settings.winlogbeat_index,
        query={"range": {"@timestamp": {"gte": "now-5m"}}},
    )

    return {
        "alerts_by_severity": {b["key"]: b["doc_count"] for b in severity_buckets},
        "alerts_by_status": {b["key"]: b["doc_count"] for b in status_buckets},
        "open_investigations": inv_count,
        "recent_events_5m": event_count,
    }
