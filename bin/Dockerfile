# Use the Ubuntu base image
FROM ubuntu:20.04 as builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create the home directory for the root user, set ownership and permissions, and set the HOME environment variable
RUN mkdir -p /home/root && \
    chown -R root:root /home/root && \
    chmod 700 /home/root

# Set the HOME environment variable for the root user
ENV HOME=/home/root

WORKDIR /synclite

# Copy files from the RELEASE_DIR to /synclite/
COPY synclite-platform.tar.gz /synclite/synclite-platform.tar.gz

RUN tar -xf /synclite/synclite-platform.tar.gz -C /synclite && \
    chmod +x /synclite/bin/*.sh

WORKDIR /synclite/bin

RUN ./deploy.sh && \
     rm -rf /synclite/lib && \
     rm -rf /synclite/tools/synclite-dbreader && \
     rm -rf /synclite/tools/synclite-qreader && \
     rm -rf /synclite/tools/synclite-jobmonitor && \
     rm -rf /synclite/tools/synclite-validator && \
     rm -rf /synclite/synclite-platform.tar.gz
	 
FROM ubuntu:20.04

# Create the home directory for the root user, set ownership and permissions, and set the HOME environment variable
RUN mkdir -p /home/root && \
    chown -R root:root /home/root && \
    chmod 700 /home/root

# Set the HOME environment variable for the root user
ENV HOME=/home/root

COPY --from=builder /synclite /synclite

WORKDIR /synclite/bin

