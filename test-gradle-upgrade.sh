#!/bin/bash

# Test Gradle 8.5 compatibility

echo "=== Testing Gradle 8.5 Compatibility ==="

# Update gradle wrapper
./gradlew wrapper --gradle-version=8.5

# Test with different engine versions
echo ""
echo "Testing with OpenSearch 2.18.0 (JDK11)..."
./gradlew -PengineVersion=os:2.18.0 clean compileJava compileKotlin

echo ""
echo "Testing with OpenSearch 3.1.0 (JDK21)..."
./gradlew -PengineVersion=os:3.1.0 clean compileJava compileKotlin

echo ""
echo "Testing with ElasticSearch 8.15.2..."
./gradlew -PengineVersion=es:8.15.2 clean compileJava compileKotlin

echo "=== Gradle 8.5 compatibility test completed ==="