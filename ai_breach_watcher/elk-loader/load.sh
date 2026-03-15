#!/bin/bash
set -e

ES_URL="${ELASTICSEARCH_URL:-http://elasticsearch-dev:9200}"
ARCHIVE="/data/elk-export.tar.gz"
WORKDIR="/tmp/elk-import"

echo "=== ELK Data Loader ==="
echo "ES: $ES_URL"

# Wait for ES to be ready
echo "Waiting for Elasticsearch..."
until curl -sf "$ES_URL/_cluster/health" > /dev/null 2>&1; do
  sleep 2
done
echo "Elasticsearch is ready."

# Extract archive
echo "Extracting $ARCHIVE..."
mkdir -p "$WORKDIR"
tar xzf "$ARCHIVE" -C "$WORKDIR" --strip-components=1

# Load each index (mappings first, then data)
for mapping_file in "$WORKDIR"/*-mapping.json; do
  [ -f "$mapping_file" ] || continue
  idx=$(basename "$mapping_file" | sed 's/-mapping\.json$//')
  data_file="$WORKDIR/${idx}-data.json"

  echo "--- Loading index: $idx ---"

  # Load mapping
  elasticdump \
    --input="$mapping_file" \
    --output="$ES_URL/$idx" \
    --type=mapping

  # Load data if it exists
  if [ -f "$data_file" ]; then
    doc_count=$(wc -l < "$data_file")
    echo "    $doc_count documents to load"
    elasticdump \
      --input="$data_file" \
      --output="$ES_URL/$idx" \
      --type=data \
      --limit=5000
  fi
done

echo "=== All indices loaded ==="
curl -s "$ES_URL/_cat/indices?v&h=index,docs.count,store.size" | sort
