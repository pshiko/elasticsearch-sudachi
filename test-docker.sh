#!/usr/bin/env bash

set -euo pipefail

# Configuration
DEFAULT_ENGINE="opensearch"
DEFAULT_VERSION="2.18.0"

ENGINE=${ENGINE:-$DEFAULT_ENGINE}
VERSION=${VERSION:-$DEFAULT_VERSION}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Sudachi Plugin Docker Integration Test ==="
echo "Engine: $ENGINE"
echo "Version: $VERSION"
echo ""

# Function to build plugin in Docker
build_plugin() {
    echo "Building plugin with Docker..."
    
    # Build the Docker image
    docker build -f Dockerfile.build \
        --build-arg ENGINE_VERSION="${ENGINE}:${VERSION}" \
        -t sudachi-builder .
    
    if [ $? -ne 0 ]; then
        echo "❌ Plugin build failed"
        exit 1
    fi
    
    echo "✅ Plugin build completed"
    
    # Create a container to extract artifacts
    echo "Extracting build artifacts..."
    docker create --name sudachi-build-extract sudachi-builder
    docker cp sudachi-build-extract:/output ./build
    docker rm sudachi-build-extract
    
    # List built artifacts
    echo "Built artifacts:"
    find ./build -name "*.zip" -type f
}

# Function to prepare OpenSearch with plugin
prepare_opensearch() {
    echo "Preparing OpenSearch with plugin..."
    
    # Create init script for OpenSearch
    cat > opensearch-init.sh << 'EOF'
#!/bin/bash
set -e

echo "Installing Sudachi plugin..."

# Wait for build artifacts
while [ ! -f /build/distributions/*.zip ]; do
    echo "Waiting for plugin artifacts..."
    sleep 5
done

# Find and install plugin
PLUGIN_ZIP=$(find /build/distributions -name "*opensearch*sudachi*.zip" | head -1)
if [ -n "$PLUGIN_ZIP" ]; then
    echo "Installing plugin: $PLUGIN_ZIP"
    /usr/share/opensearch/bin/opensearch-plugin install "file://$PLUGIN_ZIP" --batch
else
    echo "❌ Plugin zip not found"
    exit 1
fi

# Download and setup dictionary
echo "Setting up Sudachi dictionary..."
cd /tmp
wget -q "http://sudachi.s3-website-ap-northeast-1.amazonaws.com/sudachidict/sudachi-dictionary-latest-small.zip"
mkdir -p /usr/share/opensearch/config/sudachi
unzip -p sudachi-dictionary-latest-small.zip "*/system_small.dic" > /usr/share/opensearch/config/sudachi/system_core.dic

echo "✅ Plugin and dictionary setup completed"

# Start OpenSearch
exec /usr/share/opensearch/opensearch-docker-entrypoint.sh
EOF

    chmod +x opensearch-init.sh
    
    echo "✅ OpenSearch preparation completed"
}

# Function to create custom OpenSearch Dockerfile
create_opensearch_dockerfile() {
    cat > Dockerfile.opensearch << EOF
FROM opensearchproject/opensearch:${VERSION}

USER root

# Install required tools
RUN yum update -y && yum install -y wget unzip

# Copy initialization script
COPY opensearch-init.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/opensearch-init.sh

USER opensearch

# Use custom entrypoint
ENTRYPOINT ["/usr/local/bin/opensearch-init.sh"]
EOF
}

# Function to start services
start_services() {
    echo "Starting services..."
    
    # Create custom OpenSearch service
    create_opensearch_dockerfile
    prepare_opensearch
    
    # Update docker-compose to use custom OpenSearch
    export ENGINE_VERSION="${ENGINE}:${VERSION}"
    
    # Build custom OpenSearch image
    docker build -f Dockerfile.opensearch -t opensearch-sudachi:${VERSION} .
    
    # Run OpenSearch container
    docker run -d --name opensearch-sudachi-test \
        -p 9200:9200 -p 9600:9600 \
        -v $(pwd)/build:/build:ro \
        -e "discovery.type=single-node" \
        -e "plugins.security.disabled=true" \
        -e "OPENSEARCH_INITIAL_ADMIN_PASSWORD=AdminPassword123!" \
        opensearch-sudachi:${VERSION}
    
    echo "Waiting for OpenSearch to be ready..."
    for i in {1..60}; do
        if curl -s "http://localhost:9200/_cluster/health" > /dev/null 2>&1; then
            echo "✅ OpenSearch is ready"
            
            # Test plugin installation
            if curl -s "http://localhost:9200/_analyze" -H "Content-Type: application/json" \
                -d '{"analyzer": "sudachi", "text": "テスト"}' | grep -q "tokens"; then
                echo "✅ Sudachi plugin is working"
                break
            else
                echo "❌ Sudachi plugin test failed"
                exit 1
            fi
        fi
        echo "Waiting... ($i/60)"
        sleep 5
    done
    
    if [ $i -eq 60 ]; then
        echo "❌ OpenSearch failed to start or plugin not working"
        docker logs opensearch-sudachi-test
        exit 1
    fi
}

# Function to run integration tests
run_tests() {
    echo "Running integration tests..."
    
    export ES_KIND="$ENGINE"
    export ES_VERSION="$VERSION"
    
    # Run integration tests in a container
    docker run --rm --network host \
        -v $(pwd)/test-scripts:/app/test-scripts \
        -e ES_KIND="$ENGINE" \
        -e ES_VERSION="$VERSION" \
        python:3.11-slim \
        bash -c "
            apt-get update && apt-get install -y curl &&
            pip install urllib3 &&
            cd /app/test-scripts &&
            python3 01-integration-test.py --host http://localhost --port 9200
        "
    
    if [ $? -eq 0 ]; then
        echo "✅ Integration tests completed successfully"
    else
        echo "❌ Integration tests failed"
        exit 1
    fi
}

# Function to cleanup
cleanup() {
    echo "Cleaning up..."
    docker stop opensearch-sudachi-test 2>/dev/null || true
    docker rm opensearch-sudachi-test 2>/dev/null || true
    docker rmi opensearch-sudachi:${VERSION} 2>/dev/null || true
    docker rmi sudachi-builder 2>/dev/null || true
    docker image prune -f
    rm -f opensearch-init.sh Dockerfile.opensearch
    rm -rf ./build
    echo "✅ Cleanup completed"
}

# Main execution
case "${1:-all}" in
    "build")
        build_plugin
        ;;
    "start")
        start_services
        ;;
    "test")
        run_tests
        ;;
    "cleanup")
        cleanup
        ;;
    "all")
        build_plugin
        start_services
        run_tests
        ;;
    *)
        echo "Usage: $0 [build|start|test|cleanup|all]"
        echo ""
        echo "Commands:"
        echo "  build    - Build the plugin in Docker"
        echo "  start    - Start OpenSearch with plugin"
        echo "  test     - Run integration tests"
        echo "  cleanup  - Stop and clean up Docker containers"
        echo "  all      - Run complete test cycle (default)"
        echo ""
        echo "Environment variables:"
        echo "  ENGINE=[opensearch|elasticsearch] (default: opensearch)"
        echo "  VERSION=<version> (default: 2.18.0)"
        exit 1
        ;;
esac

echo ""
echo "=== Docker Integration Test Complete ==="