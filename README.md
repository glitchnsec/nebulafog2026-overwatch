attack_platform = "3.96.198.17"
dorothy = "99.79.48.57"
elk = "15.223.1.249"
glinda = "35.182.177.173"
quick_ref = <<EOT

=== SSH (Linux) ===
ELK: ssh -i <key>.pem ubuntu@15.223.1.249
CALDERA: ssh -i <key>.pem ubuntu@3.96.198.17

=== RDP (Windows) — Administrator / WizSpider-Lab2024! ===
Wizard DC: 99.79.51.106
Dorothy: 99.79.48.57
Toto: 35.183.131.12
Glinda: 35.182.177.173

=== Run order ===

1. ssh ELK -> sudo bash setup-elk.sh
2. ssh CALDERA -> sudo bash setup-caldera.sh
3. RDP Wizard DC -> paste setup-dc.ps1 (reboots)
4. RDP Wizard DC -> paste setup-ad-users.ps1 (after reboot)
5. RDP Dorothy/Toto/Glinda -> paste setup-domain-join.ps1
6. RDP all Windows hosts -> paste setup-sysmon-winlogbeat.ps1

EOT
toto = "35.183.131.12"
wizard_dc = "99.79.51.106"

Ingest the logs into demo ELK
tar xzf elk-export.tar.gz
for f in elk-export/\*-mapping.json; do
idx=$(basename $f -mapping.json)
  echo "=== Importing: $idx ==="
  elasticdump --input=$f --output=http://localhost:9200/$idx --type=mapping
  elasticdump --input=elk-export/${idx}-data.json --output=http://localhost:9200/$idx --type=data
done

---

```
docker compose -f docker_compose.yml --profile dev up --build backend frontend elasticsearch-dev
```

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
