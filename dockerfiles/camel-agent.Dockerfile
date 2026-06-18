ARG AGENT_NAME
ARG CAMEL_VERSION=4.21.0-SNAPSHOT

FROM registry.access.redhat.com/ubi9/openjdk-21:latest

ENV CAMEL_VERSION=${CAMEL_VERSION}

RUN curl -Ls https://sh.jbang.dev | bash -s - app install --fresh --force jbang && \
    mkdir -p $HOME/.jbang && \
    echo '{"trustedSources": ["https://github.com/apache/camel/"]}' > $HOME/.jbang/trusted-sources.json && \
    jbang app install camel@apache/camel

WORKDIR /app

COPY ${AGENT_NAME}/ .

EXPOSE 8080

CMD ["sh", "-c", "jbang camel@apache/camel run * --camel-version=${CAMEL_VERSION} --dep=org.apache.camel:camel-a2a:${CAMEL_VERSION} --dep=org.apache.camel:camel-oauth:${CAMEL_VERSION} --logging-level=info"]
