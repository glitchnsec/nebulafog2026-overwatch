#!/bin/bash
# Run on ELK host (10.0.1.10): sudo bash setup-elk.sh

echo "=== [1/4] Installing Docker ==="
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release jq
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
ARCH=$(dpkg --print-architecture)
CODENAME=$(lsb_release -cs)
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "=== [2/4] System tuning ==="
sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" >> /etc/sysctl.conf

echo "=== [3/4] Writing configs ==="
mkdir -p /opt/elk/logstash/pipeline
cd /opt/elk

cat > docker-compose.yml << 'DCOMPOSE'
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
      elasticsearch: { condition: service_healthy }
    ports:
      - "5044:5044"
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline:ro
    restart: unless-stopped
  kibana:
    image: docker.elastic.co/kibana/kibana:8.17.0
    container_name: kibana
    depends_on:
      elasticsearch: { condition: service_healthy }
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    restart: unless-stopped
volumes:
  es-data:
DCOMPOSE

cat > logstash/pipeline/logstash.conf << 'LSPIPELINE'
input {
  beats { port => 5044 }
}
filter {
  if [winlog][channel] == "Microsoft-Windows-Sysmon/Operational" {
    if [winlog][event_id] == 1  { mutate { add_field => { "event_type" => "process_creation" } } }
    if [winlog][event_id] == 2  { mutate { add_field => { "event_type" => "file_creation_time_changed" } } }
    if [winlog][event_id] == 3  { mutate { add_field => { "event_type" => "network_connection" } } }
    if [winlog][event_id] == 5  { mutate { add_field => { "event_type" => "process_terminated" } } }
    if [winlog][event_id] == 6  { mutate { add_field => { "event_type" => "driver_loaded" } } }
    if [winlog][event_id] == 7  { mutate { add_field => { "event_type" => "image_loaded" } } }
    if [winlog][event_id] == 8  { mutate { add_field => { "event_type" => "create_remote_thread" } } }
    if [winlog][event_id] == 9  { mutate { add_field => { "event_type" => "raw_access_read" } } }
    if [winlog][event_id] == 10 { mutate { add_field => { "event_type" => "process_access" } } }
    if [winlog][event_id] == 11 { mutate { add_field => { "event_type" => "file_created" } } }
    if [winlog][event_id] == 12 { mutate { add_field => { "event_type" => "registry_object_added_deleted" } } }
    if [winlog][event_id] == 13 { mutate { add_field => { "event_type" => "registry_value_set" } } }
    if [winlog][event_id] == 14 { mutate { add_field => { "event_type" => "registry_object_renamed" } } }
    if [winlog][event_id] == 15 { mutate { add_field => { "event_type" => "file_stream_created" } } }
    if [winlog][event_id] == 17 { mutate { add_field => { "event_type" => "pipe_created" } } }
    if [winlog][event_id] == 18 { mutate { add_field => { "event_type" => "pipe_connected" } } }
    if [winlog][event_id] == 22 { mutate { add_field => { "event_type" => "dns_query" } } }
    if [winlog][event_id] == 23 { mutate { add_field => { "event_type" => "file_deleted" } } }
    if [winlog][event_id] == 25 { mutate { add_field => { "event_type" => "process_tampering" } } }
    if [winlog][event_id] == 26 { mutate { add_field => { "event_type" => "file_delete_logged" } } }
    mutate { add_tag => ["sysmon"] }
  }
  if [winlog][channel] == "Security"                                                          { mutate { add_tag => ["windows_security"] } }
  if [winlog][channel] == "System"                                                            { mutate { add_tag => ["windows_system"] } }
  if [winlog][channel] == "Microsoft-Windows-PowerShell/Operational"                           { mutate { add_tag => ["powershell_operational"] } }
  if [winlog][channel] == "Windows PowerShell"                                                 { mutate { add_tag => ["powershell_classic"] } }
  if [winlog][channel] == "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational" { mutate { add_tag => ["terminal_services"] } }
  if [winlog][event_data][Hashes] {
    kv { source => "[winlog][event_data][Hashes]"; target => "process_hashes"; field_split => ","; value_split => "=" }
  }
  if [winlog][event_data][UtcTime] {
    date { match => ["[winlog][event_data][UtcTime]", "yyyy-MM-dd HH:mm:ss.SSS"]; target => "event_timestamp" }
  }
  if [event_type] == "network_connection" {
    if [winlog][event_data][Initiated] == "true" { mutate { add_field => { "network_direction" => "outbound" } } }
    else                                         { mutate { add_field => { "network_direction" => "inbound" } } }
  }
  if [winlog][event_data][Image]           { mutate { add_field => { "process_image"   => "%{[winlog][event_data][Image]}" } } }
  if [winlog][event_data][ParentImage]     { mutate { add_field => { "parent_image"    => "%{[winlog][event_data][ParentImage]}" } } }
  if [winlog][event_data][CommandLine]     { mutate { add_field => { "command_line"    => "%{[winlog][event_data][CommandLine]}" } } }
  if [winlog][event_data][User]            { mutate { add_field => { "event_user"      => "%{[winlog][event_data][User]}" } } }
  if [winlog][event_data][TargetFilename]  { mutate { add_field => { "target_file"     => "%{[winlog][event_data][TargetFilename]}" } } }
  if [winlog][event_data][TargetObject]    { mutate { add_field => { "registry_target" => "%{[winlog][event_data][TargetObject]}" } } }
  if [winlog][event_data][DestinationIp]   { mutate { add_field => { "dst_ip"          => "%{[winlog][event_data][DestinationIp]}" } } }
  if [winlog][event_data][DestinationPort] { mutate { add_field => { "dst_port"        => "%{[winlog][event_data][DestinationPort]}" } } }
  if [winlog][event_data][SourceIp]        { mutate { add_field => { "src_ip"          => "%{[winlog][event_data][SourceIp]}" } } }
  if [winlog][event_data][SourcePort]      { mutate { add_field => { "src_port"        => "%{[winlog][event_data][SourcePort]}" } } }
}
output {
  elasticsearch { hosts => ["http://elasticsearch:9200"]; index => "winlogbeat-%{+YYYY.MM.dd}" }
}
LSPIPELINE

echo "=== [4/4] Starting ELK stack ==="
docker compose up -d

echo "Waiting for Elasticsearch..."
for i in $(seq 1 60); do
  curl -s http://localhost:9200/_cluster/health 2>/dev/null | grep -qE '"status":"(green|yellow)"' && echo "ES healthy" && break
  sleep 5
done

echo "Waiting for Logstash on :5044..."
for i in $(seq 1 30); do
  ss -tlnp | grep -q 5044 && echo "Logstash ready" && break
  sleep 5
done

echo ""
echo "=== DONE ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo "Kibana: http://$(hostname -I | awk '{print $1}'):5601"
