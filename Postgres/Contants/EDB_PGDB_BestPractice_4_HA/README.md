
## **🔹 Best Practice Configuration for High Availability & Performance**

To handle **35,000 active connections** while ensuring **data integrity and automatic failover**, we need to optimize:

✅ **PostgreSQL (Primary & Replicas)** – Performance tuning for high concurrency  
✅ **PgBouncer (2 Instances)** – Connection pooling to reduce PostgreSQL load  
✅ **EFM (Enterprise Failover Manager)** – Automatic failover handling  
✅ **OS & Kernel Optimizations** – Improve system limits for high connections

---

# **📌 1️⃣ PostgreSQL Configuration (`postgresql.conf`)**

### **Primary Server Configuration**

```ini
# Connection Limits
max_connections = 3000  # Limit to prevent overwhelming PostgreSQL
superuser_reserved_connections = 20  

# Memory Tuning (Assuming 128GB RAM)
shared_buffers = 32GB  # 25% of RAM
work_mem = 64MB  # Allocated for each sort operation
effective_cache_size = 80GB  # PostgreSQL cache estimation

# WAL & Checkpoint Configuration (for replication & durability)
wal_level = replica
max_wal_senders = 10  # Allow multiple standby connections
wal_keep_size = 8GB  # Keep WAL logs for faster recovery
synchronous_commit = remote_apply  # Ensures replication consistency
checkpoint_timeout = 15min
checkpoint_completion_target = 0.9
archive_mode = on
archive_command = 'cp %p /var/lib/postgresql/archivedir/%f'  # WAL Archiving

# Replication & Failover
synchronous_standby_names = 'ANY 1 (pg_replica_1, pg_replica_2)'  # At least 1 standby must acknowledge
hot_standby = on
```

✅ **Why?**

- **Limits `max_connections` to prevent exhaustion** – we will use PgBouncer for handling 35,000 connections.
- **Uses `synchronous_commit = remote_apply`** for better replication performance while ensuring data safety.
- **Keeps WAL logs longer (`wal_keep_size = 8GB`)** to allow quick recovery of failed standbys.

---

### **Standby (Replica) Configuration**

```ini
hot_standby = on
max_connections = 2000  # Allow read traffic from PgBouncer
primary_conninfo = 'host=primary-db.local user=replicator password=replica_pass'  # Auto-sync
```

✅ **Why?**

- **Allows read queries on replicas**, reducing load on the primary.
- **Ensures automatic reconnection to the primary.**

---

# **📌 2️⃣ PgBouncer Configuration (`pgbouncer.ini`)**

Since we have **two PgBouncer instances**, they **connect to the primary PostgreSQL** and distribute connections efficiently.

### **PgBouncer Configuration (Same on Both Instances)**

```ini
[pgbouncer]
max_client_conn = 40000  # Allow 40,000 client connections
default_pool_size = 750  # Per-database pool size
min_pool_size = 50
reserve_pool_size = 750
reserve_pool_timeout = 5
max_db_connections = 3000  # Matches PostgreSQL max_connections

# Pooling Mode (Transaction-Level Pooling is Best for High Concurrency)
pool_mode = transaction

# PostgreSQL Connection Settings
[databases]
mosip_master = host=primary-db.local port=5432 user=postgres dbname=mosip_master pool_mode=transaction
mosip_replica_1 = host=replica1-db.local port=5432 user=postgres dbname=mosip_master pool_mode=transaction
mosip_replica_2 = host=replica2-db.local port=5432 user=postgres dbname=mosip_master pool_mode=transaction
```

✅ **Why?**

- **Handles 40,000+ connections with pooling** (each backend connection serves multiple clients).
- **Distributes reads to replicas (`mosip_replica_*`)** for performance.
- **Uses `pool_mode = transaction`** (optimal for high-concurrency applications like MOSIP).

---

# **📌 3️⃣ EFM (Enterprise Failover Manager) Configuration (`efm.properties`)**

EFM **monitors PostgreSQL replication** and **automatically fails over** if the primary crashes.

### **EFM Configuration on All Three Servers**

Edit `/etc/edb/efm-4.0/efm.properties`:

```ini
db.user=efm
db.password=efm_pass
db.port=5432
db.database=postgres

# Primary & Standby Nodes
db.service.owner=postgres
db.service.name=edb-as
db.bin=/usr/edb/as15/bin

# Standby Auto-Failover Settings
auto.failover=true
auto.reconfigure=true
synchronous.replication=true  # Enforce sync replication
promote.synced.standby=true  # Promote a fully synced standby first

# Fencing (To Prevent Split-Brain)
fence.enabled=true
fence.script=/usr/edb/efm-4.0/bin/failover.sh
```

✅ **Why?**

