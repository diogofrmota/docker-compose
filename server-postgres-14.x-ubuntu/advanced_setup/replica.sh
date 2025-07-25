#!/bin/bash
# Configuration (Adjust the values on .env file)
# OS - Ubuntu
# Replica machine
# For this example i will use ssh OMITTED

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
sudo mv /tmp/pgdata.key.tmp "$KEY_FILE"                      # Move the key file from /tmp/ to Its final location
sudo mkdir -p /mnt/pgdata
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
sudo ufw allow from ${IP_PRIMARY} to any port 5432 proto tcp
sudo ufw allow from ${IP_PRIMARY} to any port 22 proto tcp
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
sudo chmod 0400 "$KEY_FILE"                                  # Key file read-only for the owner (root)
sudo cryptsetup luksFormat "$DISK" --key-file "$KEY_FILE"    # Encrypts disk using the key file
sudo cryptsetup luksOpen "$DISK" "$MAP_NAME" --key-file "$KEY_FILE" # Unlocks the encrypted volume for access, creates a mapped device (/dev/mapper/pgdata) that can be formatted and mounted
sudo mkfs.xfs "$MAPPED_DISK"                                 # Formats the unlocked LUKS volume (/dev/mapper/pgdata) with the XFS filesystem

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

# Create symlinks for Docker-Compose (Replica uses server-replica.crt & key)
ln -sf server.crt server-replica.crt
ln -sf server.key server-replica.key

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
