# MongoDB Replica Set Deployment Guide

## 1. Prerequisites

Ensure the following prerequisites are met on all three servers:

### 1.1 Install Docker and Docker Compose
On Mongo 1, Mongo 2 and Mongo 3:
```sh
sudo apt update && sudo apt upgrade && sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 1.2 Create the `/data` Directory
On Mongo 1, Mongo 2 and Mongo 3:
```sh
sudo mkdir -p /data/
```

## 2. Set Up Keyfile and .env file on each Server

### 2.1 Generate the Keyfile
```sh
openssl rand -base64 756 > /data/keyfile.key
sudo chmod 400 /data/keyfile.key
sudo chown 999:999 /data/keyfile.key
```

### 2.2 Create the Keyfile in Mongo 2 and Mongo 3
On Mongo 1:
```sh
scp /data/keyfile.key OMITTED:/data/keyfile.key
scp /data/keyfile.key OMITTED:/data/keyfile.key
```

### 2.3 Set Permissions on Mongo 2 and Mongo 3
On Mongo 2 and Mongo 3:
```sh
sudo chmod 400 /data/keyfile.key
sudo chown 999:999 /data/keyfile.key
```

### 2.4 Create the .env File
On Mongo 1, Mongo 2 and Mongo 3:
```sh
sudo echo 'MONGO_INITDB_ROOT_USERNAME=OMITTED
MONGO_INITDB_ROOT_PASSWORD=OMITTED
R4C_USERNAME=OMITTED
R4C_PASSWORD=OMITTED
R4CDOC_USERNAME=OMITTED
R4CDOC_PASSWORD=OMITTED
TAGSTORE_USERNAME=OMITTED
TAGSTORE_PASSWORD=OMITTED' > /data/.env
```
Export variables:
```sh
export $(grep -v '^#' /data/.env | xargs)
```

### 2.5 Create the file initReplicaSet.js
Before setting up Mongo 1, create the initialization script initReplicaSet.js on Mongo 1.
Create `initReplicaSet.js` and place it in /data/.
```sh
sudo vim /data/initReplicaSet.js
```

## 3. Start the databases

### 3.1 Create the Docker Compose File
Create `docker-compose-mongo1.yml` on Mongo 1.
Create `docker-compose-mongo2.yml` on Mongo 2.
Create `docker-compose-mongo3.yml` on Mongo 3.

### 3.2 Start Primary Mongo database:
On Mongo 1:
```sh
docker compose -f docker-compose-mongo1.yml up -d
```
Check logs:
```sh
docker logs mongo-1-container
```

### 3.3 Start Secundary Mongo database:
On Mongo 2:
```sh
docker compose -f docker-compose-mongo2.yml up -d
```
On Mongo 3:
```sh
docker compose -f docker-compose-mongo3.yml up -d
```

## 4. Create the Replica Set and databases necessary for R4C

### 4.1 Check if credentials were exported

Check if the variables were exported:
```sh
docker exec -it mongo-1-container printenv | grep MONGO_INITDB_ROOT_USERNAME
```

### 4.2 Run The Script initReplicaSet.js
On Mongo 1:
```sh
docker exec -it mongo-1-container mongo -u ${MONGO_INITDB_ROOT_USERNAME} -p ${MONGO_INITDB_ROOT_PASSWORD} --file /data/initReplicaSet.js
```

### 4.3 Verify New Databases
On Mongo 1:
```sh
docker exec -it mongo-1-container mongo -u ${MONGO_INITDB_ROOT_USERNAME} -p ${MONGO_INITDB_ROOT_PASSWORD} --eval "show dbs"
```

## 5. Verify the Replica Set

### 5.1 Check Replica Set Status
On Mongo 1:
```sh
docker exec -it mongo-1-container mongo -u ${MONGO_INITDB_ROOT_USERNAME} -p ${MONGO_INITDB_ROOT_PASSWORD}
```
Inside MongoDB shell:
```sh
rs.status()
```
All three members should be listed.

## 6. Additional Notes

### Firewall Configuration
Ensure port `27017` is open on all servers. Test connectivity:
```sh
telnet OMITTED 27017  # From Mongo 2 and Mongo 3
telnet OMITTED 27017  # From Mongo 1 and Mongo 2
```

### MongoDB Networking
With `network_mode: host` enabled, MongoDB is accessible at:
- **Mongo 1:** OMITTED:27017
- **Mongo 2:** OMITTED:27017
- **Mongo 3:** OMITTED:27017
No need to define ports in `docker-compose`.