# Use the official PostgreSQL image as the base image
FROM postgres:latest

# Set environment variables for the new user and password

ARG DST_USER=synclite
ARG DST_PASSWORD=synclite
ARG DST_DB=synclitedb

ENV POSTGRES_USER ${DST_USER}
ENV POSTGRES_PASSWORD ${DST_PASSWORD}

# Create a custom database if needed (Optional)
ENV POSTGRES_DB ${DST_DB}

# Optional: Set the locale (adjust as needed)
ENV LANG en_US.utf8

# Optional: Expose the PostgreSQL port (default is 5432)
EXPOSE 5432

# Specify the mount point for PostgreSQL data inside the container
VOLUME /var/lib/postgresql/data

# Install pgvector extension
RUN apt-get update && \
    apt-get install -y git postgresql-server-dev-all gcc make && \
    git clone https://github.com/pgvector/pgvector.git && \
    cd pgvector && \
    make && \
    make install && \
    cd .. && \
    rm -rf pgvector && \
    apt-get remove -y gcc make postgresql-server-dev-all git && \
    apt-get autoremove -y && \
    apt-get clean

# Create the pgvector extension in the default database
RUN echo "CREATE EXTENSION IF NOT EXISTS vector;" > /docker-entrypoint-initdb.d/init-pgvector.sql
