"""WebSocket endpoint for live alert and agent event streaming."""

import asyncio
import json
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

logger = logging.getLogger(__name__)

router = APIRouter()

# Connected clients
_clients: set[WebSocket] = set()


async def broadcast(event_type: str, data: dict) -> None:
    """Broadcast an event to all connected WebSocket clients."""
    message = json.dumps({
        "type": event_type,
        "data": data,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    })
    disconnected = set()
    for ws in _clients:
        try:
            await ws.send_text(message)
        except Exception:
            disconnected.add(ws)
    _clients.difference_update(disconnected)


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """Live feed for blue team UI — alerts, agent status, investigation updates."""
    await websocket.accept()
    _clients.add(websocket)
    logger.info("WebSocket client connected (%d total)", len(_clients))
    try:
        while True:
            # Keep connection alive; client can send commands later
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        _clients.discard(websocket)
        logger.info("WebSocket client disconnected (%d remaining)", len(_clients))
