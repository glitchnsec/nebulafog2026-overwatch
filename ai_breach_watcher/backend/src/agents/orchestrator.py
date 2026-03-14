"""Orchestrator — polls ES on an interval, feeds events into the breach workflow."""

import asyncio
import json
import logging
from datetime import datetime, timezone

from elasticsearch import AsyncElasticsearch

from src.config import settings
from src.state.checkpoint import get_checkpoint, update_checkpoint
from src.tools.elastic import search_events, store_alert
from src.api.ws import broadcast

logger = logging.getLogger(__name__)


async def run_poll_loop():
    """Main polling loop — runs as a background task in the FastAPI app."""
    es = AsyncElasticsearch(settings.elasticsearch_url)
    logger.info("Orchestrator started — polling every %ds", settings.poll_interval_seconds)

    while True:
        try:
            await _poll_cycle(es)
        except Exception:
            logger.exception("Error in poll cycle")

        await asyncio.sleep(settings.poll_interval_seconds)


async def _poll_cycle(es: AsyncElasticsearch):
    """Single poll cycle: fetch new events, run triage, broadcast results."""
    checkpoint = await get_checkpoint(es)
    last_poll = checkpoint.get("last_poll_timestamp", "now-5m")

    # Fetch new events since last poll
    events = await search_events(time_from=last_poll, time_to="now", max_results=100)

    if not events:
        logger.debug("No new events since %s", last_poll)
        return

    logger.info("Found %d new events since %s", len(events), last_poll)

    # Update checkpoint immediately
    now = datetime.now(timezone.utc).isoformat()
    await update_checkpoint(es, last_poll_timestamp=now)

    # Build event summary for the workflow
    event_summary = _summarize_events(events)

    # For now, store a placeholder alert — the full workflow integration
    # will feed this through triage -> TTP team -> responder
    alert = {
        "summary": f"Batch of {len(events)} events detected",
        "event_count": len(events),
        "hosts": list({e.get("host", {}).get("name", "unknown") for e in events}),
        "severity": "pending_triage",
        "raw_event_ids": [e.get("_id", "") for e in events[:20]],
        "event_summary": event_summary,
    }
    alert_id = await store_alert(alert)

    # Broadcast to connected UI clients
    await broadcast("new_alert", {"id": alert_id, **alert})

    logger.info("Alert %s created with %d events", alert_id, len(events))


def _summarize_events(events: list[dict]) -> str:
    """Create a text summary of events for agent consumption."""
    lines = []
    for e in events[:30]:  # Limit to avoid token overflow
        ts = e.get("@timestamp", "?")
        host = e.get("host", {}).get("name", "?")
        winlog = e.get("winlog", {})
        channel = winlog.get("channel", "?")
        event_id = winlog.get("event_id", "?")
        event_data = winlog.get("event_data", {})

        if event_id == 1:  # Process creation
            parent = event_data.get("ParentImage", "?").split("\\")[-1]
            image = event_data.get("Image", "?").split("\\")[-1]
            cmd = event_data.get("CommandLine", "")[:150]
            user = event_data.get("User", "?")
            lines.append(f"[{ts}] {host} | Process: {parent} -> {image} | User: {user} | Cmd: {cmd}")
        elif event_id == 3:  # Network
            image = event_data.get("Image", "?").split("\\")[-1]
            dst_ip = event_data.get("DestinationIp", "?")
            dst_port = event_data.get("DestinationPort", "?")
            lines.append(f"[{ts}] {host} | Network: {image} -> {dst_ip}:{dst_port}")
        elif event_id == 10:  # Process access
            src = event_data.get("SourceImage", "?").split("\\")[-1]
            tgt = event_data.get("TargetImage", "?").split("\\")[-1]
            lines.append(f"[{ts}] {host} | Process Access: {src} -> {tgt}")
        elif event_id == 11:  # File creation
            fname = event_data.get("TargetFilename", "?")
            lines.append(f"[{ts}] {host} | File Created: {fname}")
        elif event_id == 4624:  # Logon
            logon_type = event_data.get("LogonType", "?")
            user = event_data.get("TargetUserName", "?")
            src_ip = event_data.get("IpAddress", "?")
            lines.append(f"[{ts}] {host} | Logon Type {logon_type}: {user} from {src_ip}")
        elif event_id == 4769:  # TGS request
            svc = event_data.get("ServiceName", "?")
            enc = event_data.get("TicketEncryptionType", "?")
            lines.append(f"[{ts}] {host} | TGS Request: {svc} (enc: {enc})")
        elif event_id == 4648:  # Explicit credential
            sub = event_data.get("SubjectUserName", "?")
            tgt = event_data.get("TargetUserName", "?")
            srv = event_data.get("TargetServerName", "?")
            lines.append(f"[{ts}] {host} | Explicit Cred: {sub} -> {tgt}@{srv}")
        elif event_id == 4104:  # PowerShell script block
            script = event_data.get("ScriptBlockText", "")[:200]
            lines.append(f"[{ts}] {host} | PowerShell: {script}")
        else:
            lines.append(f"[{ts}] {host} | {channel} Event {event_id}")

    return "\n".join(lines)
