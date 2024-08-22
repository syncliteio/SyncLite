# Use a base image with OpenSSH server
FROM ubuntu

ARG UPLOAD_USER=synclite
ARG UPLOAD_USER_PASSWORD=synclite
ARG STAGE_DIR_NAME=stageDir

# Update and install required packages
RUN apt-get update && \
    apt-get install -y vim && \
    apt-get install -y openssh-server

# Create a group and user for SFTP
RUN groupadd sftp_users && \
    useradd -m -d /home/$UPLOAD_USER -s /usr/sbin/nologin -g sftp_users $UPLOAD_USER

# Set the password for the SFTP user (CHANGE THIS PASSWORD)
RUN echo "$UPLOAD_USER:$UPLOAD_USER_PASSWORD" | chpasswd


# Create the chroot jail directories and set appropriate permissions
RUN mkdir -p /var/uploads/${STAGE_DIR_NAME} && \
    chown root:root /var/uploads  && \
    chmod 755 /var/uploads && \
    chown $UPLOAD_USER:sftp_users /var/uploads/${STAGE_DIR_NAME} && \
    chmod o+w /var/uploads/${STAGE_DIR_NAME} && \ 
    chmod o-r /var/uploads/${STAGE_DIR_NAME}
       

# Create the privilege separation directory for SSH
RUN mkdir -p /run/sshd

# Configure OpenSSH for SFTP and chroot jail with password authentication
RUN sed -i 's/#Subsystem/Subsystem/' /etc/ssh/sshd_config && \
    echo "Match User $UPLOAD_USER" >> /etc/ssh/sshd_config && \
    echo 'ForceCommand internal-sftp' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'ChrootDirectory /var/uploads' >> /etc/ssh/sshd_config && \
    echo 'PermitTunnel no' >> /etc/ssh/sshd_config && \
    echo 'AllowAgentForwarding no' >> /etc/ssh/sshd_config && \
    echo 'AllowTcpForwarding no' >> /etc/ssh/sshd_config && \
    echo 'X11Forwarding no' >> /etc/ssh/sshd_config && \
    echo 'DenyUsers root'


# Expose SSH port
EXPOSE 22

# Start SSH server
CMD ["/usr/sbin/sshd", "-D"]

