#!/bin/bash

# 1. Load environment variables
source "$ENV_FILE"
HOSTNAME=$(hostname)

# Only the primary should generate and renew certificates
if [[ "$HOSTNAME" == "$PRIMARY_HOST" ]]; then
    cd "$SSL_PATH"

    # Extract SSL certificate expiration date
    EXPIRY_DATE=$(openssl x509 -in server.crt -enddate -noout | cut -d= -f2) # Extracts the exact expiration date of the SSL certificate
    EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)                               # Stores the timestamp in $EXPIRY_EPOCH
    CURRENT_EPOCH=$(date +%s)                                                # Allows comparison with the certificate expiration timestamp
    DAYS_REMAINING=$(( ($EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))           # Determines how many days are left before the certificate expires

    if [ $DAYS_REMAINING -lt $CERT_RENEWAL_THRESHOLD ]; then
        echo "SSL certificate renewal required. Remaining days: $DAYS_REMAINING"
        
        # Generate new SSL certificates
        openssl req -new -nodes -out server.csr -keyout server.key \
            -subj "/CN=postgres-cluster" \
            -config <(printf "[req]\ndistinguished_name=dn\nreq_extensions=ext\n[dn]\nCN=postgres-cluster\n[ext]\nsubjectAltName=DNS:$PRIMARY_HOST,DNS:$REPLICA_HOST")

        openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days $CERT_VALIDITY_DAYS -extfile <(printf "subjectAltName=DNS:$PRIMARY_HOST,DNS:$REPLICA_HOST")

        echo "SSL certificates renewed."

        # Copy the new certificates to the replica
        scp server.crt server.key $USER@$REPLICA_HOST:${INSTALL_PATH}/postgres-cluster/ssl/

        echo "SSL certificates copied to the replica."

        # Renew client certificate
        openssl req -new -nodes -out client.csr -keyout client.key \
            -subj "/CN=postgres-client/O=${ORGANIZATION}/C=IT"
        
        openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key \
            -out client.crt -days 365

        # Distribute to clients/nodes
        scp client.crt client.key $USER@$REPLICA_HOST:$SSL_PATH/
    else
        echo "SSL certificates are still valid for $DAYS_REMAINING days. No renewal needed."
    fi
fi

# On the replica, ensure certificates are updated when received
if [[ "$HOSTNAME" == "$REPLICA_HOST" ]]; then
    cd "$SSL_PATH"
    if [ -f "server.crt" ]; then
        ln -sf server.crt server-replica.crt
        ln -sf server.key server-replica.key
        echo "SSL certificate symlinks updated on the replica."
    fi
fi
