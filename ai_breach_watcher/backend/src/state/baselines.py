"""Event fingerprinting and baseline tracking.

Collapses recurring "normal" events so the triage agent only sees
novel or unusual activity. Fingerprints capture the *shape* of an event
(event type, process lineage, network destination port, logon type, etc.)
while stripping volatile fields like timestamps and unique IDs.

A fingerprint that has been seen many times and was previously triaged as
low/benign is suppressed. If the same shape suddenly appears on a new host
or with a new user, it's treated as novel.
"""

import hashlib
import logging
from datetime import datetime, timezone

from elasticsearch import AsyncElasticsearch

logger = logging.getLogger(__name__)

BASELINES_INDEX = "breach-watcher-baselines"

# After this many sightings with low severity, suppress the event
SUPPRESSION_THRESHOLD = 5


def fingerprint_event(event: dict) -> str | None:
    """Generate a stable fingerprint for an event based on its shape.

    Returns None for events that can't be meaningfully fingerprinted.
    """
    winlog = event.get("winlog", {})
    event_id = winlog.get("event_id")
    event_data = winlog.get("event_data", {})
    channel = winlog.get("channel", "")

    if event_id is None:
        return None

    # Build a list of key fields that define the event's "shape"
    parts: list[str] = [str(event_id)]

    if event_id == 1:  # Process creation
        parent = _basename(event_data.get("ParentImage", ""))
        image = _basename(event_data.get("Image", ""))
        # Normalize command line: strip arguments that look like paths/GUIDs/timestamps
        cmd_shape = _normalize_cmdline(event_data.get("CommandLine", ""))
        parts += [parent, image, cmd_shape]

    elif event_id == 3:  # Network connection
        image = _basename(event_data.get("Image", ""))
        dst_port = str(event_data.get("DestinationPort", ""))
        # Don't include dest IP — it changes; port+process is the shape
        parts += [image, dst_port]

    elif event_id == 10:  # Process access
        src = _basename(event_data.get("SourceImage", ""))
        tgt = _basename(event_data.get("TargetImage", ""))
        parts += [src, tgt]

    elif event_id == 11:  # File creation
        fname = event_data.get("TargetFilename", "")
        # Use directory + extension as shape, not full path
        parts.append(_file_shape(fname))

    elif event_id == 4624:  # Logon
        logon_type = str(event_data.get("LogonType", ""))
        parts.append(logon_type)

    elif event_id == 4769:  # Kerberos TGS
        svc = event_data.get("ServiceName", "")
        enc = str(event_data.get("TicketEncryptionType", ""))
        parts += [svc, enc]

    elif event_id == 4648:  # Explicit credential use
        parts.append("explicit_cred")

    elif event_id == 4672:  # Special privilege logon
        parts.append("special_priv")

    elif event_id == 4634:  # Logoff
        parts.append("logoff")

    elif event_id == 4104:  # PowerShell script block
        script = event_data.get("ScriptBlockText", "")
        # Use first 200 chars as shape — same script = same shape
        parts.append(_normalize_cmdline(script[:200]))

    else:
        # Generic: channel + event_id is the shape
        parts.append(channel)

    raw = "|".join(parts)
    return hashlib.sha256(raw.encode()).hexdigest()[:16]


def fingerprint_with_context(event: dict) -> dict | None:
    """Return fingerprint plus context fields for baseline matching."""
    fp = fingerprint_event(event)
    if fp is None:
        return None

    winlog = event.get("winlog", {})
    event_id = winlog.get("event_id")
    host = event.get("host", {}).get("name", "unknown")

    return {
        "fingerprint": fp,
        "event_id": event_id,
        "host": host,
    }


async def check_baselines(
    es: AsyncElasticsearch,
    events: list[dict],
) -> tuple[list[dict], list[dict], dict[str, int]]:
    """Split events into novel and suppressed based on baseline history.

    Returns:
        (novel_events, suppressed_events, suppression_stats)
    """
    # Fingerprint all events
    fp_map: dict[str, list[dict]] = {}  # fingerprint -> list of events
    unfingerprintable: list[dict] = []

    for event in events:
        fp = fingerprint_event(event)
        if fp is None:
            unfingerprintable.append(event)
            continue
        fp_map.setdefault(fp, []).append(event)

    if not fp_map:
        return unfingerprintable, [], {}

    # Batch-fetch baseline records for all fingerprints
    baselines = await _get_baselines(es, list(fp_map.keys()))

    novel: list[dict] = list(unfingerprintable)
    suppressed: list[dict] = []
    stats: dict[str, int] = {}

    for fp, fp_events in fp_map.items():
        baseline = baselines.get(fp)

        if baseline and baseline.get("times_seen", 0) >= SUPPRESSION_THRESHOLD:
            last_severity = baseline.get("last_severity", "")
            if last_severity in ("low", ""):
                # This is known-normal — suppress it
                suppressed.extend(fp_events)
                stats[fp] = len(fp_events)
                continue

        # Novel or not yet baselined enough — pass through
        novel.extend(fp_events)

    return novel, suppressed, stats


