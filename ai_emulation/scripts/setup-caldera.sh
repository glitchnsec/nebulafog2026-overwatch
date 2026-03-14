#!/bin/bash
# Run on Attack Platform (10.0.2.4): sudo bash setup-caldera.sh

echo "=== [1/5] Installing dependencies ==="
apt-get update -y
apt-get install -y git python3 python3-pip python3-venv golang-go unzip jq curl

echo "=== [2/5] Cloning CALDERA ==="
cd /home/ubuntu
git clone --branch 5.1.0 --single-branch https://github.com/mitre/caldera.git caldera
cd caldera

git submodule update --init plugins/sandcat
git submodule update --init plugins/stockpile
git submodule update --init plugins/emu
git submodule update --init plugins/response
git submodule update --init plugins/manx

echo "=== [3/5] Python venv + deps ==="
python3 -m venv .calderavenv
source .calderavenv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo "=== [4/5] Writing config ==="
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

echo "=== [5/5] Starting CALDERA ==="
nohup python3 server.py --insecure --build > /home/ubuntu/caldera.log 2>&1 &

echo "Waiting for CALDERA..."
for i in $(seq 1 60); do
  curl -s http://localhost:8888 > /dev/null 2>&1 && echo "CALDERA is up on :8888" && break
  sleep 5
done

# Download Emu payloads
if [ -f "plugins/emu/download_payloads.sh" ]; then
  echo "Downloading Emu payloads..."
  cd plugins/emu && bash download_payloads.sh && cd ../..
fi

# Clone emulation library
cd /home/ubuntu
git clone https://github.com/center-for-threat-informed-defense/adversary_emulation_library.git
cd adversary_emulation_library/wizard_spider
python3 Resources/utilities/crypt_executables.py -i ./ -p malware --decrypt 2>/dev/null || true

chown -R ubuntu:ubuntu /home/ubuntu/caldera /home/ubuntu/adversary_emulation_library

echo ""
echo "=== DONE ==="
echo "UI:   http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8888"
echo "Cred: red / admin"
echo "Log:  tail -f /home/ubuntu/caldera.log"
