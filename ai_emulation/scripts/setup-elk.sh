#!/bin/bash
# =============================================================================
# ELK Stack Setup — Runs via Terraform remote-exec on the ELK host
# =============================================================================

echo "=== [1/5] Installing Docker ==="
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release jq

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

ARCH=$(dpkg --print-architecture)
CODENAME=$(lsb_release -cs)
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "=== [2/5] Configuring system for Elasticsearch ==="
sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" >> /etc/sysctl.conf

echo "=== [3/5] Creating ELK directory structure ==="
mkdir -p /opt/elk/logstash/pipeline

echo "=== [4/5] Writing docker-compose.yml ==="
cat > /opt/elk/docker-compose.yml << 'COMPOSE'
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.17.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms4g -Xmx4g"
    ports:
      - "9200:9200"
    volumes:
      - es-data:/usr/share/elasticsearch/data
    healthcheck:
      test: ["CMD-SHELL", "curl -s http://localhost:9200/_cluster/health | grep -qE 'green|yellow'"]
      interval: 10s
      timeout: 5s
      retries: 30
    restart: unless-stopped

  logstash:
    image: docker.elastic.co/logstash/logstash:8.17.0
    container_name: logstash
    depends_on:
      elasticsearch:
        condition: service_healthy
    ports:
      - "5044:5044"
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline:ro
    restart: unless-stopped

  kibana:
    image: docker.elastic.co/kibana/kibana:8.17.0
    container_name: kibana
    depends_on:
      elasticsearch:
        condition: service_healthy
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    restart: unless-stopped

volumes:
  es-data:
COMPOSE

echo "=== [5/5] Starting ELK stack ==="
cd /opt/elk
docker compose up -d

echo "Waiting for Elasticsearch to become healthy..."
for i in $(seq 1 60); do
  if curl -s http://localhost:9200/_cluster/health | grep -qE '"status":"(green|yellow)"'; then
    echo "Elasticsearch is healthy."
    break
  fi
  echo "  ...waiting ($i/60)"
  sleep 5
done

echo "Waiting for Logstash to listen on 5044..."
for i in $(seq 1 30); do
  if ss -tlnp | grep -q 5044; then
    echo "Logstash is ready."
    break
  fi
  echo "  ...waiting ($i/30)"
  sleep 5
done

echo ""
echo "=== ELK Stack deployment complete ==="
echo "Elasticsearch: http://localhost:9200"
echo "Kibana:        http://localhost:5601"
echo "Logstash:      listening on :5044"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