async def update_baselines(
    es: AsyncElasticsearch,
    events: list[dict],
    severity: str,
) -> None:
    """Update baseline counts after triage has classified events."""
    fp_counts: dict[str, int] = {}
    fp_labels: dict[str, dict] = {}  # fingerprint -> example event info

    for event in events:
        ctx = fingerprint_with_context(event)
        if ctx is None:
            continue
        fp = ctx["fingerprint"]
        fp_counts[fp] = fp_counts.get(fp, 0) + 1
        if fp not in fp_labels:
            fp_labels[fp] = {
                "event_id": ctx["event_id"],
                "host": ctx["host"],
            }

    now = datetime.now(timezone.utc).isoformat()

    for fp, count in fp_counts.items():
        try:
            # Upsert: increment counter, update last_seen and severity
            await es.update(
                index=BASELINES_INDEX,
                id=fp,
                body={
                    "script": {
                        "source": (
                            "ctx._source.times_seen += params.count; "
                            "ctx._source.last_seen = params.now; "
                            "ctx._source.last_severity = params.severity; "
                            "if (!ctx._source.hosts.contains(params.host)) { "
                            "  ctx._source.hosts.add(params.host); "
                            "}"
                        ),
                        "params": {
                            "count": count,
                            "now": now,
                            "severity": severity,
                            "host": fp_labels[fp].get("host", "unknown"),
                        },
                    },
                    "upsert": {
                        "fingerprint": fp,
                        "event_id": fp_labels[fp].get("event_id"),
                        "times_seen": count,
                        "first_seen": now,
                        "last_seen": now,
                        "last_severity": severity,
                        "hosts": [fp_labels[fp].get("host", "unknown")],
                    },
                },
            )
        except Exception:
            logger.debug("Failed to update baseline for %s", fp)


async def _get_baselines(
    es: AsyncElasticsearch,
    fingerprints: list[str],
) -> dict[str, dict]:
    """Batch-fetch baseline records by fingerprint IDs."""
    result: dict[str, dict] = {}
    if not fingerprints:
        return result

    try:
        resp = await es.mget(
            index=BASELINES_INDEX,
            body={"ids": fingerprints},
        )
        for doc in resp.get("docs", []):
            if doc.get("found"):
                result[doc["_id"]] = doc["_source"]
    except Exception:
        # Index might not exist yet — that's fine, everything is novel
        pass

    return result


def _basename(path: str) -> str:
    """Extract filename from a Windows or Unix path."""
    if not path:
        return ""
    return path.replace("/", "\\").rsplit("\\", 1)[-1].lower()


def _normalize_cmdline(cmd: str) -> str:
    """Reduce a command line to its structural shape.

    Strips GUIDs, timestamps, temp paths, and random-looking arguments
    so that repeated invocations of the same tool produce the same shape.
    """
    import re
    if not cmd:
        return ""
    cmd = cmd.lower()
    # Replace GUIDs
    cmd = re.sub(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", "<GUID>", cmd)
    # Replace hex strings (8+ chars)
    cmd = re.sub(r"\b[0-9a-f]{8,}\b", "<HEX>", cmd)
    # Replace numbers that look like PIDs, ports, timestamps
    cmd = re.sub(r"\b\d{4,}\b", "<NUM>", cmd)
    # Replace temp paths
    cmd = re.sub(r"\\temp\\[^\s\\]+", "\\temp\\<FILE>", cmd)
    cmd = re.sub(r"\\tmp\\[^\s\\]+", "\\tmp\\<FILE>", cmd)
    return cmd[:200]


def _file_shape(path: str) -> str:
    """Extract the directory pattern + extension from a file path."""
    import re
    if not path:
        return ""
    path = path.lower().replace("/", "\\")
    # Get directory (strip filename)
    parts = path.rsplit("\\", 1)
    directory = parts[0] if len(parts) > 1 else ""
    filename = parts[-1]

    # Get extension
    ext = ""
    if "." in filename:
        ext = filename.rsplit(".", 1)[-1]

    # Normalize temp/random directories
    directory = re.sub(r"\\[0-9a-f]{8,}", "\\<HASH>", directory)
    directory = re.sub(r"\\\d{4,}", "\\<NUM>", directory)

    return f"{directory}|.{ext}" if ext else directory
