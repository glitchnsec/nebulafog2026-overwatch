"""Elasticsearch query tools for Agno agents."""

from datetime import datetime, timezone
from typing import Any

from elasticsearch import AsyncElasticsearch

from src.config import settings

_es: AsyncElasticsearch | None = None


def get_es() -> AsyncElasticsearch:
    global _es
    if _es is None:
        _es = AsyncElasticsearch(settings.elasticsearch_url)
    return _es


async def search_events(
    time_from: str = "now-5m",
    time_to: str = "now",
    hosts: list[str] | None = None,
    event_ids: list[int] | None = None,
    keyword: str | None = None,
    max_results: int = 50,
) -> list[dict[str, Any]]:
    """Search raw security events in Elasticsearch.

    Args:
        time_from: Start time (ES format, e.g. 'now-5m', '2026-03-14T10:00:00Z').
        time_to: End time.
        hosts: Filter by hostname (e.g. ['DOROTHY', 'WIZARD']).
        event_ids: Filter by Sysmon/Security event IDs (e.g. [1, 3, 4624]).
        keyword: Free-text search across all fields.
        max_results: Max documents to return.

    Returns:
        List of event documents.
    """
    es = get_es()
    must_clauses: list[dict] = [
        {"range": {"@timestamp": {"gte": time_from, "lte": time_to}}}
    ]
    if hosts:
        must_clauses.append({"terms": {"host.name": [h.upper() for h in hosts]}})
    if event_ids:
        must_clauses.append({"terms": {"winlog.event_id": event_ids}})
    if keyword:
        must_clauses.append({"query_string": {"query": keyword}})

    resp = await es.search(
        index=settings.winlogbeat_index,
        query={"bool": {"must": must_clauses}},
        size=max_results,
        sort=[{"@timestamp": {"order": "desc"}}],
    )
    return [hit["_source"] | {"_id": hit["_id"]} for hit in resp["hits"]["hits"]]


async def get_event_detail(event_id: str) -> dict[str, Any] | None:
    """Fetch a single event by its Elasticsearch document ID.

    Args:
        event_id: The ES _id of the document.

    Returns:
        Full event document, or None if not found.
    """
    es = get_es()
    try:
        resp = await es.get(index=settings.winlogbeat_index, id=event_id)
        return resp["_source"] | {"_id": resp["_id"]}
    except Exception:
        return None


async def aggregate_by_field(
    field: str,
    time_from: str = "now-1h",
    time_to: str = "now",
    size: int = 20,
) -> list[dict[str, Any]]:
    """Aggregate events by a field to find top values.

    Args:
        field: Field to aggregate on (e.g. 'winlog.event_data.Image',
               'host.name', 'winlog.event_id').
        time_from: Start time.
        time_to: End time.
        size: Number of top buckets to return.

    Returns:
        List of {value, count} buckets.
    """
    es = get_es()
    resp = await es.search(
        index=settings.winlogbeat_index,
        query={"range": {"@timestamp": {"gte": time_from, "lte": time_to}}},
        aggs={"top_values": {"terms": {"field": field, "size": size}}},
        size=0,
    )
    buckets = resp.get("aggregations", {}).get("top_values", {}).get("buckets", [])
    return [{"value": b["key"], "count": b["doc_count"]} for b in buckets]


async def store_alert(alert: dict[str, Any]) -> str:
    """Store a triage alert in the alerts index.

    Returns:
        The ES document ID of the stored alert.
    """
    es = get_es()
    alert.setdefault("created_at", datetime.now(timezone.utc).isoformat())
    alert.setdefault("status", "new")
    resp = await es.index(index=settings.alerts_index, document=alert)
    return resp["_id"]


async def store_investigation(investigation: dict[str, Any]) -> str:
    """Store an investigation record."""
    es = get_es()
    investigation.setdefault("created_at", datetime.now(timezone.utc).isoformat())
    investigation.setdefault("status", "open")
    resp = await es.index(index=settings.investigations_index, document=investigation)
    return resp["_id"]
