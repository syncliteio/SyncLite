# Use Ubuntu as the base image
FROM ubuntu:20.04

# Install dependencies
RUN apt-get update && apt-get install -y vim && apt-get install -y curl

# Set environment variables for access and secret keys
ARG MINIO_ROOT_USER=synclite_root
ARG MINIO_ROOT_PASSWORD=synclite
ARG BUCKET_NAME=synclite-devices
ARG UPLOAD_USER=synclite
ARG UPLOAD_USER_PASSWORD=synclite
ARG DOWNLOAD_USER=synclite_consolidator
ARG DOWNLOAD_USER_PASSWORD=synclite
ARG HOST_IP_ADDRESS=$(hostname -I | cut -d' ' -f1)
ARG ENABLE_HTTPS=false

# Download MinIO Server using curl
RUN curl -o /usr/bin/minio https://dl.minio.io/server/minio/release/linux-amd64/minio && \
    chmod +x /usr/bin/minio

RUN curl -o /usr/bin/mc https://dl.minio.io/client/mc/release/linux-amd64/mc && \
    chmod +x /usr/bin/mc


# Create a very restrictive upload only access policy file for "UPLOAD_USER" user
RUN echo '{ \
  "Version": "2012-10-17", \
  "Statement": [ \
    { \
      "Effect": "Allow", \
      "Action": ["s3:GetBucketLocation"], \
      "Resource": ["arn:aws:s3:::${BUCKET_NAME}"] \
    }, \
    { \
      "Effect": "Allow", \
      "Action": ["s3:PutObject"], \
      "Resource": ["arn:aws:s3:::${BUCKET_NAME}/synclite-*"] \
    } \
  ] \
}' > /usr/bin/synclite_upload_user_policy.json

# Create a policy file with full bucket access for "DOWNLOAD_USER" user
RUN echo '{ \
    "Version": "2012-10-17", \
    "Statement": [ \
        { \
            "Effect": "Allow", \
            "Action": [ \
                "s3:ListBucket" \
            ], \
            "Resource": [ \
                "arn:aws:s3:::${BUCKET_NAME}" \
            ] \
        }, \
        { \
            "Effect": "Allow", \
            "Action": [ \
                "s3:GetBucketLocation" \
            ], \
            "Resource": [ \
                "arn:aws:s3:::${BUCKET_NAME}" \
            ] \
        }, \
        { \
            "Effect": "Allow", \
            "Action": [ \
                "s3:GetObject" \
            ], \
            "Resource": [ \
                "arn:aws:s3:::${BUCKET_NAME}/synclite-*" \
            ] \
        }, \
        { \
            "Effect": "Allow", \
            "Action": [ \
                "s3:DeleteObject" \
            ], \
            "Resource": [ \
                "arn:aws:s3:::${BUCKET_NAME}/synclite-*" \
            ] \
        } \
    ] \
}' > /usr/bin/synclite_download_user_policy.json

RUN mkdir -p /root/.minio/certs

WORKDIR [/root/.minio/certs]

# Generate SSL certificate with SAN extension including localhost
RUN  if [ "${ENABLE_HTTPS}" = "true" ]; then \
    openssl req -newkey rsa:2048 -nodes -keyout /root/.minio/certs/private.key -x509 -days 365 -out /root/.minio/certs/cert.pem -subj "/C=IN/ST=MH/L=PN/O=SyncLite/CN=${HOST_IP_ADDRESS}" && \ 
    openssl req -new -key /root/.minio/certs/private.key -out /root/.minio/certs/cert.csr -subj "/C=IN/ST=MH/L=PN/O=SyncLite/CN=${HOST_IP_ADDRESS}" && \
    openssl x509 -req -days 365 -in /root/.minio/certs/cert.csr -signkey /root/.minio/certs/private.key -out /root/.minio/certs/public.crt; \
fi

WORKDIR /usr/bin

# Start MinIO server, wait for it to start, and configure it
RUN if [ "${ENABLE_HTTPS}" = "true" ]; then \
    	/usr/bin/minio server /data --certs-dir /root/.minio/certs/ --address :9000 --console-address :9090 & \
	sleep 10 && \
    	export MC_ENABLE_HTTPS=true && \
    	/usr/bin/mc --insecure config host add myminio https://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD && \
    	/usr/bin/mc --insecure mb myminio/${BUCKET_NAME} && \
    	/usr/bin/mc --insecure admin policy create myminio synclite_upload_user_policy /usr/bin/synclite_upload_user_policy.json && \
    	/usr/bin/mc --insecure admin user add myminio $UPLOAD_USER $UPLOAD_USER_PASSWORD && \
    	/usr/bin/mc --insecure admin policy attach myminio synclite_upload_user_policy --user $UPLOAD_USER && \
    	/usr/bin/mc --insecure admin policy create myminio synclite_download_user_policy /usr/bin/synclite_download_user_policy.json && \
    	/usr/bin/mc --insecure admin user add myminio $DOWNLOAD_USER $DOWNLOAD_USER_PASSWORD &&\
    	/usr/bin/mc --insecure admin policy attach myminio synclite_download_user_policy --user $DOWNLOAD_USER; \