- **Auto-failover enabled (`auto.failover=true`)** – ensures a replica takes over immediately.
- **Promotes only fully synced standby (`promote.synced.standby=true`)** to prevent data inconsistency.
- **Fencing (`fence.script`)** prevents the old primary from accidentally writing after a failover.

---

# **📌 4️⃣ Linux Kernel & OS Optimizations**

To **handle high connections and prevent performance bottlenecks**, adjust system limits.

### **Increase Open File Limits (`/etc/sysctl.conf`)**

```ini
fs.file-max = 2000000
net.core.somaxconn = 8192
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_syn_backlog = 16384
net.core.netdev_max_backlog = 10000
```

### **Increase PostgreSQL Process Limits (`/etc/security/limits.conf`)**

```ini
postgres  soft  nofile  500000
postgres  hard  nofile  1000000
postgres  soft  nproc   32768
postgres  hard  nproc   65536
```

✅ **Why?**

- **Prevents PgBouncer and PostgreSQL from running out of connections.**
- **Optimizes TCP/IP stack for high-performance networking.**

---

# **📌 5️⃣ Automatic Failover Workflow (EFM)**

### **How Failover Works with EFM**

1️⃣ **EFM detects primary failure** (using heartbeat monitoring).  
2️⃣ **EFM promotes a synchronous standby** (whichever is most up-to-date).  
3️⃣ **EFM updates PgBouncer connections** to point to the new primary.  
4️⃣ **When the old primary recovers**, it is **demoted to a replica** automatically.

### **EFM Failover Logs**

Monitor failover activity:

```bash
tail -f /var/log/efm-4.0.log
```

✅ **Why?**

- **Ensures zero downtime by promoting a standby instantly.**
- **PgBouncer re-routes queries automatically after failover.**

---

# **📌 Final Architecture**

✅ **Application → Two PgBouncer Instances → Primary & Replicas (via Streaming Replication) → EFM Handles Failover**

- **Writes go to the primary, reads go to replicas.**
- **PgBouncer pools connections to reduce PostgreSQL load.**
- **EFM ensures automatic failover without data loss.**

---

## **📌 Next Steps**

🔹 **Monitor PostgreSQL Replication Status:**

```sql
SELECT client_addr, state, sync_state FROM pg_stat_replication;
```

🔹 **Check PgBouncer Connection Pooling:**

```sql
SHOW POOLS;
```

🔹 **Test EFM Failover:**

```bash
systemctl stop edb-as
```




Since you have **EnterpriseDB Postgres Advanced Server (EPAS) with streaming replication across three nodes**, the configuration must be optimized for **high availability, replication efficiency, and handling 35,000 connections via PgBouncer**. Below are the adjusted parameters for **primary and standby nodes** while ensuring **replication consistency**.

---

## **1️⃣ Adjusted PostgreSQL Configuration (`postgresql.conf`)**

Modify **`postgresql.conf`** on all three nodes, adjusting for primary and standby roles.

### **🟢 Primary Node (Leader)**

```json
# Connection Limits
max_connections = 5000  # Managed by PgBouncer
superuser_reserved_connections = 10

# Memory Tuning
shared_buffers = 32GB
work_mem = 64MB
maintenance_work_mem = 2GB
effective_cache_size = 96GB

# Background Workers
max_worker_processes = 16
max_parallel_workers = 16
max_parallel_workers_per_gather = 4

# Replication Configuration
wal_level = replica   # Required for streaming replication
synchronous_commit = local  # `on` ensures full durability, but may slow writes
max_wal_senders = 10   # Number of standby nodes + some buffer
max_replication_slots = 10
wal_keep_size = 4GB    # Ensure WAL is available for standbys
hot_standby = on
synchronous_standby_names = 'ANY 1 (node2, node3)'  # Ensure at least one synchronous standby

# WAL Optimization for Replication
wal_buffers = 128MB
checkpoint_timeout = 15min
checkpoint_completion_target = 0.9
max_wal_size = 8GB
min_wal_size = 1GB

# Autovacuum Tuning
autovacuum = on
autovacuum_max_workers = 6
autovacuum_naptime = 30s
autovacuum_vacuum_cost_limit = 2000
autovacuum_vacuum_scale_factor = 0.02
autovacuum_analyze_scale_factor = 0.01

# Connection Keepalive (For Replication Stability)
tcp_keepalives_idle = 60
tcp_keepalives_interval = 10
tcp_keepalives_count = 5
```

---

### **🟠 Standby Nodes (node2 & node3)**

Modify **`postgresql.conf`** for standbys:

