# PostgreSQL Deployment (Primary + Replica)

## Overview

This guide outlines the step-by-step process for deploying a PostgreSQL cluster using Docker Compose, Bitnami PostgreSQL-repmgr, and LUKS encryption for data security.

## Security Features

- **Encryption at Rest**:  
  - LUKS with a dedicated keyfile (`/etc/luks-keys/pgdata.key`) generated in the setup.sh.  
  - Auto-mounted via `/etc/crypttab` (encrypted block that need to be automatically unlocked during boot) and `/etc/fstab` (once the encrypted volume is unlocked, `/etc/fstab` provides the instructions for automatically mounting file systems).
- **Encryption in Transit**:  
  - SSL/TLS for client connections and replication.  
  - Mutual TLS support using a Certificate Authority (CA).  
- **Credentials**:  
  - Secured via `.env` file with restricted permissions (`chmod 600`).  

## Project Structure

```plaintext
📁 /home/user/postgres-cluster/
│── 📄 README.md
│── 📄 docker-compose-primary.yml   # Primary node configuration
│── 📄 docker-compose-replica.yml   # Replica node configuration
│── 📄 .env                         # Environment variables (credentials)
│── 📄 primary.sh                   # Script to configurate primary machine
│── 📄 replica.sh                   # Script to configurate replica machine
│── 📁 ssl/
│   ├── 📄 ca.crt                   # Certificate Authority
│   ├── 📄 server-primary.crt       # Primary node certificate
│   ├── 📄 server-primary.key       # Primary node private key
│   ├── 📄 server-replica.crt       # Replica node certificate
│   └── 📄 server-replica.key       # Replica node private key
```

## Deployment Steps

1. **Create the data folder for the Postgres cluster**

On both machines:
```bash
USER="diogo" 
sudo mkdir -p /home/$USER/postgres-cluster/
```

2. **Add the cluster configuration files**

On primary machine:
```bash
sudo vim /home/$USER/postgres-cluster/docker-compose-primary.yml
sudo vim /home/$USER/postgres-cluster/.env
source /home/$USER/postgres-cluster/.env
sudo vim /home/$USER/postgres-cluster/primary.sh
sudo mkdir -p /mnt/pgdata/backups
sudo chown 1001:1001 /mnt/pgdata/backups
sudo chmod 755 /mnt/pgdata/backups
```

On replica machine:
```bash
sudo vim /home/$USER/postgres-cluster/docker-compose-replica.yml
sudo vim /home/$USER/postgres-cluster/.env
source /home/$USER/postgres-cluster/.env
sudo vim /home/$USER/postgres-cluster/replica.sh
```

3. **.env file needs to be adapted with the correct environment variables for the systems where the postgres will be installed**

4. **Before running the script you need to have attached a secundary disk that will be encrypted on both machines**

On primary machine:
Run the commands in primary.sh

Now run the following commands on the primary machine:
```bash
sudo scp "$KEY_FILE" $USER@$REPLICA_HOST:/tmp/pgdata.key.tmp                            # Copy the key file to the Replica host
scp ca.crt server.crt server.key client.crt client.key $USER@$POSTGRES_HOST_BACKUP:${INSTALL_PATH}/postgres-cluster/ssl/
```
On replica machine:
Run the commands in replica.sh

5. **After running the script run this commands**

On primary machine:
```bash
sudo docker compose -f ${INSTALL_PATH}/postgres-cluster/docker-compose-primary.yml up -d # Ensures the primary PostgreSQL container starts only on the primary machine
```

On replica machine:
```bash
sudo docker compose -f ${INSTALL_PATH}/postgres-cluster/docker-compose-replica.yml up -d # Ensures the replica PostgreSQL container starts only on the replica machine
```

6. **Verify installation**

On primary machine:
```bash
sudo docker exec -it postgresql-primary repmgr cluster show
sudo docker exec -it postgresql-primary psql -U postgres -c "SHOW ssl;"
sudo docker exec -it postgresql-primary psql -U $USER -d postgresDB -c "SELECT * FROM pg_stat_replication;"
sudo docker exec -it postgresql-primary psql -U postgres -c "SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;"
```

On replica machine:
```bash
sudo docker exec -it postgresql-replica repmgr cluster show
sudo docker exec -it postgresql-replica psql -U $USER -d postgresDB -c "SELECT * FROM pg_stat_wal_receiver;
gunzip -t /mnt/pgdata/backups/db_backup_*.sql.gz
```