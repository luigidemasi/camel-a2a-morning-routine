# Reusable Dockerfile for Camel agents
# Build with: docker build -f dockerfiles/camel-agent.Dockerfile --build-arg AGENT_NAME=<agent-name> -t <agent-name> .

ARG AGENT_NAME
ARG CAMEL_VERSION=4.21.0-SNAPSHOT

FROM registry.access.redhat.com/ubi9/openjdk-21:latest

# Install Camel JBang
RUN curl -Ls https://sh.jbang.dev | bash -s - app install camel@apache/camel

WORKDIR /app

# Copy agent-specific source files
ARG AGENT_NAME
COPY ${AGENT_NAME}/ .

EXPOSE 8080

# Run Camel JBang with dependencies
ARG CAMEL_VERSION
CMD jbang camel@apache/camel run * \
    --camel-version=${CAMEL_VERSION} \
    --dep=org.apache.camel:camel-a2a:${CAMEL_VERSION} \
    --dep=org.apache.camel:camel-oauth:${CAMEL_VERSION} \
    --logging-level=info
