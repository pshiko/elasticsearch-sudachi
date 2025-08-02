#!/bin/bash

# Simple integration test script using existing infrastructure

set -e

echo "=== Starting OpenSearch 2.18.0 Integration Test ==="

# Stop any existing containers
docker compose -f docker-compose-test.yml down || true

# Start OpenSearch
echo "Starting OpenSearch..."
docker compose -f docker-compose-test.yml up -d opensearch

# Wait for OpenSearch to be ready
echo "Waiting for OpenSearch to be ready..."
timeout=60
count=0
while [ $count -lt $timeout ]; do
    if curl -s http://localhost:9200/_cluster/health > /dev/null; then
        echo "OpenSearch is ready!"
        break
    fi
    sleep 1
    count=$((count + 1))
done

if [ $count -eq $timeout ]; then
    echo "Timeout waiting for OpenSearch"
    exit 1
fi

# Check cluster health
echo "Checking cluster health..."
curl -s http://localhost:9200/_cluster/health | jq '.'

# Basic test: check if we can analyze text without plugin (baseline)
echo "Testing basic analysis..."
curl -s -X POST "http://localhost:9200/_analyze" \
  -H "Content-Type: application/json" \
  -d '{"analyzer": "standard", "text": "This is a test"}' | jq '.'

echo "=== Test completed successfully ==="
echo "OpenSearch 2.18.0 is running and responding normally"

# Keep container running for manual testing
echo "Container is still running. Use 'docker compose -f docker-compose-test.yml down' to stop it."