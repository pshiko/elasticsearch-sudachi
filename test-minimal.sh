#!/usr/bin/env bash

set -euo pipefail

echo "=== Minimal Integration Test ==="

# Function to start OpenSearch in Docker
start_opensearch() {
    echo "Starting OpenSearch 2.18.0..."
    
    docker run -d --name opensearch-minimal-test \
        -p 9200:9200 -p 9600:9600 \
        -e "discovery.type=single-node" \
        -e "plugins.security.disabled=true" \
        -e "OPENSEARCH_INITIAL_ADMIN_PASSWORD=AdminPassword123!" \
        opensearchproject/opensearch:2.18.0
    
    echo "Waiting for OpenSearch to be ready..."
    for i in {1..30}; do
        if curl -s "http://localhost:9200/_cluster/health" > /dev/null 2>&1; then
            echo "✅ OpenSearch is ready"
            return 0
        fi
        echo "Waiting... ($i/30)"
        sleep 5
    done
    
    echo "❌ OpenSearch failed to start"
    docker logs opensearch-minimal-test
    exit 1
}

# Function to test basic OpenSearch functionality
test_basic_opensearch() {
    echo "Testing basic OpenSearch functionality..."
    
    # Test cluster health
    HEALTH=$(curl -s "http://localhost:9200/_cluster/health" | grep -o '"status":"[^"]*"' || echo 'FAILED')
    echo "Cluster health: $HEALTH"
    
    # Test basic analysis
    RESULT=$(curl -s -X POST "http://localhost:9200/_analyze" \
        -H "Content-Type: application/json" \
        -d '{"analyzer": "standard", "text": "test"}' | grep -o '"token":"[^"]*"' || echo 'FAILED')
    echo "Basic analysis: $RESULT"
    
    if [[ "$HEALTH" == *"green"* ]] || [[ "$HEALTH" == *"yellow"* ]]; then
        echo "✅ Basic OpenSearch functionality OK"
    else
        echo "❌ Basic OpenSearch functionality failed"
        exit 1
    fi
}

# Function to copy plugin to container (manual install)
install_plugin_manually() {
    echo "Installing Sudachi plugin manually..."
    
    # Check if plugin file exists
    PLUGIN_FILE="build/distributions/opensearch-2.18.0-analysis-sudachi-3.3.1-SNAPSHOT.zip"
    if [ ! -f "$PLUGIN_FILE" ]; then
        echo "❌ Plugin file not found: $PLUGIN_FILE"
        echo "Please run: docker run --rm -v \$(pwd):/workspace -w /workspace gradle:8.5-jdk11 ./gradlew -PengineVersion=os:2.18.0 assemble --no-daemon"
        exit 1
    fi
    
    # Create a simple install script
    cat > install-plugin.sh << 'EOF'
#!/bin/bash
set -e
cd /tmp
echo "Installing Sudachi plugin..."
/usr/share/opensearch/bin/opensearch-plugin install file:///tmp/plugin.zip --batch
echo "Plugin installed, restarting OpenSearch..."
EOF
    
    # Copy files to container
    docker cp "$PLUGIN_FILE" opensearch-minimal-test:/tmp/plugin.zip
    docker cp install-plugin.sh opensearch-minimal-test:/tmp/install-plugin.sh
    
    # Make script executable and run it
    docker exec opensearch-minimal-test chmod +x /tmp/install-plugin.sh
    docker exec opensearch-minimal-test /tmp/install-plugin.sh
    
    # Restart container to load plugin
    echo "Restarting OpenSearch to load plugin..."
    docker restart opensearch-minimal-test
    
    # Wait for restart
    echo "Waiting for OpenSearch to restart..."
    sleep 20
    
    for i in {1..20}; do
        if curl -s "http://localhost:9200/_cluster/health" > /dev/null 2>&1; then
            echo "✅ OpenSearch restarted successfully"
            break
        fi
        echo "Waiting for restart... ($i/20)"
        sleep 5
    done
    
    if [ $i -eq 20 ]; then
        echo "❌ OpenSearch failed to restart"
        docker logs opensearch-minimal-test
        exit 1
    fi
}

# Function to test Sudachi plugin
test_sudachi_plugin() {
    echo "Testing Sudachi plugin..."
    
    # Test if Sudachi analyzer is available
    RESULT=$(curl -s -X POST "http://localhost:9200/_analyze" \
        -H "Content-Type: application/json" \
        -d '{"analyzer": "sudachi", "text": "テスト"}' 2>/dev/null || echo 'FAILED')
    
    if [[ "$RESULT" == *"tokens"* ]]; then
        echo "✅ Sudachi plugin is working"
        echo "Sample result: $(echo "$RESULT" | head -c 200)..."
        return 0
    else
        echo "❌ Sudachi plugin test failed"
        echo "Error response: $RESULT"
        
        # Check plugin list
        echo "Checking installed plugins..."
        PLUGINS=$(curl -s "http://localhost:9200/_cat/plugins" || echo 'FAILED')
        echo "Installed plugins: $PLUGINS"
        
        exit 1
    fi
}

# Function to cleanup
cleanup() {
    echo "Cleaning up..."
    docker stop opensearch-minimal-test 2>/dev/null || true
    docker rm opensearch-minimal-test 2>/dev/null || true
    rm -f install-plugin.sh
    echo "✅ Cleanup completed"
}

# Main execution
case "${1:-all}" in
    "start")
        start_opensearch
        test_basic_opensearch
        ;;
    "install")
        install_plugin_manually
        ;;
    "test")
        test_sudachi_plugin
        ;;
    "cleanup")
        cleanup
        ;;
    "all")
        cleanup  # Clean up any existing containers first
        start_opensearch
        test_basic_opensearch
        install_plugin_manually
        test_sudachi_plugin
        echo "✅ All minimal tests passed!"
        ;;
    *)
        echo "Usage: $0 [start|install|test|cleanup|all]"
        echo ""
        echo "Commands:"
        echo "  start    - Start OpenSearch and test basic functionality"
        echo "  install  - Install Sudachi plugin manually"
        echo "  test     - Test Sudachi plugin functionality"
        echo "  cleanup  - Stop and clean up containers"
        echo "  all      - Run complete minimal test (default)"
        exit 1
        ;;
esac

echo ""
echo "=== Minimal Test Complete ==="