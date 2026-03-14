# Switch to the operator user that the bootstrap created
sudo su - operator

# Check if the bootstrap finished
ls ~/caldera/conf/local.yml && echo "CALDERA cloned OK" || echo "Still bootstrapping, wait..."

# If ready, finish setup:
cd ~/caldera
source .calderavenv/bin/activate

# Download Emu plugin payloads
cd plugins/emu
bash download_payloads.sh
cd ../..

# Install MCP plugin deps
pip install -r plugins/mcp/requirements.txt

# Configure your LLM API key
cat > plugins/mcp/conf/default.yml << 'EOF'
llm:
  model: claude-sonnet-4-20250514
  api_key: PASTE_YOUR_ANTHROPIC_KEY_HERE
  offline: false
  use_mock: false
factory:
  model: claude-sonnet-4-20250514
  api_key: PASTE_YOUR_ANTHROPIC_KEY_HERE
  temperature: 0.4
EOF

# Start CALDERA (background it)
python3 server.py --insecure --build &

# Wait ~30 seconds, then verify
curl -s http://localhost:8888 | head -5 && echo "CALDERA is up"