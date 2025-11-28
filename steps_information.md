# PostgreSQL Replication Setup Guide

## Step 1: Open Interactive Shell

Open an interactive shell inside the primary PostgreSQL container to execute commands directly.

```bash
docker exec -it pgPrimary bash
```

---

## Step 2: Create Replication User Role

Create a user named `replicator` with replication privileges. The `REPLICATION` privilege is required for streaming replication.

```sql
psql -U postgres -c "CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'rep_pass';"
```

---

## Understanding WAL (Write-Ahead Log)

### What is WAL?

> **WAL (Write-Ahead Log)** is PostgreSQL's transaction log - a sequential record of all changes made to the database. Think of it like a detailed diary that records every modification before it's actually applied to the data files.

### ❓ Is WAL Common with PostgreSQL Only?

> **Answer:** **NO!** Write-Ahead Logging (WAL) is **NOT** exclusive to PostgreSQL. It's actually a fundamental database technique used by most major database systems, though they may call it by different names.

#### Database Systems Using WAL/Similar Mechanisms:

| Database                 | WAL Name                 | Purpose                                       |
| ------------------------ | ------------------------ | --------------------------------------------- |
| **PostgreSQL**           | WAL (Write-Ahead Log)    | Stored in `pg_wal` directory                  |
| **Oracle Database**      | Redo Log                 | Crash recovery and Data Guard replication     |
| **MySQL (InnoDB)**       | Redo Log                 | ACID compliance and crash recovery            |
| **Microsoft SQL Server** | Transaction Log          | Recovery, replication, point-in-time recovery |
| **IBM DB2**              | Transaction/Recovery Log | Data integrity and recovery                   |
| **SQLite**               | WAL Mode                 | Better concurrency and performance            |
| **MongoDB**              | Oplog (Operations Log)   | Replication and recovery                      |

#### Why Most Databases Use WAL:

WAL is a fundamental database technique because it solves critical problems:

- ✅ **ACID Compliance** - Ensures Durability (the 'D' in ACID)
- ✅ **Crash Recovery** - Enables recovery without data loss
- ✅ **Replication** - Supports high availability setups
- ✅ **Performance** - Improves efficiency through sequential writes
- ✅ **Point-in-Time Recovery** - Restore to any specific moment

> **Note:** The concept is so important that it's part of the **ARIES** (Algorithms for Recovery and Isolation Exploiting Semantics) algorithm, which is a foundational database recovery algorithm used by many database systems.

#### Differences Between Systems:

While the core concept is the same, different databases implement WAL with variations:

- **Naming:** WAL, Redo Log, Transaction Log, Oplog, etc.
- **Storage format:** Binary, text-based, or proprietary formats
- **Configuration:** Different parameters and settings
- **Features:** Some support logical replication, others only physical replication

**Summary:** WAL is a universal database technique, not unique to PostgreSQL. PostgreSQL just uses the term "WAL" explicitly, while others use different names for essentially the same concept.

---

### Why Does WAL Exist?

WAL ensures data integrity and durability. It's based on a simple principle:

> **"Write the log first, then write the data."**

This guarantees that even if the system crashes, we can always recover by replaying the log entries.

---

### How WAL Works (Step by Step)

1. **Transaction Begins**

   - When you INSERT, UPDATE, or DELETE data, PostgreSQL doesn't immediately modify the actual data files on disk.

2. **Write to WAL First**

   - PostgreSQL first writes a record of the change to the WAL (Write-Ahead Log).
   - This log entry describes exactly what change is being made (e.g., "insert row X into table Y").

3. **Flush WAL to Disk**

   - The WAL entry is immediately flushed (written) to disk to ensure it's safely stored, even if the system crashes right after.

4. **Apply Changes**

   - Only after the WAL is safely written to disk does PostgreSQL apply the changes to the actual data files.
   - These data file writes might be deferred for performance optimization.

5. **Transaction Commits**
   - When you commit a transaction, PostgreSQL ensures the WAL entry is on disk before confirming the commit is complete.

### WAL Files and Storage

- WAL files are stored in the `pg_wal` directory (formerly `pg_xlog` in older versions)
- Each WAL file is typically **16MB** in size
- WAL files are written sequentially and in order
- Old WAL files are recycled or archived when no longer needed

---

### Checkpoints

Periodically, PostgreSQL creates **"checkpoints"** - snapshots of the database state at a specific point in time. Checkpoints help limit how much WAL needs to be replayed during recovery, making recovery faster.

---

### WAL and Replication

For replication to work, the replica server needs access to the WAL data from the primary server. The replica reads the WAL entries and applies them to its own data files, keeping it synchronized with the primary.

> **This is why we need to configure `wal_level`** - it determines how much information is included in the WAL, which affects what replication features are available.\*\*\*\*

---

