# On the ELK host
sudo apt-get install -y nodejs npm
sudo npm install -g elasticdump

cd /home/ubuntu
mkdir elk-export

# List all indices
curl -s http://localhost:9200/_cat/indices?h=index | grep -v '^\.' | sort

# Export everything (mappings + data for each index)
for idx in $(curl -s http://localhost:9200/_cat/indices?h=index | grep -v '^\.' | sort); do
  echo "=== Exporting: $idx ==="
  elasticdump \
    --input=http://localhost:9200/$idx \
    --output=elk-export/${idx}-mapping.json \
    --type=mapping

  elasticdump \
    --input=http://localhost:9200/$idx \
    --output=elk-export/${idx}-data.json \
    --type=data \
    --limit=10000
done

# Pack it up
tar czf elk-export.tar.gz elk-export/
echo "Total size: $(du -sh elk-export.tar.gz | awk '{print $1}')"
echo "Total docs: $(wc -l elk-export/*-data.json | tail -1)"