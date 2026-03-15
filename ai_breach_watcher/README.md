# AI Breach Watcher

Blue team agent platform that monitors security logs from an adversary emulation lab. AI agents analyze raw telemetry from Elasticsearch, detect ATT&CK techniques, and present findings through a web UI — without any pre-labeled hints in the data.

```
┌─────────────────────────────────────────────────────────────┐
│                     ELK Host                                │
│                                                             │
│  Winlogbeat ──► Logstash (raw only) ──► Elasticsearch       │
│                                              │              │
│                                              ▼              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │            AI Breach Watcher (Docker)                │    │
│  │                                                      │    │
│  │  Poll Loop (60s)         Hunt Loop (300s)            │    │
│  │      │                        │                      │    │
│  │      ▼                        ▼                      │    │
│  │  Baseline Filter         Hunter (severity            │    │
│  │      │                    assignment only)            │    │
│  │      ▼                        │                      │    │
│  │  Triage (classify)      ┌─────┴──────┐               │    │
│  │      │                  │ if finding │               │    │
│  │      ▼                  ▼            ▼               │    │
│  │  if suspicious:    TTP Team ──► Responder            │    │
│  │  ──► TTP Team       (6 specialists)                  │    │
│  │  ──► Responder                                       │    │
│  │                                                      │    │
│  │  FastAPI ◄──── WebSocket ────► React UI (:3000)      │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
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

### Using Local Dev with Production ES

To run the dev stack but query a remote ELK instance:

```bash
# In .env, point to the remote ES
ELASTICSEARCH_URL=http://<elk_ip>:9200

# Launch dev profile (local ES still starts but backend ignores it)
docker compose -f docker_compose.yml --profile dev up --build
```

### Production (on ELK Host)

```bash
# Copy to ELK host
scp -r ai_breach_watcher/ ubuntu@<elk_ip>:/opt/

# SSH in and configure
ssh ubuntu@<elk_ip>
cd /opt/ai_breach_watcher
cp .env.example .env
# Set ELASTICSEARCH_URL=http://localhost:9200 and your ANTHROPIC_API_KEY

