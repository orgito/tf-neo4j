#!/bin/bash

# Exit if already executed
if [ -f ~/.terraform_provisioned ]; then exit; fi

NEO4J_ACCEPT_LICENSE_AGREEMENT=yes yum -q -y install neo4j-enterprise-${version}

neo4j-admin set-initial-password ${initial_password}

echo neo4j soft nofile 65000 >> /etc/security/limits.conf
echo neo4j hard nofile 65000 >> /etc/security/limits.conf

PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

cat > /etc/neo4j/neo4j.conf << EOF
dbms.directories.data=/var/lib/neo4j/data
dbms.directories.plugins=/var/lib/neo4j/plugins
dbms.directories.certificates=/var/lib/neo4j/certificates
dbms.directories.logs=/var/log/neo4j
dbms.directories.lib=/usr/share/neo4j/lib
dbms.directories.run=/var/run/neo4j
dbms.directories.metrics=/var/lib/neo4j/metrics
dbms.directories.import=/var/lib/neo4j/import

dbms.connector.bolt.enabled=true
dbms.connector.http.enabled=true
dbms.connector.https.enabled=true

dbms.jvm.additional=-XX:+UseG1GC
dbms.jvm.additional=-XX:-OmitStackTraceInFastThrow
dbms.jvm.additional=-XX:+AlwaysPreTouch
dbms.jvm.additional=-XX:+UnlockExperimentalVMOptions
dbms.jvm.additional=-XX:+TrustFinalNonStaticFields
dbms.jvm.additional=-XX:+DisableExplicitGC
dbms.jvm.additional=-Djdk.tls.ephemeralDHKeySize=2048
dbms.jvm.additional=-Djdk.tls.rejectClientInitiatedRenegotiation=true
dbms.jvm.additional=-Dunsupported.dbms.udc.source=rpm

dbms.windows_service_name=neo4j

dbms.connectors.default_listen_address=0.0.0.0
dbms.connectors.default_advertised_address=$PRIVATE_IP
dbms.mode=${mode}

causal_clustering.discovery_type=DNS
causal_clustering.minimum_core_cluster_size_at_formation=3
causal_clustering.minimum_core_cluster_size_at_runtime=3
causal_clustering.initial_discovery_members=${members}:5000
causal_clustering.cluster_allow_reads_on_followers=true
EOF

# Add memory recommendations
neo4j-admin memrec 2>/dev/null | grep -v ^# >> /etc/neo4j/neo4j.conf

# Wait for the cluster A record to be available
until host ${members}; do
    sleep 1
done

# Prepare and mount /srv
/usr/local/bin/preparesrv.sh

# Move Neo4j to the ebs volume
mkdir /srv/lib
mkdir /srv/log
mv /var/lib/neo4j /srv/lib
mv /var/log/neo4j /srv/log
ln -s /srv/lib/neo4j /var/lib/neo4j
ln -s /srv/log/neo4j /var/log/neo4j

systemctl enable neo4j
systemctl start neo4j

echo "Node Provisioned" > ~/.terraform_provisioned
chattr +i ~/.terraform_provisioned
