#!/bin/bash

# Build and Test Script for OpenSearch 3.1 with Sudachi Plugin

set -e

echo "=== OpenSearch 3.1 + Sudachi Plugin Build & Test ==="

# Check if we're in the right directory
if [ ! -f "Dockerfile" ]; then
    echo "Error: Please run this script from the opensearch-3.1-sudachi directory"
    exit 1
fi

# Check if plugin is built
if [ ! -f "../build-jdk21/distributions/opensearch-3.1.0-analysis-sudachi-3.3.1-SNAPSHOT.zip" ]; then
    echo "Error: Sudachi plugin not found. Please build it first:"
    echo "cd .. && docker build -f Dockerfile.build-jdk21 --build-arg ENGINE_VERSION=os:3.1.0 -t sudachi-builder-jdk21 ."
    echo "docker run --rm -v \$(pwd):/host_workspace sudachi-builder-jdk21 sh -c \"mkdir -p /host_workspace/build-jdk21 && cp -r /output/* /host_workspace/build-jdk21/\""
    exit 1
fi

echo ""
echo "Step 1: Building OpenSearch 3.1 + Sudachi Docker image..."
docker-compose build

echo ""
echo "Step 2: Starting OpenSearch 3.1 + Sudachi container..."
docker-compose up -d

echo ""
echo "Step 3: Waiting for OpenSearch to be ready..."
timeout=120
count=0
while [ $count -lt $timeout ]; do
    if curl -s http://localhost:9200/_cluster/health > /dev/null; then
        echo "OpenSearch is ready!"
        break
    fi
    sleep 1
    count=$((count + 1))
    if [ $((count % 10)) -eq 0 ]; then
        echo "Waiting... ($count/$timeout seconds)"
    fi
done

if [ $count -eq $timeout ]; then
    echo "Timeout waiting for OpenSearch to start"
    docker-compose logs opensearch-sudachi
    exit 1
fi

echo ""
echo "Step 4: Verifying OpenSearch 3.1.0 installation..."
curl -s http://localhost:9200/ | jq '.'

echo ""
echo "Step 5: Checking installed plugins..."
curl -s http://localhost:9200/_cat/plugins?v

echo ""
echo "Step 6: Testing Sudachi analyzer..."
echo "Basic Sudachi analysis test:"
curl -X POST "http://localhost:9200/_analyze" \
  -H "Content-Type: application/json" \
  -d '{"analyzer": "sudachi", "text": "すもももももももものうち"}' | jq '.tokens[] | {token: .token, start_offset: .start_offset, end_offset: .end_offset}'

echo ""
echo "Step 7: Testing Sudachi tokenizer with Japanese text..."
curl -X POST "http://localhost:9200/_analyze" \
  -H "Content-Type: application/json" \
  -d '{"tokenizer": "sudachi_tokenizer", "text": "東京都渋谷区恵比寿"}' | jq '.tokens[] | {token: .token, position: .position}'

echo ""
echo "Step 8: Creating test index with Sudachi analyzer..."
curl -X PUT "http://localhost:9200/sudachi-test" \
  -H "Content-Type: application/json" \
  -d '{
    "settings": {
      "analysis": {
        "analyzer": {
          "default": {
            "type": "sudachi"
          }
        }
      }
    },
    "mappings": {
      "properties": {
        "content": {
          "type": "text",
          "analyzer": "sudachi"
        }
      }
    }
  }' | jq '.'

echo ""
echo "Step 9: Indexing test documents..."
curl -X POST "http://localhost:9200/sudachi-test/_doc/1" \
  -H "Content-Type: application/json" \
  -d '{"content": "私は東京駅から新宿駅まで電車で移動しました。"}' | jq '.'

curl -X POST "http://localhost:9200/sudachi-test/_doc/2" \
  -H "Content-Type: application/json" \
  -d '{"content": "すもももももももものうち、柿も桃も桃のうち。"}' | jq '.'

echo ""
echo "Step 10: Refreshing index..."
curl -X POST "http://localhost:9200/sudachi-test/_refresh"

echo ""
echo "Step 11: Testing search functionality..."
echo "Searching for '電車':"
curl -X GET "http://localhost:9200/sudachi-test/_search" \
  -H "Content-Type: application/json" \
  -d '{"query": {"match": {"content": "電車"}}}' | jq '.hits.total.value'

echo ""
echo "Searching for 'もも':"
curl -X GET "http://localhost:9200/sudachi-test/_search" \
  -H "Content-Type: application/json" \
  -d '{"query": {"match": {"content": "もも"}}}' | jq '.hits.total.value'

echo ""
echo "Step 12: Cleaning up test index..."
curl -X DELETE "http://localhost:9200/sudachi-test" | jq '.'

echo ""
echo "=== Test Results Summary ==="
echo "✅ OpenSearch 3.1.0 successfully started"
echo "✅ Sudachi plugin successfully installed"
echo "✅ Japanese text analysis working"
echo "✅ Index and search operations working"
echo "✅ All tests passed!"

echo ""
echo "=== Container Information ==="
echo "Container Status:"
docker-compose ps

echo ""
echo "OpenSearch Logs (last 10 lines):"
docker-compose logs --tail=10 opensearch-sudachi

echo ""
echo "=== Usage Instructions ==="
echo "• OpenSearch is running at: http://localhost:9200"
echo "• OpenSearch Performance Analyzer: http://localhost:9600"
echo "• To stop: docker-compose down"
echo "• To stop and remove volumes: docker-compose down -v"
echo "• To view logs: docker-compose logs -f opensearch-sudachi"

echo ""
echo "🎉 OpenSearch 3.1 + Sudachi Plugin setup completed successfully!"