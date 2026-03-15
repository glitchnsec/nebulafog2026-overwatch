"""Orchestrator — polls ES on an interval, feeds events into the breach workflow."""

import asyncio
import json
import logging
import traceback
from datetime import datetime, timezone

from elasticsearch import AsyncElasticsearch

from src.config import settings
from src.state.checkpoint import get_checkpoint, update_checkpoint
from src.state.baselines import check_baselines, update_baselines
from src.tools.elastic import search_events, store_alert, store_investigation
from src.api.ws import broadcast

logger = logging.getLogger(__name__)

AGENT_LOGS_INDEX = "breach-watcher-agent-logs"


async def run_poll_loop():
    """Main polling loop — runs as a background task in the FastAPI app."""
    es = AsyncElasticsearch(settings.elasticsearch_url)
    logger.info("Orchestrator started — polling every %ds", settings.poll_interval_seconds)

    # Wait a few seconds for the app to fully start
    await asyncio.sleep(5)

    while True:
        try:
            await _poll_cycle(es)
        except Exception:
            logger.exception("Error in poll cycle")

        await asyncio.sleep(settings.poll_interval_seconds)


async def run_hunt_loop():
    """Separate hunt loop on a slower cadence."""
    es = AsyncElasticsearch(settings.elasticsearch_url)
    logger.info("Hunt loop started — running every %ds", settings.hunt_interval_seconds)

    await asyncio.sleep(30)  # Let the system warm up

    while True:
        try:
            await _hunt_cycle(es)
        except Exception:
            logger.exception("Error in hunt cycle")

        await asyncio.sleep(settings.hunt_interval_seconds)


async def _poll_cycle(es: AsyncElasticsearch):
    """Single poll cycle: fetch new events, filter baselines, run triage, broadcast results."""
    checkpoint = await get_checkpoint(es)
    last_poll = checkpoint.get("last_poll_timestamp", "now-5m")

    events = await search_events(time_from=last_poll, time_to="now", max_results=100)

    if not events:
        logger.debug("No new events since %s", last_poll)
        return

    logger.info("Found %d new events since %s", len(events), last_poll)

    now = datetime.now(timezone.utc).isoformat()
    await update_checkpoint(es, last_poll_timestamp=now)

    # --- Baseline filtering: suppress known-normal recurring events ---
    novel_events, suppressed_events, suppression_stats = await check_baselines(es, events)

    if suppressed_events:
        logger.info(
            "Baseline suppressed %d/%d events (%d unique patterns)",
            len(suppressed_events), len(events), len(suppression_stats),
        )
        await broadcast("baseline_suppressed", {
            "suppressed": len(suppressed_events),
            "total": len(events),
            "patterns": len(suppression_stats),
        })

    if not novel_events:
        logger.info("All %d events matched baselines — skipping triage", len(events))
        # Still update baselines with the suppressed events
        await update_baselines(es, suppressed_events, "low")
        return

    event_summary = _summarize_events(novel_events)
    hosts = list({e.get("host", {}).get("name", "unknown") for e in novel_events})

    # Add suppression context to the triage prompt if some events were filtered
    triage_context = ""
    if suppressed_events:
        triage_context = (
            f"\n\nNote: {len(suppressed_events)} additional events were suppressed by "
            f"baseline filtering (known-normal recurring patterns). The {len(novel_events)} "
            f"events below are novel or unusual.\n\n"
        )

    # --- Step 1: Triage ---
    triage_result = await _run_agent_step(
        es, "Triage", triage_context + event_summary, len(novel_events)
    )

    # Parse severity from triage result
    severity = _extract_severity(triage_result)
    should_escalate = severity in ("critical", "high")

    # Update baselines with triage result
    await update_baselines(es, novel_events, severity)
    if suppressed_events:
        await update_baselines(es, suppressed_events, "low")

    # Store alert
    alert = {
        "summary": triage_result[:500] if triage_result else f"Batch of {len(novel_events)} events",
        "event_count": len(novel_events),
        "suppressed_count": len(suppressed_events),
        "total_event_count": len(events),
        "hosts": hosts,
        "severity": severity,
        "status": "escalated" if should_escalate else "triaged",
        "triage_output": triage_result,
        "raw_event_ids": [e.get("_id", "") for e in novel_events[:20]],
    }
    alert_id = await store_alert(alert)
    await broadcast("new_alert", {
        "id": alert_id, "severity": severity,
        "summary": alert["summary"][:200], "hosts": hosts,
        "event_count": len(novel_events),
        "suppressed_count": len(suppressed_events),
    })
    logger.info("Alert %s created — severity: %s (suppressed %d baseline events)",
                alert_id, severity, len(suppressed_events))

    # --- Step 2: TTP Analysis (only for escalated alerts) ---
    if should_escalate:
        ttp_result = await _run_agent_step(
            es, "TTP Analysis Team",
            f"Triage found {severity} severity events. Analyze:\n\n{event_summary}",
            len(novel_events),
        )

        # --- Step 3: Responder ---
        responder_result = await _run_agent_step(
            es, "Responder",
            f"TTP Analysis:\n{ttp_result}\n\nOriginal events:\n{event_summary}",
            len(novel_events),
        )

        # Store investigation
        investigation = {
            "alert_id": alert_id,
            "hosts": hosts,
            "severity": severity,
            "triage_output": triage_result,
            "ttp_analysis": ttp_result,
            "response_plan": responder_result,
            "attack_narrative": ttp_result[:500] if ttp_result else "",
            "kill_chain_phase": _extract_phase(ttp_result),
            "tactics": _extract_tactics(ttp_result),
        }
        inv_id = await store_investigation(investigation)
        await broadcast("new_investigation", {"id": inv_id, "severity": severity, "hosts": hosts})
        logger.info("Investigation %s created for alert %s", inv_id, alert_id)


