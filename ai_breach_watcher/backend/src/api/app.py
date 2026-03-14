import logging
from contextlib import asynccontextmanager

from elasticsearch import AsyncElasticsearch
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.config import settings
from src.api.routes import alerts, investigations, skills, agents, dashboard
from src.api.ws import router as ws_router
from src.state.checkpoint import ensure_indices

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logging.basicConfig(level=getattr(logging, settings.log_level.upper()))
    app.state.es = AsyncElasticsearch(settings.elasticsearch_url)
    await ensure_indices(app.state.es)
    logger.info("Breach Watcher backend started — ES at %s", settings.elasticsearch_url)
    yield
    await app.state.es.close()


app = FastAPI(
    title="AI Breach Watcher",
    description="Blue team agent platform for monitoring and analyzing security events",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(dashboard.router, prefix="/api/dashboard", tags=["dashboard"])
app.include_router(alerts.router, prefix="/api/alerts", tags=["alerts"])
app.include_router(investigations.router, prefix="/api/investigations", tags=["investigations"])
app.include_router(skills.router, prefix="/api/skills", tags=["skills"])
app.include_router(agents.router, prefix="/api/agents", tags=["agents"])
app.include_router(ws_router)


@app.get("/health")
async def health():
    try:
        info = await app.state.es.info()
        return {"status": "ok", "elasticsearch": info["version"]["number"]}
    except Exception as e:
        return {"status": "degraded", "error": str(e)}
