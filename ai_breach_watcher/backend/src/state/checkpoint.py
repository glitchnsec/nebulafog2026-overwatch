"""Watcher polling state management — persisted in ES."""

from datetime import datetime, timezone

from elasticsearch import AsyncElasticsearch

from src.config import settings

CHECKPOINT_DOC_ID = "watcher-checkpoint"


async def ensure_indices(es: AsyncElasticsearch) -> None:
    """Create Breach Watcher indices if they don't exist."""
    single_node_settings = {"settings": {"number_of_replicas": 0}}
    for index in [settings.alerts_index, settings.investigations_index, settings.state_index, "breach-watcher-agent-logs", "breach-watcher-baselines"]:
        try:
            exists = await es.indices.exists(index=index)
            if not exists:
                await es.indices.create(index=index, body=single_node_settings)
        except Exception:
            try:
                await es.indices.create(index=index, body=single_node_settings)
            except Exception:
                pass  # Index may already exist


async def get_checkpoint(es: AsyncElasticsearch) -> dict:
    """Get the last poll checkpoint."""
    try:
        resp = await es.get(index=settings.state_index, id=CHECKPOINT_DOC_ID)
        return resp["_source"]
    except Exception:
        return {
            "last_poll_timestamp": "now-5m",
            "hunt_last_run": "now-30m",
        }


async def update_checkpoint(
    es: AsyncElasticsearch,
    last_poll_timestamp: str | None = None,
    hunt_last_run: str | None = None,
) -> None:
    """Update the poll checkpoint."""
    doc: dict = {}
    if last_poll_timestamp:
        doc["last_poll_timestamp"] = last_poll_timestamp
    if hunt_last_run:
        doc["hunt_last_run"] = hunt_last_run
    doc["updated_at"] = datetime.now(timezone.utc).isoformat()

    await es.index(index=settings.state_index, id=CHECKPOINT_DOC_ID, document=doc)
