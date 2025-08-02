#!/usr/bin/env bash

set -euo pipefail

echo "=== OpenSearch 2.18.0 Integration Test with Docker ==="

# Configuration
ENGINE_KIND="opensearch"
ENGINE_VERSION="2.18.0"
PLUGIN_VERSION="3.3.1-SNAPSHOT"

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    docker stop opensearch-integration-test 2>/dev/null || true
    docker rm opensearch-integration-test 2>/dev/null || true
    echo "✅ Cleanup completed"
}

# Start OpenSearch with plugin
start_opensearch_with_plugin() {
    echo "Starting OpenSearch $ENGINE_VERSION with Sudachi plugin..."
    
    # Check if plugin file exists
    PLUGIN_FILE="build/distributions/opensearch-${ENGINE_VERSION}-analysis-sudachi-${PLUGIN_VERSION}.zip"
    if [ ! -f "$PLUGIN_FILE" ]; then
        echo "❌ Plugin file not found: $PLUGIN_FILE"
        echo "Building plugin first..."
        docker run --rm -v "$(pwd)":/workspace -w /workspace gradle:8.5-jdk11 \
            ./gradlew -PengineVersion="os:${ENGINE_VERSION}" assemble --no-daemon
    fi
    
    # Create init script
    cat > opensearch-init.sh << 'EOF'
#!/bin/bash
set -e

echo "Installing required tools..."
yum update -y -q
yum install -y -q unzip

echo "Installing Sudachi plugin..."
/usr/share/opensearch/bin/opensearch-plugin install file:///plugin.zip --batch

echo "Downloading Sudachi dictionary..."
cd /tmp
curl -s -L -o sudachi-dictionary-latest-small.zip "http://sudachi.s3-website-ap-northeast-1.amazonaws.com/sudachidict/sudachi-dictionary-latest-small.zip"
mkdir -p /usr/share/opensearch/config/sudachi
unzip -p sudachi-dictionary-latest-small.zip "*/system_small.dic" > /usr/share/opensearch/config/sudachi/system_core.dic

echo "✅ Plugin and dictionary setup completed"
echo "Starting OpenSearch..."
# Change ownership and start as opensearch user
chown -R opensearch:opensearch /usr/share/opensearch
su opensearch -c "/usr/share/opensearch/opensearch-docker-entrypoint.sh"
EOF
    
    chmod +x opensearch-init.sh
    
    # Start OpenSearch container with plugin
    docker run -d --name opensearch-integration-test --user root \
        -p 9200:9200 -p 9600:9600 \
        -v "$(pwd)/$PLUGIN_FILE":/plugin.zip:ro \
        -v "$(pwd)/opensearch-init.sh":/usr/local/bin/opensearch-init.sh:ro \
        -v "$(pwd)/test-scripts/opensearch.yml":/usr/share/opensearch/config/opensearch.yml:ro \
        -e "discovery.type=single-node" \
        -e "plugins.security.disabled=true" \
        -e "OPENSEARCH_INITIAL_ADMIN_PASSWORD=AdminPassword123!" \
        --entrypoint /usr/local/bin/opensearch-init.sh \
        opensearchproject/opensearch:${ENGINE_VERSION}
    
    echo "Waiting for OpenSearch to be ready..."
    for i in {1..60}; do
        if curl -s "http://localhost:9200/_cluster/health" > /dev/null 2>&1; then
            echo "✅ OpenSearch is ready"
            
            # Test Sudachi plugin
            echo "Testing Sudachi plugin..."
            RESULT=$(curl -s -X POST "http://localhost:9200/_analyze" \
                -H "Content-Type: application/json" \
                -d '{"analyzer": "sudachi", "text": "テスト"}' || echo 'FAILED')
            
            if [[ "$RESULT" == *"tokens"* ]]; then
                echo "✅ Sudachi plugin is working"
                return 0
            else
                echo "❌ Sudachi plugin test failed: $RESULT"
                exit 1
            fi
        fi
        echo "Waiting... ($i/60)"
        sleep 5
    done
    
    echo "❌ OpenSearch failed to start or plugin not working"
    docker logs opensearch-integration-test
    exit 1
}

# Run integration tests
run_integration_tests() {
    echo "Running integration tests..."
    
    # Run integration test in Docker
    docker run --rm --network host \
        -v "$(pwd)/test-scripts":/app/test-scripts \
        -e ES_KIND="$ENGINE_KIND" \
        -e ES_VERSION="$ENGINE_VERSION" \
        python:3.11-slim \
        bash -c "
            apt-get update -qq && apt-get install -y -qq curl &&
            pip install urllib3 &&
            cd /app/test-scripts &&
            python3 01-integration-test.py --host http://localhost --port 9200
        "
    
    if [ $? -eq 0 ]; then
        echo "✅ Integration tests completed successfully"
        return 0
    else
        echo "❌ Integration tests failed"
        return 1
    fi
}

# Main execution
case "${1:-all}" in
    "start")
        cleanup
        start_opensearch_with_plugin
        ;;
    "test")
        run_integration_tests
        ;;
    "cleanup")
        cleanup
        ;;
    "all")
        cleanup
        start_opensearch_with_plugin
        run_integration_tests
        echo ""
        echo "✅ All integration tests completed successfully!"
        ;;
    *)
        echo "Usage: $0 [start|test|cleanup|all]"
        echo ""
        echo "Commands:"
        echo "  start    - Start OpenSearch with Sudachi plugin"
        echo "  test     - Run integration tests"
        echo "  cleanup  - Stop and clean up containers"
        echo "  all      - Run complete integration test (default)"
        exit 1
        ;;
esac

# Cleanup temp files
rm -f opensearch-init.sh

echo ""
echo "=== Integration Test Complete ==="