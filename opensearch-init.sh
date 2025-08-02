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