async def _hunt_cycle(es: AsyncElasticsearch):
    """Run proactive hunting on a slower cadence."""
    checkpoint = await get_checkpoint(es)
    hunt_last = checkpoint.get("hunt_last_run", "now-30m")

    events = await search_events(time_from=hunt_last, time_to="now", max_results=200)

    if not events:
        return

    logger.info("Hunt cycle: analyzing %d events", len(events))

    now = datetime.now(timezone.utc).isoformat()
    await update_checkpoint(es, hunt_last_run=now)

    event_summary = _summarize_events(events)

    hunt_result = await _run_agent_step(
        es, "Hunter",
        f"Proactively hunt through these {len(events)} events for threats the triage pipeline might miss:\n\n{event_summary}",
        len(events),
    )

    if hunt_result and "malicious" in hunt_result.lower():
        alert = {
            "summary": f"[HUNT] {hunt_result[:300]}",
            "event_count": len(events),
            "hosts": list({e.get("host", {}).get("name", "unknown") for e in events}),
            "severity": "high",
            "status": "hunt_finding",
            "hunt_output": hunt_result,
        }
        alert_id = await store_alert(alert)
        await broadcast("hunt_finding", {"id": alert_id, "summary": alert["summary"][:200]})
        logger.info("Hunt finding stored as alert %s", alert_id)


async def _run_agent_step(
    es: AsyncElasticsearch,
    agent_name: str,
    prompt: str,
    event_count: int,
) -> str:
    """Run a single agent step via Agno and log the result."""
    from agno.agent import Agent
    from agno.models.anthropic import Claude

    started_at = datetime.now(timezone.utc).isoformat()
    result = ""
    status = "completed"

    try:
        # Create a lightweight agent for this step
        agent = Agent(
            name=agent_name,
            model=Claude(id="claude-sonnet-4-5"),
            instructions=_get_instructions(agent_name),
            markdown=True,
        )

        # Run in a thread to avoid blocking the async event loop
        response = await asyncio.to_thread(agent.run, prompt)
        result = response.content if response and response.content else ""
        logger.info("Agent %s completed — %d chars output", agent_name, len(result))

    except Exception as e:
        status = "error"
        result = f"Error: {str(e)}\n{traceback.format_exc()}"
        logger.exception("Agent %s failed", agent_name)

    # Log the run to ES
    try:
        log_entry = {
            "agent_name": agent_name,
            "status": status,
            "started_at": started_at,
            "completed_at": datetime.now(timezone.utc).isoformat(),
            "event_count": event_count,
            "result_summary": result[:1000] if result else "",
            "reasoning_trace": result,
            "prompt_preview": prompt[:500],
        }
        await es.index(index=AGENT_LOGS_INDEX, document=log_entry)
    except Exception:
        logger.exception("Failed to log agent run for %s", agent_name)

    await broadcast("agent_run", {"agent": agent_name, "status": status})

    return result


