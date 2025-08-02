#!/usr/bin/env bash

set -euo pipefail

# Configuration
ENGINE=${ENGINE:-opensearch}
ENGINE_VERSION=${ENGINE_VERSION:-"os:2.18.0"}

echo "=== Sudachi Plugin Docker Test ==="
echo "Engine Version: $ENGINE_VERSION"
echo ""

# Function to build plugin using Docker
build_plugin() {
    echo "Building plugin with Docker..."
    
    # Use gradle Docker image to build
    docker run --rm \
        -v "$(pwd)":/workspace \
        -w /workspace \
        gradle:8.5-jdk11 \
        ./gradlew -PengineVersion="$ENGINE_VERSION" build --no-daemon
    
    if [ $? -ne 0 ]; then
        echo "❌ Plugin build failed"
        exit 1
    fi
    
    echo "✅ Plugin build completed"
    
    # List built artifacts
    echo "Built artifacts:"
    find build/distributions -name "*.zip" -type f 2>/dev/null || echo "No zip files found"
}

# Function to test basic functionality
test_basic() {
    echo "Testing basic build functionality..."
    
    # Check if distributions were created
    if [ -d "build/distributions" ] && [ "$(ls -A build/distributions 2>/dev/null)" ]; then
        echo "✅ Build distributions created"
        ls -la build/distributions/
    else
        echo "❌ No build distributions found"
        exit 1
    fi
}

# Function to run unit tests
run_unit_tests() {
    echo "Running unit tests with Docker..."
    
    docker run --rm \
        -v "$(pwd)":/workspace \
        -w /workspace \
        gradle:8.5-jdk11 \
        ./gradlew -PengineVersion="$ENGINE_VERSION" test --no-daemon
    
    if [ $? -eq 0 ]; then
        echo "✅ Unit tests passed"
    else
        echo "❌ Unit tests failed"
        exit 1
    fi
}

# Function to run integration test setup
prepare_integration_test() {
    echo "Preparing integration test environment..."
    
    # Check if we have the required files for integration testing
    if [ ! -f "test-scripts/01-integration-test.py" ]; then
        echo "❌ Integration test script not found"
        exit 1
    fi
    
    # Run a simple Python syntax check
    docker run --rm \
        -v "$(pwd)/test-scripts":/scripts \
        python:3.11-slim \
        python3 -m py_compile /scripts/01-integration-test.py
    
    if [ $? -eq 0 ]; then
        echo "✅ Integration test script syntax OK"
    else
        echo "❌ Integration test script has syntax errors"
        exit 1
    fi
}

# Function to cleanup
cleanup() {
    echo "Cleaning up build artifacts..."
    rm -rf build/
    echo "✅ Cleanup completed"
}

# Main execution
case "${1:-build}" in
    "build")
        build_plugin
        test_basic
        ;;
    "test")
        run_unit_tests
        ;;
    "prepare")
        prepare_integration_test
        ;;
    "cleanup")
        cleanup
        ;;
    "all")
        build_plugin
        test_basic
        run_unit_tests
        prepare_integration_test
        ;;
    *)
        echo "Usage: $0 [build|test|prepare|cleanup|all]"
        echo ""
        echo "Commands:"
        echo "  build    - Build the plugin using Docker (default)"
        echo "  test     - Run unit tests"
        echo "  prepare  - Prepare integration test environment"
        echo "  cleanup  - Clean up build artifacts"
        echo "  all      - Run build, test, and prepare"
        echo ""
        echo "Environment variables:"
        echo "  ENGINE_VERSION=<version> (default: os:2.18.0)"
        exit 1
        ;;
esac

echo ""
echo "=== Docker Test Complete ==="