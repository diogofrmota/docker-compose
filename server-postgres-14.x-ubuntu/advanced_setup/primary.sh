#!/bin/bash
# Configuration (Adjust the values on .env file)
# OS - Ubuntu
# Primary machine
# For this example i will use ssh diogo@192.168.56.102

# ============================================================
# Step 1. Create necessary directories
# ============================================================

set -e
source /home/$USER/postgres-cluster/.env
echo "Creating directories..."
sudo chmod 600 /home/${USER}/postgres-cluster/.env
sudo chown ${USER}:${USER} /home/diogo/postgres-cluster/.env
sudo mkdir /home/${USER}/postgres-cluster/ssl                # Create certificates directory
sudo mkdir -p /etc/luks-keys                                 # Create key storage directory
sudo mkdir -p /mnt/pgdata
sudo chown 1001:1001 /mnt/pgdata
sudo mkdir -p ${INSTALL_PATH}/postgres-cluster/ssl           # Organizes SSL certificates in a dedicated location
sudo chown -R ${USER}:${USER} ${INSTALL_PATH}/postgres-cluster/ssl
sudo vim /home/${USER}/postgres-cluster/postgresql.conf
sudo chmod 644 /home/${USER}/postgres-cluster/postgresql.conf
sudo chown 1001:1001 /home/${USER}/postgres-cluster/postgresql.conf

# ============================================================
# Step 2. Install necessary plugins and Docker
# ============================================================

echo "Installing prerequisites..."
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin cryptsetup xfsprogs
sudo apt-get install --reinstall docker-ce docker-ce-cli containerd.io
sudo systemctl enable docker
sudo systemctl start docker

# ============================================================
# Step 3. Configure firewall (adjust IP if needed)
# ============================================================
echo "Configuring firewall..."
sudo ufw allow from ${IP_REPLICA} to any port 5432 proto tcp
sudo ufw allow from ${IP_REPLICA} to any port 22 proto tcp
sudo ufw reload

# ============================================================
# Step 4. Disk and Partitioning Operations
# ============================================================
echo "Verifying disk paths..."
lsblk

echo "Creating partition table and partition on $BASE_DISK..."
sudo parted $BASE_DISK mklabel msdos --script                # Create a partition table with MBR-style
sudo parted $BASE_DISK -s "mkpart primary 2048s 100%"        # Create a primary table - Defines a primary partition (/dev/sdb1) that spans nearly the entire disk, leaving space for the boot sector
sudo partprobe $BASE_DISK
echo "Updated disk layout:"
lsblk

# ============================================================
# Step 5. Set up LUKS encryption and filesystem
# ============================================================
echo "Setting up LUKS encryption..."
sudo dd if=/dev/urandom of="$KEY_FILE" bs=32 count=1         # Generate a LUKS key file (Primary Host)

echo "Encrypting disk $DISK with LUKS..."
sudo chmod 0400 "$KEY_FILE"                                  # Read-only for the owner
sudo cryptsetup luksFormat "$DISK" --key-file "$KEY_FILE"    # Encrypts disk using the key file
sudo cryptsetup luksOpen "$DISK" "$MAP_NAME" --key-file "$KEY_FILE" # Unlocks the encrypted volume for access, creates a mapped device (/dev/mapper/pgdata) that can be formatted and mounted
sudo mkfs.xfs "$MAPPED_DISK"                                 # Formats the unlocked LUKS volume (/dev/mapper/pgdata) with the XFS filesystem

echo "Mounting encrypted volume..."
sudo mkdir -p "$MOUNT_POINT"                                 # Ensures the mount point directory exists
sudo mount "$MAPPED_DISK" "$MOUNT_POINT"                     # Makes the encrypted disk accessible for PostgreSQL storage
sudo chown -R 1001:1001 "$MOUNT_POINT"                       # Gives PostgreSQL permissions to write to the mounted volume
echo "$MAP_NAME $DISK $KEY_FILE luks" | sudo tee -a /etc/crypttab          # Ensures the LUKS volume is unlocked automatically during system boot
echo "$MAPPED_DISK $MOUNT_POINT xfs defaults 0 0" | sudo tee -a /etc/fstab # Ensures the disk mounts automatically after reboot
sudo systemctl daemon-reload                                 # Ensures auto-mounting changes are applied without requiring a reboot.
sudo mount -a                                                # Immediately applies the new mount settings

# ============================================================
# Step 6. Generate SSL Certificates
# ============================================================
echo "Generating SSL Certificates..."
cd ${INSTALL_PATH}/postgres-cluster/ssl

# Generate a Certificate Authority (CA) - Issue the SSL certificate
sudo chown -R diogo:diogo ${INSTALL_PATH}/postgres-cluster/ssl
openssl req -new -x509 -days $CERT_VALIDITY_DAYS -nodes -out ca.crt -keyout ca.key -subj "/CN=PostgreSQL-CA/O=$ORGANIZATION/C=IT"

# Generate the Server Certificate Signing Request (CSR) - Ensures SSL works for both primary & replica PostgreSQL instances
openssl req -new -nodes -out server.csr -keyout server.key -subj "/CN=postgres-cluster" -config <(printf "[req]\ndistinguished_name=dn\nreq_extensions=ext\n[dn]\nCN=postgres-cluster\n[ext]\nsubjectAltName=DNS:$DNS_PRIMARY,DNS:$DNS_REPLICA")

# Generate the Signed Server Certificate - Enables secure SSL communication between PostgreSQL nodes
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days $CERT_VALIDITY_DAYS -extfile <(printf "subjectAltName=DNS:$DNS_PRIMARY,DNS:$DNS_REPLICA")
        
# Generate client certificate
openssl req -new -nodes -out client.csr -keyout client.key -subj "/CN=postgres-client/O=${ORGANIZATION}/C=IT"
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365

# Create symlinks for docker-compose - Ensures Docker-Compose references consistent filenames
ln -sf server.crt server-primary.crt
ln -sf server.key server-primary.key

# Permissions
sudo chmod 0600 ${INSTALL_PATH}/postgres-cluster/ssl/*.key # Ensures only the owner (root) can read/write SSL private keys, preventing unauthorized access
sudo chmod 0644 ${INSTALL_PATH}/postgres-cluster/ssl/*.crt # Allows PostgreSQL and other services to read the SSL certificates while keeping them secure

sudo mkdir ${INSTALL_PATH}/postgres-cluster/conf.d
sudo vim ${INSTALL_PATH}/postgres-cluster/conf.d/ssl.conf
# ssl = on
# ssl_cert_file = '/opt/bitnami/postgresql/certs/server-primary.crt'
# ssl_key_file = '/opt/bitnami/postgresql/certs/server-primary.key'
# ssl_ca_file = '/opt/bitnami/postgresql/certs/ca.crt'
sudo chown 1001:1001 ${INSTALL_PATH}/postgres-cluster/conf.d/ssl.conf
sudo chmod 644 ${INSTALL_PATH}/postgres-cluster/conf.d/ssl.conf
sudo chown -R 1001:1001 ${INSTALL_PATH}/postgres-cluster/conf.d
sudo chmod -R 755 ${INSTALL_PATH}/postgres-cluster/conf.d


echo "Configurations completed..."