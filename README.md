# Docker Compose for MongoDB & Postgres Replica Sets

Collection of Docker Compose files for deploying **MongoDB** and **Postgres** replica sets locally and across multiple servers.

## Structure

### MongoDB
- **Local Deployment**  
  `mongodb-cluster/local-mongo-6.x/`  
  `docker-compose-mongo[1-3].yml` | `initReplicaSet.js`  

- **Multi-Server Deployment**  
  `server-mongo-4.x/` | `server-mongo-6.x/`  
  `docker-compose-mongo[1-3].yml` | `initReplicaSet.js`  

### Postgres
- **Advanced Setup**  
  `server-postgres-14.x-ubuntu/advanced_setup/`  
  `docker-compose-primary.yml` | `docker-compose-replica.yml`  
  `primary.sh` | `replica.sh`  

- **Simple Setup**  
  `server-postgres-14.x-ubuntu/simple_setup/`  
  `docker-compose-primary.yml` | `docker-compose-replica.yml`  
  `primary.sh` | `replica.sh`  

## Usage
1. Navigate to the desired folder (e.g., `mongodb-cluster/local-mongo-6.x`).  
2. Run:  
   ```bash
   docker-compose -f docker-compose-mongo1.yml up -d