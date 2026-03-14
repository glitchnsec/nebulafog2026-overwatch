# AI Breach Watcher

Blue team agent platform that monitors security logs from an adversary emulation lab. AI agents analyze raw telemetry from Elasticsearch, detect ATT&CK techniques, and present findings through a web UI — without any pre-labeled hints in the data.

```
┌─────────────────────────────────────────────────────────┐
│                    ELK Host (10.0.1.10)                 │
│                                                         │
│  Winlogbeat ──► Logstash (raw only) ──► Elasticsearch   │
│                                              │          │
│                                              ▼          │
│  ┌─────────────────────────────────────────────────┐    │
│  │           AI Breach Watcher (Docker)             │    │
│  │                                                  │    │
│  │  Orchestrator (polls ES every 60s)               │    │
│  │       │                                          │    │
│  │       ▼                                          │    │
│  │  Triage ──► TTP Analyst Team ──► Responder       │    │
│  │              (6 specialists)                     │    │
│  │       │                                          │    │
│  │       ▼                                          │    │
│  │  FastAPI ◄──── WebSocket ────► React UI (:3000)  │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## Quick Start

### Local Development

```bash
# 1. Create your .env
cp .env.example .env
# Edit .env and set your ANTHROPIC_API_KEY

# 2. Launch everything (local ES + backend + frontend)
docker compose -f docker_compose.yml --profile dev up --build

# 3. Seed fake log data for testing
docker compose -f docker_compose.yml --profile dev run --rm seed-dev-data
```

Open **http://localhost:3000** in your browser.

> If ports 8000 or 3000 are already in use, set overrides in `.env`:
> ```
> BACKEND_PORT=8001
> FRONTEND_PORT=3001
> ```

### Production (on ELK Host)

```bash
# Copy to ELK host
scp -i <key.pem> -r ai_breach_watcher/ ubuntu@<elk_ip>:/opt/

# SSH in and configure
ssh -i <key.pem> ubuntu@<elk_ip>
cd /opt/ai_breach_watcher
cp .env.example .env
# Set ELASTICSEARCH_URL=http://localhost:9200 and your ANTHROPIC_API_KEY

# Launch (connects to existing ELK stack)
docker compose -f docker_compose.yml --profile prod up --build -d
```

## Architecture

### Agent Pipeline (Agno Workflow)

Events flow through a sequential pipeline: **Triage → TTP Analyst Team → Responder**.

| Agent | Framework | Role |
|-------|-----------|------|
| **Triage** | Agno Agent | Scores raw events as critical/high/medium/low |
| **TTP Analyst Team** | Agno Team (`coordinate` mode) | 6 tactic specialists reason together |
| **Hunter** | Agno Agent | Proactive hypothesis-driven hunting (slower cadence) |
| **Responder** | Agno Agent | Recommends containment — never executes |

### TTP Analyst Team — One Agent Per Tactic

The team leader distributes events to specialists, then synthesizes findings into an attack narrative.

| Specialist | Tactic | Detects |
|-----------|--------|---------|
| Initial Access | TA0001 | Office macro → shell spawns, phishing payloads |
| Execution | TA0002 | PowerShell cradles, rundll32, LOLBins, WMI |
| Persistence | TA0003 | Registry run keys, scheduled tasks, services |
| Credential Access | TA0006 | LSASS dumps, Kerberoasting, credential harvesting |
| Lateral Movement | TA0008 | RDP, WinRM, SMB, pass-the-hash |
| Impact | TA0040 | Shadow copy deletion, ransomware, service stops |

### Claude Skills

Each agent's instructions live in `.claude/skills/` as `SKILL.md` files with YAML frontmatter. These are **editable from the web UI** with git-backed versioning — blue team operators can tune detection logic without code changes.

```
backend/.claude/skills/
├── triage/SKILL.md
├── hunt/SKILL.md
├── responder/SKILL.md
└── ttp-analysts/
    ├── SKILL.md
    └── tactics/
        ├── initial-access.md
        ├── execution.md
        ├── persistence.md
        ├── credential-access.md
        ├── lateral-movement.md
        └── impact.md
