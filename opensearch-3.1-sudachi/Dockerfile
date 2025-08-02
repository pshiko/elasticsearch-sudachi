# OpenSearch 3.1.0 with Sudachi Plugin
FROM opensearchproject/opensearch:3.1.0

# Metadata
LABEL maintainer="OpenSearch Sudachi Plugin"
LABEL description="OpenSearch 3.1.0 with Sudachi Japanese Morphological Analyzer Plugin"
LABEL version="3.1.0-sudachi-3.3.1"

# Environment variables
ENV OPENSEARCH_HOME=/usr/share/opensearch
ENV SUDACHI_VERSION=3.3.1-SNAPSHOT
ENV SUDACHI_DICT_VERSION=20241021

# Switch to root user for plugin installation
USER root

# Install necessary tools
RUN yum update -y && \
    yum install -y wget unzip curl && \
    yum clean all

# Create sudachi config directory
RUN mkdir -p ${OPENSEARCH_HOME}/config/sudachi

# Download and install Sudachi dictionary
RUN cd /tmp && \
    wget -O sudachi-dictionary-${SUDACHI_DICT_VERSION}-core.zip \
    "https://github.com/WorksApplications/SudachiDict/releases/download/v${SUDACHI_DICT_VERSION}/sudachi-dictionary-${SUDACHI_DICT_VERSION}-core.zip" && \
    unzip sudachi-dictionary-${SUDACHI_DICT_VERSION}-core.zip && \
    cp sudachi-dictionary-${SUDACHI_DICT_VERSION}-core/system_core.dic ${OPENSEARCH_HOME}/config/sudachi/ && \
    rm -rf /tmp/sudachi-dictionary-*

# Copy pre-built plugin (assumes plugin is built in parent directory)
COPY ../build-jdk21/distributions/opensearch-3.1.0-analysis-sudachi-${SUDACHI_VERSION}.zip /tmp/

# Install Sudachi plugin
RUN cd ${OPENSEARCH_HOME} && \
    bin/opensearch-plugin install --batch file:///tmp/opensearch-3.1.0-analysis-sudachi-${SUDACHI_VERSION}.zip && \
    rm /tmp/opensearch-3.1.0-analysis-sudachi-${SUDACHI_VERSION}.zip

# Create basic sudachi configuration
RUN cat > ${OPENSEARCH_HOME}/config/sudachi/sudachi.json << 'EOF'
{
  "systemDict": "system_core.dic",
  "characterDefinitionFile": "char.def",
  "userDict": [],
  "inputTextPlugin": [
    {
      "class": "com.worksap.nlp.sudachi.DefaultInputTextPlugin"
    }
  ],
  "oovProviderPlugin": [
    {
      "class": "com.worksap.nlp.sudachi.MeCabOovProviderPlugin",
      "charDef": "char.def",
      "unkDef": "unk.def"
    }
  ],
  "pathRewritePlugin": [
    {
      "class": "com.worksap.nlp.sudachi.JoinNumericPlugin"
    },
    {
      "class": "com.worksap.nlp.sudachi.JoinKatakanaOovPlugin"
    }
  ]
}
EOF

# Set proper permissions
RUN chown -R opensearch:opensearch ${OPENSEARCH_HOME}/config/sudachi

# Switch back to opensearch user
USER opensearch

# Expose OpenSearch ports
EXPOSE 9200 9600

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:9200/_cluster/health || exit 1

# Default command
CMD ["./bin/opensearch"]