#!/bin/bash

# Test bytecode compatibility between JDK11-built plugin and JDK21 OpenSearch

set -e

echo "=== Bytecode Compatibility Test ==="
echo "OpenSearch 3.1.0 (JDK21) vs Sudachi Plugin (JDK11)"

# Check current plugin files
echo "Current plugin jar info:"
if [ -f "build/libs/analysis-sudachi-3.3.1-SNAPSHOT.jar" ]; then
    echo "Plugin jar exists: $(ls -la build/libs/analysis-sudachi-3.3.1-SNAPSHOT.jar)"
    # Try to inspect jar bytecode version
    unzip -p build/libs/analysis-sudachi-3.3.1-SNAPSHOT.jar 'com/worksap/nlp/elasticsearch/sudachi/plugin/AnalysisSudachiPlugin.class' | od -t x1 -N 8 | head -1 || echo "Could not extract class file"
else
    echo "Plugin jar not found in build/libs/"
fi

echo ""
echo "OpenSearch 3.1.0 version info:"
curl -s http://localhost:9201/ | jq '.version'

echo ""
echo "Java version in OpenSearch 3.1.0 container:"
docker exec opensearch-3-1-test java -version

echo ""
echo "=== Compatibility Test Results ==="
echo "1. OpenSearch 3.1.0: JDK21, Lucene 10.2.1"
echo "2. Current plugin: Built with JDK11"
echo "3. Expected issue: Bytecode compatibility problems"

# Basic API test
echo ""
echo "Basic API test:"
curl -X GET "http://localhost:9201/_analyze" \
  -H "Content-Type: application/json" \
  -d '{"analyzer": "standard", "text": "test"}' | jq '.'

echo ""
echo "=== Next Steps ==="
echo "• Build plugin with JDK21 for full compatibility"
echo "• Update Dockerfile.build to use JDK21"
echo "• Create OpenSearch 3.x compatibility layer"