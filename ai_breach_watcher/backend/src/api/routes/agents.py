"""Agents API — run history, status, and logs."""

from fastapi import APIRouter, Request, Query

router = APIRouter()

AGENT_LOGS_INDEX = "breach-watcher-agent-logs"


@router.get("")
async def list_agent_runs(
    request: Request,
    agent_name: str | None = Query(None),
    size: int = Query(30, le=100),
):
    """List recent agent runs with their status and reasoning traces."""
    es = request.app.state.es

    query: dict = {"match_all": {}}
    if agent_name:
        query = {"term": {"agent_name.keyword": agent_name}}

    try:
        resp = await es.search(
            index=AGENT_LOGS_INDEX,
            query=query,
            size=size,
            sort=[{"started_at": {"order": "desc"}}],
        )
        hits = resp.get("hits", {}).get("hits", [])
        return [h["_source"] | {"id": h["_id"]} for h in hits]
    except Exception:
        return []


@router.get("/status/current")
async def agent_status(request: Request):
    """Get current status of all agents (last run time, result)."""
    es = request.app.state.es
    try:
        resp = await es.search(
            index=AGENT_LOGS_INDEX,
            query={"match_all": {}},
            aggs={
                "by_agent": {
                    "terms": {"field": "agent_name.keyword", "size": 20},
                    "aggs": {
                        "latest": {
                            "top_hits": {
                                "size": 1,
                                "sort": [{"started_at": {"order": "desc"}}],
                            }
                        }
                    },
                }
            },
            size=0,
        )
        buckets = resp.get("aggregations", {}).get("by_agent", {}).get("buckets", [])
        return [
            {
                "agent_name": b["key"],
                "last_run": b["latest"]["hits"]["hits"][0]["_source"]
                if b["latest"]["hits"]["hits"]
                else None,
            }
            for b in buckets
        ]
    except Exception:
        return []


@router.get("/{run_id}")
async def get_agent_run(request: Request, run_id: str):
    """Get full details of a single agent run including reasoning trace."""
    es = request.app.state.es
    resp = await es.get(index=AGENT_LOGS_INDEX, id=run_id)
    return resp["_source"] | {"id": resp["_id"]}
