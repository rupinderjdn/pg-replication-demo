# Step 1: Open an interactive shell inside the primary PostgreSQL container

# This allows us to execute commands directly in the container

docker exec -it pg-primary bash

# Step 2: Create a replication user role

# This creates a user named 'replicator' with replication privileges and sets the password

# The REPLICATION privilege is required for streaming replication

psql -U postgres -c "CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'rep_pass';"

# Step 3: Configure Write-Ahead Log (WAL) level for replication

# Set wal_level to 'replica' to enable WAL archiving and streaming replication

#

# WAL (Write-Ahead Log) level determines how much information is written to the WAL files.

# Available levels:

# - 'minimal' (default): Only logs information needed for crash recovery, no replication support

# - 'replica': Enables WAL archiving and streaming replication for physical replicas

# - 'logical': Includes all replica-level info plus data needed for logical replication

#

# Setting wal_level to 'replica' is the minimum required for streaming replication.

# It enables the primary server to send WAL data to replica servers in real-time,

# allowing replicas to continuously receive and apply changes from the primary.

# This setting typically requires a PostgreSQL restart to take full effect.

psql -U postgres -c "ALTER SYSTEM SET wal_level = 'replica';"

# Step 4: Set maximum number of WAL sender processes

# This limits how many replication connections can be made simultaneously

# Set to 10 to allow multiple replicas or connections

psql -U postgres -c "ALTER SYSTEM SET max_wal_senders = 10;"

# Step 5: Configure WAL retention size

# This sets the minimum size of WAL files to keep for replication

# 64MB ensures enough WAL data is retained for replicas to catch up

psql -U postgres -c "ALTER SYSTEM SET wal_keep_size = '64MB';"

# Step 6: Configure PostgreSQL to listen on all network interfaces

# Set listen_addresses to '\*' to allow connections from any IP address

# This is necessary for the replica container to connect to the primary

psql -U postgres -c "ALTER SYSTEM SET listen_addresses = '\*';"

# Step 7: Reload PostgreSQL configuration

# This applies the configuration changes without requiring a full restart

# Note: Some settings may still require a restart to take effect

psql -U postgres -c "SELECT pg_reload_conf();"

# Step 8: Configure pg_hba.conf to allow replication connections

# This adds a rule to the host-based authentication file to allow the replicator user

# to connect from any IP (0.0.0.0/0) for replication purposes using MD5 password authentication

echo "host replication replicator 0.0.0.0/0 md5" >> /var/lib/postgresql/data/pg_hba.conf

# Step 9: Reload configuration again to apply pg_hba.conf changes

# This makes the new authentication rule active without restarting PostgreSQL

psql -U postgres -c "SELECT pg_reload_conf();"

# Step 10: Exit the container shell and return to the host system

exit