```json
# Connection Limits
max_connections = 5000
superuser_reserved_connections = 10

# Memory Tuning
shared_buffers = 32GB
work_mem = 64MB
maintenance_work_mem = 2GB
effective_cache_size = 96GB

# Streaming Replication Configuration
hot_standby = on
wal_level = replica
synchronous_standby_names = ''  # No sync needed on standbys
max_wal_senders = 10
max_replication_slots = 10
wal_keep_size = 4GB

# Archive & Recovery
archive_mode = on
archive_command = 'cp %p /var/lib/pgsql/14/archive/%f'
restore_command = 'cp /var/lib/pgsql/14/archive/%f %p'

# Connection Keepalive (To Prevent Timeouts)
tcp_keepalives_idle = 60
tcp_keepalives_interval = 10
tcp_keepalives_count = 5
```

---

## **2️⃣ Replication Configuration (`pg_hba.conf`)**

Ensure **primary and standby nodes** allow replication connections.

### **Primary Node (`/var/lib/pgsql/14/data/pg_hba.conf`)**

```ini
host    replication    replica_user   node2_ip/32  md5
host    replication    replica_user   node3_ip/32  md5
```

### **Standby Nodes (`/var/lib/pgsql/14/data/pg_hba.conf`)**

```ini
host    replication    replica_user   primary_ip/32  md5
```

Apply changes:

```bash
systemctl restart postgresql
```

---

## **3️⃣ Connection Pooling with PgBouncer**

PgBouncer must **route read queries to standby nodes** and **write queries to the primary node**.

### **PgBouncer Configuration (`/etc/pgbouncer/pgbouncer.ini`)**

```ini
[databases]
mosipdb = host=primary_ip port=5432 dbname=mosipdb user=mosip password=your_password
mosipdb_readonly = host=node2_ip port=5432 dbname=mosipdb user=mosip password=your_password

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction   # Use 'session' if needed
max_client_conn = 35000   # Total connections across nodes
default_pool_size = 2000
reserve_pool_size = 500
reserve_pool_timeout = 5
server_idle_timeout = 60
log_connections = 1
log_disconnections = 1
log_pooler_errors = 1
```

### **Start PgBouncer**

```bash
systemctl enable pgbouncer
systemctl restart pgbouncer
```

Test the connection:

```bash
psql -U mosip -h primary_ip -p 6432 -d mosipdb
```

---

## **4️⃣ OS Kernel Parameter Tuning (`sysctl.conf`)**

Modify **`/etc/sysctl.conf`** for **all nodes**:

```ini
# Shared Memory
kernel.shmmax = 85899345920
kernel.shmall = 20971520
kernel.shmmni = 4096

# Semaphores (for connection handling)
kernel.sem = 250 64000 100 512

# File Descriptors (Increase max open files)
fs.file-max = 4194304

# Virtual Memory
vm.swappiness = 10
vm.dirty_background_ratio = 3
vm.dirty_ratio = 15
vm.overcommit_memory = 2
vm.overcommit_ratio = 95

# Network Tuning
net.core.somaxconn = 8192
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_max_syn_backlog = 8192
net.core.netdev_max_backlog = 65536
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
```

Apply:

```bash
sysctl -p
```

---

## **5️⃣ File Descriptor Limits (`limits.conf`)**

Edit **`/etc/security/limits.conf`** and add:

```ini
postgres  soft  nofile  1048576
postgres  hard  nofile  1048576
postgres  soft  nproc   131072
postgres  hard  nproc   131072
```

Apply changes:

```bash
ulimit -n 1048576
ulimit -u 131072
```

---

## **6️⃣ Load Testing**

Run **pgbench** to simulate **35,000 connections**.

**🔹 Read Queries (Load on Standby)**

```bash
pgbench -U mosip -h node2_ip -p 6432 -c 35000 -j 16 -T 60 mosipdb_readonly
```

**🔹 Write Queries (Load on Primary)**

```bash
pgbench -U mosip -h primary_ip -p 6432 -c 35000 -j 16 -T 60 mosipdb
```

---

## **7️⃣ Failover & Recovery (EDB Failover Manager - EFM)**

To ensure automatic failover, use **EDB Failover Manager (EFM)**.

### **Install EFM**

```bash
dnf install -y edb-efm
```

### **Configure EFM on Primary**

Edit **`/etc/edb/efm-4.0/efm.properties`**:

```ini
cluster.name=mosip_cluster
db.user=postgres
db.port=5432
db.database=mosipdb
standby.priority=node2,node3
```

Start the service:

```bash
systemctl enable edb-efm-4.0
systemctl start edb-efm-4.0
```

---

## **✅ Final Steps**

1. **Restart all services**:
    
    ```bash
    systemctl restart postgresql
    systemctl restart pgbouncer
    systemctl restart edb-efm-4.0
    ```
    
2. **Monitor Replication**:
    
    ```bash
    SELECT * FROM pg_stat_replication;
    ```
    

---

### **Would you like a failover testing guide?** 🚀