```

### Logstash Pipeline

The raw normalization pipeline (`logstash-raw-pipeline.conf`) replaces any TTP-tagged pipeline. It only normalizes timestamps, hostnames, and adds generic `event_category` labels. No ATT&CK tags, no threat-actor attribution — the agents must figure it out independently. This allows testing the platform's detection efficacy against any emulation plan.

## Web UI

| Page | Description |
|------|-------------|
| **Dashboard** | Alert severity cards, event rate, live WebSocket feed |
| **Alerts** | Filterable table by severity, host, status |
| **Investigations** | Correlated incidents with kill chain phase and attack narrative |
| **Skills Editor** | Edit SKILL.md files in-browser, each save creates a git commit with version history |
| **Agent Logs** | Per-agent run history with reasoning traces |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | ES connection status |
| GET | `/api/dashboard` | Alert counts, event rates, open investigations |
| GET/PUT | `/api/alerts` | Triage results with severity filtering |
| GET/PUT | `/api/investigations` | Correlated incident records |
| GET/PUT | `/api/skills/{name}` | Skill CRUD with git-backed versioning |
| GET | `/api/skills/{name}/history` | Commit history for a skill |
| GET | `/api/skills/{name}/version/{sha}` | Skill content at a specific version |
| GET | `/api/agents` | Agent run logs and reasoning traces |
| WS | `/ws` | Live event stream |

## Docker Services

| Service | Profile | Port | Description |
|---------|---------|------|-------------|
| `elasticsearch-dev` | dev | 9200 | Local ES for debugging |
| `seed-dev-data` | dev | — | Seeds 100 fake attack events |
| `backend` | dev, prod | 8000 | FastAPI + Agno agents + orchestrator |
| `frontend` | dev, prod | 3000 | React UI with Vite HMR |

## Project Structure

```
ai_breach_watcher/
├── docker_compose.yml          # Dev and prod profiles
├── .env.example                # Configuration template
├── logstash-raw-pipeline.conf  # Raw normalization (no TTP tags)
│
├── backend/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── .claude/skills/         # Agent skill definitions (editable from UI)
│   └── src/
│       ├── config.py           # ES connection, polling intervals
│       ├── seed.py             # Fake event generator for dev
│       ├── agents/
│       │   ├── ttp_team.py     # Agno Team — 6 tactic specialists
│       │   ├── pipeline.py     # Agno Workflow — triage → team → respond
│       │   └── orchestrator.py # Poll loop — feeds workflow from ES
│       ├── tools/
│       │   ├── elastic.py      # ES query tools for agents
│       │   └── mitre.py        # ATT&CK technique lookup
│       ├── state/
│       │   ├── checkpoint.py   # Polling state in ES
│       │   └── versioning.py   # Git-backed skill versioning
│       └── api/
│           ├── app.py          # FastAPI entrypoint
│           ├── ws.py           # WebSocket live feed
│           └── routes/         # REST endpoints
│
└── frontend/
    ├── Dockerfile
    ├── package.json
    └── src/
        ├── main.tsx            # React router + layout
        ├── api.ts              # API client
        ├── hooks.ts            # useFetch, useLiveFeed
        └── pages/
            ├── Dashboard.tsx
            ├── Alerts.tsx
            ├── Investigations.tsx
            ├── Skills.tsx      # Skill editor with version history
            └── AgentLogs.tsx
```

## Status

**Working:**
- Docker compose builds and runs (dev + prod profiles)
- All API endpoints responding
- Skills discovery and CRUD with git versioning
- Seed data generates realistic attack telemetry
- Frontend serves and proxies to backend
- WebSocket live feed connected

**Not yet wired:**
- Orchestrator poll loop (background task in FastAPI)
- Agno workflow execution (triage → TTP team → responder)
- Agent reasoning trace storage to ES
- Hunter agent on separate slower cadence
