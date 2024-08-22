# Use the official PostgreSQL image as the base image
FROM mysql:latest

# Set environment variables for the new user and password
ARG DST_USER=synclite
ARG DST_PASSWORD=synclite 
ARG DST_SCHEMA_NAME=syncliteschema

# Use the official MySQL image as the base image
FROM mysql:latest

# Set environment variables for the new user and password
ENV MYSQL_USER ${DST_USER}
ENV MYSQL_PASSWORD ${DST_PASSWORD}

# Optional: Set the database name
ENV MYSQL_DATABASE ${DST_SCHEMA_NAME}

# Create a directory on the container to hold the database data
VOLUME /var/lib/mysql

# Expose the MySQL port (default is 3306)
EXPOSE 3306