## Step 3: Configure WAL Level for Replication

Set `wal_level` to `'replica'` to enable WAL archiving and streaming replication.

### WAL Level Options

| Level               | Description                                                   | Use Case               |
| ------------------- | ------------------------------------------------------------- | ---------------------- |
| `minimal` (default) | Only logs information needed for crash recovery               | No replication support |
| `replica`           | Enables WAL archiving and streaming replication               | Physical replicas      |
| `logical`           | Includes all replica-level info plus logical replication data | Logical replication    |

> **Setting `wal_level` to `'replica'`** is the minimum required for streaming replication. It enables the primary server to send WAL data to replica servers in real-time, allowing replicas to continuously receive and apply changes from the primary.

> ⚠️ **Note:** This setting typically requires a PostgreSQL restart to take full effect.

```sql
psql -U postgres -c "ALTER SYSTEM SET wal_level = 'replica';"
```

---

## Step 4: Set Maximum WAL Sender Processes

This limits how many replication connections can be made simultaneously. Set to 10 to allow multiple replicas or connections.

```sql
psql -U postgres -c "ALTER SYSTEM SET max_wal_senders = 10;"
```

---

## Step 5: Configure WAL Retention Size

This sets the minimum size of WAL files to keep for replication. 64MB ensures enough WAL data is retained for replicas to catch up.

```sql
psql -U postgres -c "ALTER SYSTEM SET wal_keep_size = '64MB';"
```

---

## Step 6: Configure PostgreSQL to Listen on All Network Interfaces

Set `listen_addresses` to `'*'` to allow connections from any IP address. This is necessary for the replica container to connect to the primary.

```sql
psql -U postgres -c "ALTER SYSTEM SET listen_addresses = '*';"
```

---

## Step 7: Reload PostgreSQL Configuration

This applies the configuration changes without requiring a full restart.

> ⚠️ **Note:** Some settings may still require a restart to take effect.

```sql
psql -U postgres -c "SELECT pg_reload_conf();"
```

---

## Step 8: Configure pg_hba.conf for Replication Connections

This adds a rule to the host-based authentication file to allow the replicator user to connect from any IP (`0.0.0.0/0`) for replication purposes using MD5 password authentication.

### What is `pg_hba.conf`?

**`pg_hba.conf`** (PostgreSQL Host-Based Authentication configuration file) is PostgreSQL's **firewall and authentication rulebook**. It controls:

- ✅ **WHO** can connect (which users/roles)
- ✅ **WHERE** they can connect from (which IP addresses/hosts)
- ✅ **HOW** they authenticate (password, certificate, trust, etc.)
- ✅ **WHAT** they can connect to (which databases, replication)

### Why Do We Need This Step?

Even though we created the `replicator` user in Step 2, **PostgreSQL still needs explicit permission** in `pg_hba.conf` to allow that user to connect from a remote host (the replica container).

**Without this step:**

- The `replicator` user exists ✅
- The user has `REPLICATION` privilege ✅
- But PostgreSQL will **reject the connection** ❌ because `pg_hba.conf` doesn't have a rule allowing it

**With this step:**

- PostgreSQL checks `pg_hba.conf`
- Finds a matching rule: `host replication replicator 0.0.0.0/0 md5`
- Allows the connection from the replica container ✅

### Understanding the Rule Format

The line we're adding:

```bash
host replication replicator 0.0.0.0/0 md5
```

Breaks down as:

| Part          | Meaning               | Explanation                                                           |
| ------------- | --------------------- | --------------------------------------------------------------------- |
| `host`        | Connection type       | TCP/IP connection (not local socket)                                  |
| `replication` | Database name         | Special keyword for replication connections (not a regular database)  |
| `replicator`  | Username              | The user role we created in Step 2                                    |
| `0.0.0.0/0`   | IP address range      | `0.0.0.0/0` means "any IP address" (allows connections from anywhere) |
| `md5`         | Authentication method | Password authentication using MD5 hashing                             |

### Alternative IP Restrictions

If you want to restrict to specific IPs instead of `0.0.0.0/0`:

```bash
# Allow only from a specific IP
echo "host replication replicator 172.18.0.3/32 md5" >> /var/lib/postgresql/data/pg_hba.conf

# Allow from a subnet (e.g., Docker network)
echo "host replication replicator 172.18.0.0/16 md5" >> /var/lib/postgresql/data/pg_hba.conf
```

> **Note:** In Docker, using `0.0.0.0/0` is safe because:
>
> - Docker networks are isolated
> - Only containers on the same network can reach each other
> - Additional security is provided by the password authentication (`md5`)

### How PostgreSQL Uses `pg_hba.conf`

When a connection attempt is made:

1. **PostgreSQL receives connection request** from replica container
2. **Checks `pg_hba.conf`** from top to bottom (first match wins)
3. **Matches the rule:** `host replication replicator 0.0.0.0/0 md5`
4. **Requires MD5 password authentication**
5. **If password is correct:** Connection allowed ✅
6. **If no matching rule found:** Connection rejected ❌

```bash
echo "host replication replicator 0.0.0.0/0 md5" >> /var/lib/postgresql/data/pg_hba.conf
```

---

## Step 9: Reload Configuration Again

This makes the new authentication rule active without restarting PostgreSQL.

```sql
psql -U postgres -c "SELECT pg_reload_conf();"
```

---

## Step 10: Exit Container Shell

Exit the container shell and return to the host system.

```bash
exit
```

---

---

---

---

## Step 11: Start the Replica Container

Start the replica container:

```bash
docker compose up -d pg-replica
```

Watch logs:

```bash
docker logs -f pg-replica
```

You should see:

`pg_basebackup` starting with progress bars, then PostgreSQL startup.

Then lines showing PostgreSQL startup

If you see “waiting for primary...”, wait — basebackup will start after primary ready.

If `pg_basebackup` fails due to non-empty directory:

```bash
docker compose down
rd /s /q replica_data  # Windows
docker compose up -d pg-replica
```

---

## Step 12: Verify Replication

On primary, check replication clients:

```bash
docker exec -it pgPrimary psql -U postgres -c "SELECT pid, usename, application_name, client_addr, state, sync_state FROM pg_stat_replication;"
```

Expected: one row for `pg-replica` with `state = streaming`.

On replica, check recovery mode:

```bash
docker exec -it pg-replica psql -U postgres -c "SELECT pg_is_in_recovery();"
```

Expected: `pg_is_in_recovery => t` (replica is read-only).

---

## Step 13: Test Replication

Create test database and table on primary:

```bash
docker exec -it pgPrimary psql -U postgres -c "CREATE DATABASE repl_test;"
docker exec -it pgPrimary psql -U postgres -d repl_test -c "CREATE TABLE items (id serial PRIMARY KEY, txt text);"
docker exec -it pgPrimary psql -U postgres -d repl_test -c "INSERT INTO items (txt) VALUES ('hello'), ('replication'), ('windows demo');"
```

Query replica to verify:

```bash
docker exec -it pg-replica psql -U postgres -d repl_test -c "SELECT * FROM items;"
```

Expected: three inserted rows. If empty, wait 1-2 seconds and re-run.

---

## Step 14: Check Replication Lag

On primary:

```bash
docker exec -it pgPrimary psql -U postgres -c "SELECT application_name, client_addr, state, sync_state, sent_lsn, write_lsn, flush_lsn, replay_lsn FROM pg_stat_replication;"
```

On replica:

```bash
docker exec -it pg-replica psql -U postgres -c "SELECT pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn(), pg_last_xact_replay_timestamp();"
```

To calculate replication lag as a time interval:

```bash
docker exec -it pg-replica psql -U postgres -c "SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;"
```

Difference between `sent_lsn` (primary) and `replay_lsn` (replica) indicates lag. `sync_state` shows async or sync mode. The replication lag query shows how far behind the replica is in time.

---

## Step 15: Optional - Synchronous Replication

Enable synchronous replication:

**Bash/Linux:**

```bash
docker exec -it pgPrimary psql -U postgres -c "ALTER SYSTEM SET synchronous_standby_names = '\"pgReplica\"';"
docker exec -it pgPrimary psql -U postgres -c "SELECT pg_reload_conf();"
```

**PowerShell (Windows):**

```powershell
docker exec -it pgPrimary psql -U postgres -c 'ALTER SYSTEM SET synchronous_standby_names = ''"pgReplica"'';'
docker exec -it pgPrimary psql -U postgres -c "SELECT pg_reload_conf();"
```

> **Note:** In PowerShell, use single quotes for the outer string and double the single quotes (`''`) inside for PostgreSQL string delimiters.

Test: Insert on primary will wait for replica acknowledgment.

```bash
# Test synchronous replication with an INSERT
docker exec -it pgPrimary psql -U postgres -c "CREATE TABLE IF NOT EXISTS test_sync (id SERIAL PRIMARY KEY, data TEXT);"
docker exec -it pgPrimary psql -U postgres -c "INSERT INTO test_sync (data) **VALUES** ('synchronous test');"
```

Stop replica to see blocking:

```bash
docker stop pg-replica
```

Primary commits will block. Restore replica to resume.

Revert to async:

```bash
docker exec -it pgPrimary psql -U postgres -c "ALTER SYSTEM SET synchronous_standby_names = '';"
docker exec -it pgPrimary psql -U postgres -c "SELECT pg_reload_conf();"
docker start pg-replica
```

> **Warning:** Synchronous mode can block primary if standby is unreachable.
