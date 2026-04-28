# ── Build stage ────────────────────────────────────────────────────────────────
FROM ubuntu:24.04 AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user for running SyncLite
RUN groupadd -r synclite && \
    useradd -r -g synclite -d /home/synclite -s /sbin/nologin synclite && \
    mkdir -p /home/synclite && \
    chown synclite:synclite /home/synclite

ENV HOME=/home/synclite

WORKDIR /synclite

COPY synclite-platform.tar.gz /synclite/synclite-platform.tar.gz

RUN tar -xf /synclite/synclite-platform.tar.gz -C /synclite && \
    chmod +x /synclite/bin/*.sh

# Override packaged scripts with current hardened scripts from build context.
COPY deploy.sh deploy.bat start.sh start.bat stop.sh stop.bat docker-deploy.sh docker-start.sh docker-stop.sh /synclite/bin/
RUN chmod +x /synclite/bin/*.sh

WORKDIR /synclite/bin

RUN ./deploy.sh && \
    rm -rf /synclite/lib \
           /synclite/tools/synclite-dbreader \
           /synclite/tools/synclite-qreader \
           /synclite/tools/synclite-jobmonitor \
           /synclite/tools/synclite-validator \
           /synclite/synclite-platform.tar.gz && \
    chown -R synclite:synclite /synclite

# ── Runtime stage ──────────────────────────────────────────────────────────────
FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd -r synclite && \
    useradd -r -g synclite -d /home/synclite -s /sbin/nologin synclite && \
    mkdir -p /home/synclite && \
    chown synclite:synclite /home/synclite

ENV HOME=/home/synclite \
    JAVA_HOME=/synclite/bin/jdk-25 \
    CATALINA_HOME=/synclite/bin/apache-tomcat-9.0.117
ENV PATH="${JAVA_HOME}/bin:${CATALINA_HOME}/bin:${PATH}"

COPY --from=builder --chown=synclite:synclite /synclite /synclite

WORKDIR /synclite/bin

USER synclite
EXPOSE 8080

CMD ["catalina.sh", "run"]