def _get_instructions(agent_name: str) -> str:
    """Load instructions from skill files."""
    from pathlib import Path
    skills_dir = Path(__file__).parent.parent.parent / ".claude" / "skills"

    skill_map = {
        "Triage": "triage",
        "TTP Analysis Team": "ttp-analysts",
        "Hunter": "hunt",
        "Responder": "responder",
    }

    skill_name = skill_map.get(agent_name, agent_name.lower())
    path = skills_dir / skill_name / "SKILL.md"

    if path.exists():
        content = path.read_text()
        if content.startswith("---"):
            parts = content.split("---", 2)
            if len(parts) >= 3:
                return parts[2].strip()
        return content
    return f"You are a {agent_name} security analyst. Analyze the provided events."


def _extract_severity(triage_output: str) -> str:
    """Extract the highest severity from triage output."""
    if not triage_output:
        return "medium"
    output_lower = triage_output.lower()
    if "critical" in output_lower:
        return "critical"
    if "high" in output_lower:
        return "high"
    if "medium" in output_lower:
        return "medium"
    return "low"


def _extract_phase(ttp_output: str) -> str:
    """Extract kill chain phase from TTP analysis."""
    if not ttp_output:
        return "unknown"
    output_lower = ttp_output.lower()
    if "late" in output_lower or "impact" in output_lower:
        return "late"
    if "mid" in output_lower or "lateral" in output_lower:
        return "mid"
    if "early" in output_lower or "initial" in output_lower:
        return "early"
    return "unknown"


def _extract_tactics(ttp_output: str) -> list[str]:
    """Extract mentioned ATT&CK tactic IDs from TTP analysis."""
    import re
    if not ttp_output:
        return []
    return list(set(re.findall(r"TA\d{4}", ttp_output)))


def _summarize_events(events: list[dict]) -> str:
    """Create a text summary of events for agent consumption."""
    lines = []
    for e in events[:30]:
        ts = e.get("@timestamp", "?")
        host = e.get("host", {}).get("name", "?")
        winlog = e.get("winlog", {})
        channel = winlog.get("channel", "?")
        event_id = winlog.get("event_id", "?")
        event_data = winlog.get("event_data", {})

        if event_id == 1:
            parent = event_data.get("ParentImage", "?").split("\\")[-1]
            image = event_data.get("Image", "?").split("\\")[-1]
            cmd = event_data.get("CommandLine", "")[:150]
            user = event_data.get("User", "?")
            lines.append(f"[{ts}] {host} | Process: {parent} -> {image} | User: {user} | Cmd: {cmd}")
        elif event_id == 3:
            image = event_data.get("Image", "?").split("\\")[-1]
            dst_ip = event_data.get("DestinationIp", "?")
            dst_port = event_data.get("DestinationPort", "?")
            lines.append(f"[{ts}] {host} | Network: {image} -> {dst_ip}:{dst_port}")
        elif event_id == 10:
            src = event_data.get("SourceImage", "?").split("\\")[-1]
            tgt = event_data.get("TargetImage", "?").split("\\")[-1]
            lines.append(f"[{ts}] {host} | Process Access: {src} -> {tgt}")
        elif event_id == 11:
            fname = event_data.get("TargetFilename", "?")
            lines.append(f"[{ts}] {host} | File Created: {fname}")
        elif event_id == 4624:
            logon_type = event_data.get("LogonType", "?")
            user = event_data.get("TargetUserName", "?")
            src_ip = event_data.get("IpAddress", "?")
            lines.append(f"[{ts}] {host} | Logon Type {logon_type}: {user} from {src_ip}")
        elif event_id == 4769:
            svc = event_data.get("ServiceName", "?")
            enc = event_data.get("TicketEncryptionType", "?")
            lines.append(f"[{ts}] {host} | TGS Request: {svc} (enc: {enc})")
        elif event_id == 4648:
            sub = event_data.get("SubjectUserName", "?")
            tgt_user = event_data.get("TargetUserName", "?")
            srv = event_data.get("TargetServerName", "?")
            lines.append(f"[{ts}] {host} | Explicit Cred: {sub} -> {tgt_user}@{srv}")
        elif event_id == 4104:
            script = event_data.get("ScriptBlockText", "")[:200]
            lines.append(f"[{ts}] {host} | PowerShell: {script}")
        else:
            lines.append(f"[{ts}] {host} | {channel} Event {event_id}")

    return "\n".join(lines)
