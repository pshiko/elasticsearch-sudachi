#!/usr/bin/env bash

set -euo pipefail

# Configuration
DEFAULT_ENGINE="opensearch"
DEFAULT_VERSION="2.18.0"
DEFAULT_PLUGIN_VERSION="3.1.1"

ENGINE=${ENGINE:-$DEFAULT_ENGINE}
VERSION=${VERSION:-$DEFAULT_VERSION}
PLUGIN_VERSION=${PLUGIN_VERSION:-$DEFAULT_PLUGIN_VERSION}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/build/integration-test"

echo "=== Sudachi Plugin Integration Test ==="
echo "Engine: $ENGINE"
echo "Version: $VERSION"
echo "Plugin Version: $PLUGIN_VERSION"
echo "Work Directory: $WORK_DIR"
echo ""

# Create work directory
mkdir -p "$WORK_DIR"

# Function to build plugin
build_plugin() {
    echo "Building plugin..."
    ./gradlew -PengineVersion="${ENGINE}:${VERSION}" build
    if [ $? -ne 0 ]; then
        echo "❌ Plugin build failed"
        exit 1
    fi
    echo "✅ Plugin build completed"
}

# Function to prepare plugin and dictionary
prepare_plugin() {
    echo "Preparing plugin files..."
    
    # Create plugin directory structure
    mkdir -p "$WORK_DIR/plugins/analysis-sudachi"
    mkdir -p "$WORK_DIR/config/sudachi"
    
    # Copy plugin files
    PLUGIN_ZIP="build/distributions/${ENGINE}-${VERSION}-analysis-sudachi-${PLUGIN_VERSION}.zip"
    if [ ! -f "$PLUGIN_ZIP" ]; then
        echo "❌ Plugin zip not found: $PLUGIN_ZIP"
        echo "Please run: ./gradlew -PengineVersion=${ENGINE}:${VERSION} build"
        exit 1
    fi
    
    # Extract plugin to directory
    cd "$WORK_DIR"
    unzip -o "$SCRIPT_DIR/$PLUGIN_ZIP" -d plugins/analysis-sudachi/
    cd "$SCRIPT_DIR"
    
    # Download and prepare Sudachi dictionary
    DIC_VERSION="latest"
    DIC_KIND="small"
    DIC_ZIP="$WORK_DIR/sudachi-dictionary-${DIC_VERSION}-${DIC_KIND}.zip"
    
    if [ ! -f "$DIC_ZIP" ]; then
        echo "Downloading Sudachi dictionary..."
        wget --progress=dot:giga -O "$DIC_ZIP" \
            "http://sudachi.s3-website-ap-northeast-1.amazonaws.com/sudachidict/sudachi-dictionary-${DIC_VERSION}-${DIC_KIND}.zip"
    fi
    
    echo "Extracting dictionary..."
    unzip -p "$DIC_ZIP" "*/system_${DIC_KIND}.dic" > "$WORK_DIR/config/sudachi/system_core.dic"
    
    echo "✅ Plugin and dictionary prepared"
}

# Function to start search engine with Docker
start_engine() {
    echo "Starting $ENGINE $VERSION with Docker..."
    
    # Update docker-compose for specific version
    export COMPOSE_PROJECT_NAME="sudachi-test"
    
    if [ "$ENGINE" = "opensearch" ]; then
        docker-compose up -d opensearch
        HEALTH_URL="http://localhost:9200/_cluster/health"
    else
        docker-compose up -d elasticsearch  
        HEALTH_URL="http://localhost:9200/_cluster/health"
    fi
    
    echo "Waiting for $ENGINE to be ready..."
    for i in {1..30}; do
        if curl -s "$HEALTH_URL" > /dev/null 2>&1; then
            echo "✅ $ENGINE is ready"
            break
        fi
        echo "Waiting... ($i/30)"
        sleep 5
    done
    
    if [ $i -eq 30 ]; then
        echo "❌ $ENGINE failed to start"
        docker-compose logs
        exit 1
    fi
}

# Function to install plugin to running engine
install_plugin() {
    echo "Installing plugin to running $ENGINE..."
    
    CONTAINER_NAME="${ENGINE}-sudachi-test"
    PLUGIN_DIR="/usr/share/${ENGINE}/plugins/analysis-sudachi"
    CONFIG_DIR="/usr/share/${ENGINE}/config/sudachi"
    
    # Copy plugin files
    docker cp "$WORK_DIR/plugins/analysis-sudachi/." "${CONTAINER_NAME}:${PLUGIN_DIR}/"
    docker cp "$WORK_DIR/config/sudachi/." "${CONTAINER_NAME}:${CONFIG_DIR}/"
    
    # Restart container to load plugin
    docker-compose restart $ENGINE
    
    # Wait for restart
    sleep 10
    start_engine
    
    echo "✅ Plugin installed"
}

# Function to run integration tests
run_tests() {
    echo "Running integration tests..."
    
    export ES_KIND="$ENGINE"
    export ES_VERSION="$VERSION"
    export PLUGIN_VERSION="$PLUGIN_VERSION"
    
    cd test-scripts
    python3 01-integration-test.py --host http://localhost --port 9200
    cd ..
    
    echo "✅ Integration tests completed"
}

# Function to cleanup
cleanup() {
    echo "Cleaning up..."
    docker-compose down -v
    echo "✅ Cleanup completed"
}

# Main execution
case "${1:-all}" in
    "build")
        build_plugin
        ;;
    "prepare")
        prepare_plugin
        ;;
    "start")
        start_engine
        ;;
    "install")
        install_plugin
        ;;
    "test")
        run_tests
        ;;
    "cleanup")
        cleanup
        ;;
    "all")
        build_plugin
        prepare_plugin
        start_engine
        install_plugin
        run_tests
        ;;
    *)
        echo "Usage: $0 [build|prepare|start|install|test|cleanup|all]"
        echo ""
        echo "Commands:"
        echo "  build    - Build the plugin"
        echo "  prepare  - Prepare plugin and dictionary files"
        echo "  start    - Start search engine with Docker"
        echo "  install  - Install plugin to running engine"
        echo "  test     - Run integration tests"
        echo "  cleanup  - Stop and clean up Docker containers"
        echo "  all      - Run complete test cycle (default)"
        echo ""
        echo "Environment variables:"
        echo "  ENGINE=[opensearch|elasticsearch] (default: opensearch)"
        echo "  VERSION=<version> (default: 2.18.0)"
        echo "  PLUGIN_VERSION=<version> (default: 3.1.1)"
        exit 1
        ;;
esac

echo ""
echo "=== Integration Test Complete ==="