fi
	
# Start MinIO server, wait for it to start, and configure it
RUN if [ "${ENABLE_HTTPS}" = "false" ]; then \
    	/usr/bin/minio server /data  --address :9000 --console-address :9090 & \
	sleep 10 && \
    	/usr/bin/mc config host add myminio http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD && \
    	/usr/bin/mc mb myminio/${BUCKET_NAME} && \
    	/usr/bin/mc admin policy create myminio synclite_upload_user_policy /usr/bin/synclite_upload_user_policy.json && \
    	/usr/bin/mc admin user add myminio $UPLOAD_USER $UPLOAD_USER_PASSWORD && \
    	/usr/bin/mc admin policy attach myminio synclite_upload_user_policy --user $UPLOAD_USER && \
    	/usr/bin/mc admin policy create myminio synclite_download_user_policy /usr/bin/synclite_download_user_policy.json && \
    	/usr/bin/mc admin user add myminio $DOWNLOAD_USER $DOWNLOAD_USER_PASSWORD &&\
    	/usr/bin/mc admin policy attach myminio synclite_download_user_policy --user $DOWNLOAD_USER; \
fi


RUN if [ "${ENABLE_HTTPS}" = "true" ]; then \
	echo "openssl req -newkey rsa:2048 -nodes -keyout /root/.minio/certs/private.key -x509 -days 365 -out /root/.minio/certs/cert.pem -subj '/C=IN/ST=MH/L=PN/O=SyncLite/CN=${HOST_IP_ADDRESS}'\n\
          openssl req -new -key /root/.minio/certs/private.key -out /root/.minio/certs/cert.csr -subj '/C=IN/ST=MH/L=PN/O=SyncLite/CN=${HOST_IP_ADDRESS}'\n\
          openssl x509 -req -days 365 -in /root/.minio/certs/cert.csr -signkey /root/.minio/certs/private.key -out /root/.minio/certs/public.crt\n\
          export MINIO_ROOT_USER=$MINIO_ROOT_USER\n\
          export MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD\n\
          /usr/bin/minio server /data --certs-dir /root/.minio/certs/ --address :9000 --console-address :9090 &\n\
	  sleep 10\n\
          export MC_ENABLE_HTTPS=true\n\
          /usr/bin/mc --insecure mb -p myminio/${BUCKET_NAME}\n\
          /usr/bin/mc --insecure admin policy create myminio synclite_upload_user_policy /usr/bin/synclite_upload_user_policy.json\n\
          /usr/bin/mc --insecure admin user add myminio $UPLOAD_USER $UPLOAD_USER_PASSWORD\n\
          /usr/bin/mc --insecure admin policy attach myminio synclite_upload_user_policy --user $UPLOAD_USER\n\
          /usr/bin/mc --insecure admin policy create myminio synclite_download_user_policy /usr/bin/synclite_download_user_policy.json\n\
          /usr/bin/mc --insecure admin user add myminio $DOWNLOAD_USER $DOWNLOAD_USER_PASSWORD\n\
          /usr/bin/mc --insecure admin policy attach myminio synclite_download_user_policy --user $DOWNLOAD_USER\n\
          exit 0" > /usr/bin/setup.sh && \
	  chmod +x /usr/bin/setup.sh; \
fi

RUN if [ "${ENABLE_HTTPS}" = "false" ]; then \
	 echo "export MINIO_ROOT_USER=$MINIO_ROOT_USER\n\
         export MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD\n\
         /usr/bin/minio server /data --address :9000 --console-address :9090 &\n\
	 sleep 10\n\
         /usr/bin/mc mb -p myminio/${BUCKET_NAME}\n\
         /usr/bin/mc admin policy create myminio synclite_upload_user_policy /usr/bin/synclite_upload_user_policy.json\n\
         /usr/bin/mc admin user add myminio $UPLOAD_USER $UPLOAD_USER_PASSWORD\n\
         /usr/bin/mc admin policy attach myminio synclite_upload_user_policy --user $UPLOAD_USER\n\
         /usr/bin/mc admin policy create myminio synclite_download_user_policy /usr/bin/synclite_download_user_policy.json\n\
         /usr/bin/mc admin user add myminio $DOWNLOAD_USER $DOWNLOAD_USER_PASSWORD\n\
         /usr/bin/mc admin policy attach myminio synclite_download_user_policy --user $DOWNLOAD_USER\n\
         exit 0" > /usr/bin/setup.sh && \
	 chmod +x /usr/bin/setup.sh; \
fi


# Expose the MinIO server port
EXPOSE 9000

