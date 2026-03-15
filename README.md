# Create .env

```
# --- Required ---
ANTHROPIC_API_KEY=sk-ant-your-key-here

# --- Dev mode (uses local ES) ---
ELASTICSEARCH_URL=http://elasticsearch-dev:9200

# --- Prod mode (on ELK host, ES is on localhost) ---
# ELASTICSEARCH_URL=http://localhost:9200

# --- Agent polling intervals ---
POLL_INTERVAL_SECONDS=60
HUNT_INTERVAL_SECONDS=300

# --- Frontend targets ---
FRONTEND_TARGET=dev
# These are used by Vite's dev server proxy INSIDE Docker.
# Use Docker service name "backend", not "localhost".
VITE_API_URL=http://backend:8000
VITE_WS_URL=ws://backend:8000

LOG_LEVEL=info
```

# Start the Services

```
docker compose -f docker_compose.yml --profile dev up --build backend frontend elasticsearch-dev
```

# Ingest the demo logs into ELK

```
npm install elasticdump -g
tar xzf elk-export.tar.gz
for f in elk-export/\*-mapping.json; do
idx=$(basename $f -mapping.json)
  echo "=== Importing: $idx ==="
  elasticdump --input=$f --output=http://localhost:9200/$idx --type=mapping
  elasticdump --input=elk-export/${idx}-data.json --output=http://localhost:9200/$idx --type=data
done
```

# Next Steps

1. Use Claude Code subscriptions instead of API
2. Implement Skills properly
3. Work on baselining and bypassing AI during high confidence duplicate events or similar scenarios