# PostgreSQL Replication Demo

A hands-on demonstration of PostgreSQL streaming replication using Docker Compose. This repository provides a complete setup for understanding and testing PostgreSQL's physical replication capabilities.

## 📋 Overview

This demo sets up a **primary-replica** PostgreSQL replication environment where:

- **Primary server** accepts read/write operations
- **Replica server** automatically syncs data from the primary in real-time
- Changes on the primary are streamed to the replica via WAL (Write-Ahead Log)

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Network                            │
│                                                              │
│  ┌──────────────────┐         ┌──────────────────┐         │
│  │  pgPrimary       │         │  pgReplica       │         │
│  │  (Primary)       │────────▶│  (Standby)       │         │
│  │                  │  WAL    │                  │         │
│  │  Port: 5432      │ Stream  │  Port: 5433      │         │
│  │  Read/Write      │         │  Read-Only       │         │
│  └──────────────────┘         └──────────────────┘         │
│         │                              │                    │
│         │                              │                    │
│         ▼                              ▼                    │
│  primary_data/                  replica_data/               │
│  (Persistent Volume)            (Persistent Volume)         │
└─────────────────────────────────────────────────────────────┘
```

### How It Works

1. **Primary Server** (`pgPrimary`)

   - Accepts all database operations (INSERT, UPDATE, DELETE)
   - Writes changes to WAL (Write-Ahead Log)
   - Streams WAL data to replica in real-time

2. **Replica Server** (`pgReplica`)

   - Receives WAL stream from primary
   - Applies changes to maintain data consistency
   - Operates in read-only mode (recovery mode)
   - Automatically initialized using `pg_basebackup`

3. **Replication Flow**
   ```
   Transaction → Primary WAL → Stream → Replica → Apply Changes
   ```

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Basic understanding of PostgreSQL

### Setup Steps

1. **Start the primary container** - Launch the primary PostgreSQL server that will accept all database operations.

2. **Configure primary for replication** (see detailed guide):

   - Create replication user with appropriate privileges
   - Configure WAL level to enable streaming replication
   - Set up authentication rules for replication connections

3. **Start the replica** - Launch the replica container which automatically initializes from the primary using `pg_basebackup`.

4. **Verify replication** - Check that the replica is connected and streaming data from the primary. The replica should be in recovery mode (read-only), and the primary should show an active replication connection.

## 📚 Documentation

For detailed step-by-step instructions, configuration explanations, and troubleshooting, see:

- **[Complete Setup Guide](steps_information.md)** - Comprehensive walkthrough with explanations

## ✨ Features

- ✅ **Streaming Replication** - Real-time data synchronization
- ✅ **Automatic Setup** - Replica auto-initializes from primary
- ✅ **Health Checks** - Primary container includes health monitoring
- ✅ **Persistent Storage** - Data volumes for both primary and replica
- ✅ **Docker Compose** - Easy orchestration and management
- ✅ **Educational** - Detailed explanations of WAL, replication concepts

## 🔧 Configuration Highlights

- **WAL Level:** `replica` (enables streaming replication)
- **Max WAL Senders:** 10 (allows multiple replicas)
- **WAL Keep Size:** 64MB (retains WAL for catch-up)
- **Replication User:** `replicator` with REPLICATION privilege

## 📊 Testing Replication

To verify replication is working, create test data on the primary server (databases, tables, and records). The changes should automatically appear on the replica server within seconds. You can query the replica to confirm that all data has been replicated successfully. The replica operates in read-only mode, so you can safely query it without affecting the primary.

## 🎯 Use Cases

- **High Availability** - Automatic failover scenarios
- **Read Scaling** - Distribute read queries across replicas
- **Backup Strategy** - Replica can serve as live backup
- **Disaster Recovery** - Geographic replication setups
- **Learning** - Understanding PostgreSQL replication internals

## 📝 Notes

- Replica operates in **read-only** mode (cannot accept writes)
- Replication is **asynchronous** by default (can be configured as synchronous)
- WAL (Write-Ahead Log) is the core mechanism enabling replication
- Changes typically appear on replica within seconds

## 🔗 Resources

- [PostgreSQL Replication Documentation](https://www.postgresql.org/docs/current/high-availability.html)
- [WAL Documentation](https://www.postgresql.org/docs/current/wal.html)
- [pg_basebackup Documentation](https://www.postgresql.org/docs/current/app-pgbasebackup.html)

---

**Note:** This is a demonstration setup. For production use, consider additional security measures, monitoring, and backup strategies.