# Launch (connects to existing ELK stack)
docker compose -f docker_compose.yml --profile prod up --build -d
```

## Architecture

### Design Principles

- **Assume benign** — the system optimizes for reducing alert fatigue, not maximizing detections
- **Chains over atoms** — individual events are rarely suspicious; correlated TTP chains across hosts and time are what matter
- **Severity authority is centralized** — only the Hunt agent assigns severity levels, after correlating across broad time windows
- **No pre-labeled data** — the Logstash pipeline strips all TTP tags; agents must detect techniques independently

### Two-Loop Pipeline

The orchestrator runs two async loops at different cadences:

**Poll Loop (60s) — Fast Triage Filter**

Fetches new events, filters known-normal patterns via fingerprinting, and classifies the remainder. Most batches are classified as `normal` and silently baselined — no alert, no API cost.

| Step | What happens |
|------|-------------|
| Baseline filter | Fingerprint events by shape (process lineage, port, logon type). Suppress patterns seen 5+ times with low severity. |
| Triage agent | Classify batch as `normal`, `suspicious`, or `needs_investigation`. No severity assignment. |
| If normal | Update baselines, broadcast to live feed. No alert created. |
| If suspicious | Store as `pending_hunt` for the hunt agent to review. |
| If needs_investigation | Store + immediately escalate to TTP Team and Responder. |

**Hunt Loop (300s) — Severity & Threat Narratives**

The only agent authorized to assign severity. Correlates events across a 30-minute window, reviews pending triage flags, and constructs attack narratives when real threats are found.

| Severity | Criteria |
|----------|----------|
| critical | 3+ correlated kill chain phases forming a coherent attack narrative |
| high | 2+ correlated TTP phases with supporting evidence |
| medium | Isolated suspicious activity, not yet a chain |
| low | Anomalous but likely benign |
| none | Nothing actionable — expected outcome for most cycles |

### Agent Roles

| Agent | Role |
|-------|------|
| **Triage** | Fast classifier — `normal` / `suspicious` / `needs_investigation`. No severity. |
| **Hunter** | Sole severity authority. Correlates across time/hosts to find TTP chains. |
| **TTP Analyst Team** | 6 tactic specialists reason together on escalated events. |
| **Responder** | Recommends containment/eradication/recovery — never executes. |

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

### Event Fingerprinting & Baseline Suppression

Events are hashed by their "shape" — key structural fields with volatile data (timestamps, GUIDs, PIDs, temp paths) stripped out. After a fingerprint is seen 5+ times and triaged as normal, it is automatically suppressed in future poll cycles.

| Event Type | Fingerprint Fields |
|-----------|-------------------|
| Sysmon 1 (Process) | parent process + child process + normalized command line |
| Sysmon 3 (Network) | process + destination port (not IP) |
| Sysmon 10 (Process Access) | source process + target process |
| Sysmon 11 (File Create) | directory pattern + file extension |
| Security 4624 (Logon) | logon type |
| Security 4769 (TGS) | service name + encryption type |
| Security 4104 (PowerShell) | first 200 chars of script block |

### Skills

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

The raw normalization pipeline (`logstash-raw-pipeline.conf`) replaces any TTP-tagged pipeline. It only normalizes timestamps, hostnames, and adds generic `event_category` labels. No ATT&CK tags, no threat-actor attribution — the agents must figure it out independently.

## Web UI

| Page | Description |
|------|-------------|
| **Dashboard** | Alert severity cards, event rate, live WebSocket feed |
| **Alerts** | Clickable alert table, filterable by severity — click to see full agent pipeline flow |
| **Alert Detail** | Agent pipeline visualization (Triage → TTP → Response) with markdown-rendered output |
| **Investigations** | Correlated incidents with kill chain phase, tactics, and attack narrative |
| **Skills Editor** | Edit SKILL.md files in-browser, each save creates a git commit with version history |
| **Agent Logs** | Per-agent run history — click to see full reasoning trace with prompt preview |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | ES connection status |
| GET | `/api/dashboard` | Alert counts by severity/status, event rates, open investigations |
| GET | `/api/alerts` | List alerts with filters (severity, status, host, time_from) |
| GET | `/api/alerts/{id}` | Full alert detail including triage/hunt output |
| PUT | `/api/alerts/{id}` | Update status, severity, or analyst notes |
| GET | `/api/investigations` | List investigations with status filter |
| GET | `/api/investigations/by-alert/{id}` | Get investigation linked to a specific alert |
| GET/PUT | `/api/investigations/{id}` | Investigation detail and updates |
| GET | `/api/skills` | List all skills with metadata |
| GET/PUT | `/api/skills/{name}` | Skill CRUD with git-backed versioning |
| GET | `/api/skills/{name}/history` | Commit history for a skill |
| GET | `/api/skills/{name}/version/{sha}` | Skill content at a specific version |
| GET | `/api/agents` | Agent run logs with optional agent_name filter |
| GET | `/api/agents/status/current` | Latest run status per agent |
| GET | `/api/agents/{run_id}` | Full agent run details with reasoning trace |
| WS | `/ws` | Live event stream (alerts, triage results, baseline stats, hunt findings) |

## Docker Services

| Service | Profile | Port | Description |
|---------|---------|------|-------------|
| `elasticsearch-dev` | dev | 9200 | Local single-node ES for development |
| `seed-dev-data` | dev | — | Seeds fake attack telemetry for testing |
| `backend` | dev, prod | 8000 | FastAPI + Agno agents + orchestrator loops |
| `frontend` | dev, prod | 3000 | React UI with Vite HMR |

## Elasticsearch Indices

| Index | Purpose |
|-------|---------|
| `winlogbeat-*` | Raw security events from Winlogbeat (read-only) |
| `breach-watcher-alerts` | Triage records and hunt findings |
| `breach-watcher-investigations` | Correlated incidents with TTP analysis and response plans |
| `breach-watcher-agent-logs` | Agent run history with reasoning traces |
| `breach-watcher-baselines` | Event fingerprint counters for suppression |
| `breach-watcher-state` | Orchestrator checkpoint (poll/hunt timestamps) |

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
│       ├── config.py           # Pydantic settings (ES, intervals, indices)
│       ├── seed.py             # Fake event generator for dev
│       ├── agents/
│       │   ├── orchestrator.py # Two-loop engine (poll + hunt)
│       │   ├── ttp_team.py     # Agno Team — 6 tactic specialists
│       │   └── pipeline.py     # Agno Workflow definition
│       ├── tools/
│       │   ├── elastic.py      # ES query/store tools
│       │   └── mitre.py        # ATT&CK technique lookup
│       ├── state/
│       │   ├── checkpoint.py   # Poll state + index creation
│       │   ├── baselines.py    # Event fingerprinting + suppression
│       │   └── versioning.py   # Git-backed skill versioning
│       └── api/
│           ├── app.py          # FastAPI entrypoint + background tasks
│           ├── ws.py           # WebSocket broadcaster
│           └── routes/         # REST endpoints
│               ├── dashboard.py
│               ├── alerts.py
│               ├── investigations.py
│               ├── skills.py
│               └── agents.py
│
└── frontend/
    ├── Dockerfile
    ├── package.json
    └── src/
        ├── main.tsx            # React router + layout
        ├── api.ts              # Typed API client
        ├── hooks.ts            # useFetch, useLiveFeed
        └── pages/
            ├── Dashboard.tsx
            ├── Alerts.tsx
            ├── AlertDetail.tsx # Agent pipeline flow + markdown
            ├── Investigations.tsx
            ├── Skills.tsx      # Skill editor with version history
            ├── AgentLogs.tsx
            └── AgentRunDetail.tsx # Full reasoning trace
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ANTHROPIC_API_KEY` | — | Required. Claude API key for agent calls. |
| `ELASTICSEARCH_URL` | `http://elasticsearch-dev:9200` | ES endpoint. Use `http://localhost:9200` for prod. |
| `POLL_INTERVAL_SECONDS` | `60` | How often the triage poll loop runs. |
| `HUNT_INTERVAL_SECONDS` | `300` | How often the hunt loop runs. |
| `LOG_LEVEL` | `info` | Python logging level. |
| `BACKEND_PORT` | `8000` | Host port for the backend. |
| `FRONTEND_PORT` | `3000` | Host port for the frontend. |
| `VITE_API_URL` | `http://backend:8000` | Backend URL for Vite proxy (Docker service name). |
| `VITE_WS_URL` | `ws://backend:8000` | WebSocket URL for Vite proxy. |
