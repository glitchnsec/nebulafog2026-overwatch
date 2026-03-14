#!/bin/bash
# =============================================================================
# CALDERA + Emu Plugin Setup — Runs via Terraform remote-exec
# =============================================================================

echo "=== [1/6] Installing system dependencies ==="
apt-get update -y
apt-get install -y git python3 python3-pip python3-venv golang-go unzip jq curl

echo "=== [2/6] Cloning CALDERA with all plugins ==="
cd /home/ubuntu
if [ ! -d "caldera" ]; then
  git clone https://github.com/mitre/caldera.git --recursive --tag 5.1.0
fi
cd caldera

echo "=== [3/6] Setting up Python venv and installing deps ==="
python3 -m venv .calderavenv
source .calderavenv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo "=== [4/6] Writing CALDERA config ==="
cat > conf/local.yml << 'EOF'
host: 0.0.0.0
port: 8888
plugins:
  - sandcat
  - stockpile
  - emu
  - response
users:
  red:
    red: admin
  blue:
    blue: admin
EOF

echo "=== [5/6] Cloning adversary emulation library ==="
cd /home/ubuntu
if [ ! -d "adversary_emulation_library" ]; then
  git clone https://github.com/center-for-threat-informed-defense/adversary_emulation_library.git
fi
cd adversary_emulation_library/wizard_spider
python3 Resources/utilities/crypt_executables.py -i ./ -p malware --decrypt || echo "Payload decryption skipped or completed"

echo "=== [6/6] Starting CALDERA ==="
cd /home/ubuntu/caldera
source .calderavenv/bin/activate

# Start in background, log to file
nohup python3 server.py --insecure --build > /home/ubuntu/caldera.log 2>&1 &
CALDERA_PID=$!
echo "CALDERA started with PID $CALDERA_PID"

# Wait for it to be ready
echo "Waiting for CALDERA to start..."
for i in $(seq 1 60); do
  if curl -s http://localhost:8888 > /dev/null 2>&1; then
    echo "CALDERA is up and listening on :8888"
    break
  fi
  echo "  ...waiting ($i/60)"
  sleep 5
done

# Download Emu payloads now that CALDERA has initialized the plugin dirs
if [ -f "plugins/emu/download_payloads.sh" ]; then
  echo "Downloading Emu plugin payloads..."
  cd plugins/emu
  bash download_payloads.sh || echo "Some payloads may have failed — non-critical"
  cd ../..
fi

# Fix ownership
chown -R ubuntu:ubuntu /home/ubuntu/caldera /home/ubuntu/adversary_emulation_library

echo ""
echo "=== CALDERA deployment complete ==="
echo "UI:   http://localhost:8888"
echo "Cred: red / admin"
echo "Log:  /home/ubuntu/caldera.log"
