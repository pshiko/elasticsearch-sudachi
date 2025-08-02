#!/usr/bin/env bash

set -euo pipefail

echo "=== Installing Sudachi Plugin to OpenSearch 2.18.0 ==="

# Configuration
CONTAINER_NAME="opensearch-simple"
PLUGIN_FILE="build/distributions/opensearch-2.18.0-analysis-sudachi-3.3.1-SNAPSHOT.zip"

# Start OpenSearch
echo "Starting OpenSearch 2.18.0..."
docker run -d --name $CONTAINER_NAME \
    -p 9200:9200 -p 9600:9600 \
    -e "discovery.type=single-node" \
    -e "plugins.security.disabled=true" \
    -e "OPENSEARCH_INITIAL_ADMIN_PASSWORD=MyStr0ng!Pass123#" \
    opensearchproject/opensearch:2.18.0

# Wait for OpenSearch to be ready
echo "Waiting for OpenSearch to be ready..."
for i in {1..30}; do
    if curl -s "http://localhost:9200/_cluster/health" > /dev/null 2>&1; then
        echo "✅ OpenSearch is ready"
        break
    fi
    echo "Waiting... ($i/30)"
    sleep 5
done

# Copy plugin file to container
echo "Copying plugin to container..."
docker cp "$PLUGIN_FILE" $CONTAINER_NAME:/tmp/plugin.zip

# Install plugin
echo "Installing plugin..."
docker exec $CONTAINER_NAME /usr/share/opensearch/bin/opensearch-plugin install file:///tmp/plugin.zip --batch

# Download and install dictionary
echo "Installing Sudachi dictionary..."
docker exec $CONTAINER_NAME bash -c "
    cd /tmp && \
    curl -s -L -o dict.zip 'http://sudachi.s3-website-ap-northeast-1.amazonaws.com/sudachidict/sudachi-dictionary-latest-small.zip' && \
    mkdir -p /usr/share/opensearch/config/sudachi && \
    unzip -p dict.zip '*/system_small.dic' > /usr/share/opensearch/config/sudachi/system_core.dic
"

# Restart OpenSearch
echo "Restarting OpenSearch..."
docker restart $CONTAINER_NAME

# Wait for restart
echo "Waiting for OpenSearch to restart..."
sleep 10
for i in {1..30}; do
    if curl -s "http://localhost:9200/_cluster/health" > /dev/null 2>&1; then
        echo "✅ OpenSearch restarted"
        break
    fi
    echo "Waiting... ($i/30)"
    sleep 5
done

# Test Sudachi
echo "Testing Sudachi plugin..."
curl -X POST "http://localhost:9200/_analyze" \
    -H "Content-Type: application/json" \
    -d '{"analyzer": "sudachi", "text": "東京都に行きました"}' | jq .

echo ""
echo "✅ Plugin installation complete!"
echo "Container name: $CONTAINER_NAME"
echo "To run tests: docker run --rm --network container:$CONTAINER_NAME -v \$(pwd)/test-scripts:/app python:3.11-slim bash -c 'pip install urllib3 && cd /app && python3 01-integration-test.py --host http://localhost --port 9200'"
echo "To stop: docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME"