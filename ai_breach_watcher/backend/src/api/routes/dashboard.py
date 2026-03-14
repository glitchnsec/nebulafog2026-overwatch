"""Dashboard API — aggregated stats for the UI home screen."""

from fastapi import APIRouter, Request

from src.config import settings

router = APIRouter()


@router.get("")
async def get_dashboard(request: Request):
    """Return overview stats: alert counts by severity, agent run status."""
    es = request.app.state.es

    # Alert counts by severity
    alert_agg = await es.search(
        index=settings.alerts_index,
        query={"match_all": {}},
        aggs={
            "by_severity": {"terms": {"field": "severity.keyword", "size": 10}},
            "by_status": {"terms": {"field": "status.keyword", "size": 10}},
        },
        size=0,
        ignore=[404],
    )

    severity_buckets = (
        alert_agg.get("aggregations", {}).get("by_severity", {}).get("buckets", [])
    )
    status_buckets = (
        alert_agg.get("aggregations", {}).get("by_status", {}).get("buckets", [])
    )

    # Open investigations count
    inv_count = await es.count(
        index=settings.investigations_index,
        query={"term": {"status.keyword": "open"}},
        ignore=[404],
    )

    # Recent events count (last 5 min)
    event_count = await es.count(
        index=settings.winlogbeat_index,
        query={"range": {"@timestamp": {"gte": "now-5m"}}},
        ignore=[404],
    )

    return {
        "alerts_by_severity": {b["key"]: b["doc_count"] for b in severity_buckets},
        "alerts_by_status": {b["key"]: b["doc_count"] for b in status_buckets},
        "open_investigations": inv_count.get("count", 0),
        "recent_events_5m": event_count.get("count", 0),
    }
