# GoldenGate Lab: Oracle 11g + Oracle 19c → Kafka (via OGG for Big Data)

This guide walks through building a VMware lab that simulates the production topology in your reference docs:

- **Source A** — Oracle **11g** (11.2.0.4) + OGG Classic for Oracle
- **Source B** — Oracle **19c** + OGG for Oracle
- **Target**   — single Linux VM running **Apache Kafka** (two brokers, one per source) + **OGG for Big Data** (two replicats, one per source)

Both databases push changes through their own Extract → local trail → Pump Extract → remote trail on the Kafka VM, where a dedicated Big Data replicat streams each side into its own Kafka broker/topics. This mirrors the `legacy` (11g) / `reeng` (18c in the original, 19c here) split in `OGG_for_Bigdata_and_Kafka_installation.docx`.

---

## 0. Lab topology & naming

| Role           | Hostname        | IP (host-only/NAT) | RAM   | vCPU | Disk   | OS               |
| -------------- | --------------- | ------------------ | ----- | ---- | ------ | ---------------- |
| 11g source     | `lab-ora11g`    | `192.168.56.11`    | 6 GB  | 2    | 60 GB  | Oracle Linux 7.9 |
| 19c source     | `lab-ora19c`    | `192.168.56.19`    | 8 GB  | 2    | 80 GB  | Oracle Linux 7.9 |
| Kafka + OGG BD | `lab-kafka`     | `192.168.56.20`    | 6 GB  | 2    | 40 GB  | Oracle Linux 7.9 |

Software you need to stage (on each VM as appropriate):

- Oracle DB 11.2.0.4 (source A)
- Oracle DB 19c (source B)
- OGG 12.3.0.1 for Oracle 11g (classic) — `fbo_ggs_Linux_x64_shiphome.zip`
- OGG 19c for Oracle — `V983658-01.zip` (or equivalent 19.1.x for Oracle)
- OGG 19c for Big Data — `V983760-01.zip` (same file your reference doc uses)
- Apache Kafka `kafka_2.12-2.5.0.tgz`
- JDK 8 — `jdk-8u171-linux-x64.tar.gz`

> **Why two Kafka brokers on one VM?** The reference doc keeps the legacy and reeng streams physically separated — different zookeepers, different broker ports (9095 / 9096), different log dirs. I'm keeping that pattern because it's the cleanest way to test "what if one source goes bad" in a lab, and the ports/paths map one-to-one with your production config.

---

## 1. Common OS prep (run on all three VMs)

All three VMs share the same baseline. Do this as `root`.

```bash
# 1.1 Hostname + /etc/hosts (adjust per VM)
hostnamectl set-hostname lab-ora11g     # or lab-ora19c / lab-kafka

cat >> /etc/hosts <<'EOF'
192.168.56.11   lab-ora11g
192.168.56.19   lab-ora19c
192.168.56.20   lab-kafka
EOF

# 1.2 Disable firewall + SELinux (lab only)
systemctl stop firewalld
systemctl disable firewalld
sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
setenforce 0

# 1.3 Users and groups
groupadd oinstall
groupadd dba
useradd -g oinstall -G dba oracle
echo 'oracle:oracle' | chpasswd

# On lab-kafka ONLY — add the Big Data GG user
useradd -g oinstall -G dba ggscid
echo 'ggscid:ggscid' | chpasswd
mkdir -p /ggscid/app
chown -R ggscid:oinstall /ggscid

# 1.4 Resource limits
cat > /etc/security/limits.d/96-ggs.conf <<'EOF'
oracle   soft   nproc     65535
oracle   hard   nproc     65535
oracle   soft   nofile    65535
oracle   hard   nofile    65535
oracle   soft   memlock   unlimited
oracle   hard   memlock   unlimited
ggscid   soft   nproc     65535
ggscid   hard   nproc     65535
ggscid   soft   nofile    65535
ggscid   hard   nofile    65535
ggscid   soft   memlock   unlimited
ggscid   hard   memlock   unlimited
EOF

# 1.5 Oracle prerequisite packages (DB VMs)
yum install -y oracle-database-preinstall-19c       # on lab-ora19c
yum install -y oracle-rdbms-server-11gR2-preinstall # on lab-ora11g
# On lab-kafka you only need:
yum install -y unzip tar nc telnet which
```

Reboot each VM after the SELinux change.

---

## 2. Source A — Oracle 11g setup (`lab-ora11g`)

### 2.1 Install Oracle 11.2.0.4

Use the standard `runInstaller` flow — silent or GUI, your choice. Result:

- `ORACLE_HOME=/u01/app/oracle/product/11.2.0/dbhome_1`
- Single-instance DB `SID=orcl11g`, archive log mode **ON**.

Enable archivelog + force logging (mandatory for capture):

```sql
-- as SYS
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;

ALTER DATABASE FORCE LOGGING;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
ALTER SYSTEM SET ENABLE_GOLDENGATE_REPLICATION=TRUE SCOPE=BOTH;
ALTER SYSTEM SET STREAMS_POOL_SIZE=512M SCOPE=BOTH;
ALTER SYSTEM SET UNDO_RETENTION=86400 SCOPE=BOTH;
ALTER SYSTEM SWITCH LOGFILE;
```

### 2.2 Create GG user + test schema

```sql
-- tablespace + GG user
CREATE TABLESPACE ggs_data DATAFILE '/u01/app/oracle/oradata/orcl11g/ggs_data01.dbf'
  SIZE 100M AUTOEXTEND ON NEXT 10M;

CREATE USER ggs IDENTIFIED BY ggsGGS123
  DEFAULT TABLESPACE ggs_data TEMPORARY TABLESPACE temp;

GRANT CONNECT, RESOURCE, DBA TO ggs;
GRANT SELECT ANY DICTIONARY, SELECT ANY TABLE, SELECT ANY TRANSACTION TO ggs;
GRANT FLASHBACK ANY TABLE, EXECUTE ON DBMS_FLASHBACK, EXECUTE ON UTL_FILE TO ggs;
GRANT CREATE TABLE, ALTER ANY TABLE, ALTER SYSTEM, ALTER ANY SEQUENCE TO ggs;
GRANT INSERT ANY TABLE, UPDATE ANY TABLE, DELETE ANY TABLE, LOCK ANY TABLE TO ggs;
EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('GGS','*',TRUE);
GRANT INSERT ON system.logmnr_restart_ckpt$ TO ggs;
GRANT UPDATE ON sys.streams$_capture_process TO ggs;
GRANT BECOME USER TO ggs;

-- test schema that we will replicate to Kafka
CREATE USER src11g IDENTIFIED BY src11g
  DEFAULT TABLESPACE users QUOTA UNLIMITED ON users;
GRANT CONNECT, RESOURCE TO src11g;

CREATE TABLE src11g.customers (
  id      NUMBER PRIMARY KEY,
  name    VARCHAR2(100),
  email   VARCHAR2(100),
  updated TIMESTAMP DEFAULT SYSTIMESTAMP
);

CREATE TABLE src11g.orders (
  id          NUMBER PRIMARY KEY,
  customer_id NUMBER,
  amount      NUMBER(12,2),
  created     TIMESTAMP DEFAULT SYSTIMESTAMP
);
```

### 2.3 Install OGG 12.3 Classic for Oracle 11g

As `oracle`:

```bash
mkdir -p /u01/app/oracle/gghome
cd /u01/app/oracle/gghome
unzip /stage/fbo_ggs_Linux_x64_shiphome.zip -d /tmp/ogg11
cd /tmp/ogg11/fbo_ggs_Linux_x64_shiphome/Disk1
./runInstaller -silent -nowait \
  INSTALL_OPTION=ORA11g \
  SOFTWARE_LOCATION=/u01/app/oracle/gghome \
  START_MANAGER=false \
  DATABASE_LOCATION=$ORACLE_HOME
```

Add to `oracle`'s `.bash_profile`:

```bash
export ORACLE_SID=orcl11g
export ORACLE_HOME=/u01/app/oracle/product/11.2.0/dbhome_1
export GGHOME=/u01/app/oracle/gghome
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$GGHOME:$LD_LIBRARY_PATH
export PATH=$GGHOME:$ORACLE_HOME/bin:$PATH
```

Create subdirs:

```bash
cd $GGHOME
./ggsci <<'EOF'
CREATE SUBDIRS
EXIT
EOF
```

### 2.4 Configure Manager + credentials + Extract + Pump

Start inside `ggsci`:

```text
GGSCI> EDIT PARAMS MGR
```

```text
PORT 7809
DYNAMICPORTLIST 15000-15200
USERIDALIAS ggs
PURGEOLDEXTRACTS ./dirdat/*, MINKEEPDAYS 2, FREQUENCYMINUTES 30
LAGREPORTHOURS 1
LAGINFOMINUTES 30
LAGCRITICALMINUTES 45
STARTUPVALIDATIONDELAYCSECS 10
AUTOSTART ER *
AUTORESTART ER *, RETRIES 5, WAITMINUTES 2, RESETMINUTES 60
```

Then:

```text
GGSCI> ADD CREDENTIALSTORE
GGSCI> ALTER CREDENTIALSTORE ADD USER ggs@orcl11g, PASSWORD ggsGGS123, ALIAS ggs
GGSCI> START MGR
GGSCI> DBLOGIN USERIDALIAS ggs
GGSCI> ADD SCHEMATRANDATA src11g ALLCOLS
```

> **Why classic capture, not integrated, on 11g?** 11.2.0.4 does support integrated capture with the right bundle patch, but classic capture is one less moving part in a lab and fully adequate for DML. If you want to mirror the prod setup and have the patch applied, swap the `ADD EXTRACT` line below for the integrated form shown in the 19c section.

**Local extract** (`ext_kfk`) — reads redo, writes local trail `./dirdat/kf`:

```text
GGSCI> EDIT PARAMS ext_kfk
```

```text
EXTRACT ext_kfk
USERIDALIAS ggs
EXTTRAIL ./dirdat/kf
DISCARDFILE ./dirrpt/ext_kfk.dsc, APPEND, MEGABYTES 200
DISCARDROLLOVER AT 02:00 ON FRIDAY
LOGALLSUPCOLS
UPDATERECORDFORMAT FULL
STATOPTIONS RESETREPORTSTATS
REPORT AT 00:01
REPORTROLLOVER AT 00:01
REPORTCOUNT EVERY 1000 RECORDS
REPORTCOUNT EVERY 60 MINUTES, RATE
TABLE SRC11G.*;
```

```text
GGSCI> ADD EXTRACT ext_kfk, TRANLOG, BEGIN NOW
GGSCI> ADD EXTTRAIL ./dirdat/kf, EXTRACT ext_kfk, MEGABYTES 200
```

**Pump extract** (`pmp_kfk`) — reads local trail, ships to `lab-kafka`:

```text
GGSCI> EDIT PARAMS pmp_kfk
```

```text
EXTRACT pmp_kfk
USERIDALIAS ggs
RMTHOST lab-kafka, MGRPORT 7809, COMPRESS, TCPBUFSIZE 2266875, TCPFLUSHBYTES 2266875
RMTTRAIL ./dirdat/src11g/rt
PASSTHRU
TABLE SRC11G.*;
```

```text
GGSCI> ADD EXTRACT pmp_kfk, EXTTRAILSOURCE ./dirdat/kf
GGSCI> ADD RMTTRAIL ./dirdat/src11g/rt, EXTRACT pmp_kfk, MEGABYTES 200
GGSCI> START ER *
GGSCI> INFO ALL
```

You should see `ext_kfk` and `pmp_kfk` both RUNNING. `pmp_kfk` will fail (abend) until the Kafka VM's MGR is listening, which is fine — we'll come back to it.

---

## 3. Source B — Oracle 19c setup (`lab-ora19c`)

### 3.1 Install Oracle 19c (CDB + one PDB)

Standard install — `ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1`, CDB `orcl19c`, PDB `pdb19c`. Enable archivelog the same way as 11g, plus:

```sql
ALTER SYSTEM SET STREAMS_POOL_SIZE=1G SCOPE=BOTH;
ALTER SYSTEM SET ENABLE_GOLDENGATE_REPLICATION=TRUE SCOPE=BOTH;
ALTER SYSTEM SET UNDO_RETENTION=86400 SCOPE=BOTH;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
ALTER DATABASE FORCE LOGGING;
ALTER SYSTEM SWITCH LOGFILE;
```

### 3.2 Create GG common user + PDB test schema

```sql
-- In CDB$ROOT
CREATE TABLESPACE ggs_data DATAFILE '+DATA' SIZE 100M AUTOEXTEND ON NEXT 10M;

ALTER SESSION SET CONTAINER=pdb19c;
CREATE TABLESPACE ggs_data DATAFILE '+DATA' SIZE 100M AUTOEXTEND ON NEXT 10M;
ALTER PLUGGABLE DATABASE pdb19c STORAGE (MAXSIZE UNLIMITED);

ALTER SESSION SET CONTAINER=cdb$root;
CREATE USER c##ggs IDENTIFIED BY ggsGGS123
  DEFAULT TABLESPACE ggs_data TEMPORARY TABLESPACE temp;
GRANT CONNECT, RESOURCE, DBA TO c##ggs CONTAINER=ALL;
GRANT SELECT ANY DICTIONARY, SELECT ANY TABLE, SELECT ANY TRANSACTION TO c##ggs CONTAINER=ALL;
GRANT FLASHBACK ANY TABLE, EXECUTE ON DBMS_FLASHBACK, EXECUTE ON UTL_FILE TO c##ggs CONTAINER=ALL;
GRANT CREATE TABLE, ALTER ANY TABLE, ALTER SYSTEM, ALTER ANY SEQUENCE TO c##ggs CONTAINER=ALL;
GRANT INSERT ANY TABLE, UPDATE ANY TABLE, DELETE ANY TABLE, LOCK ANY TABLE TO c##ggs CONTAINER=ALL;
EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('C##GGS','*',TRUE,container=>'ALL');
GRANT INSERT ON system.logmnr_restart_ckpt$ TO c##ggs CONTAINER=ALL;
GRANT UPDATE ON sys.streams$_capture_process TO c##ggs CONTAINER=ALL;
GRANT BECOME USER TO c##ggs CONTAINER=ALL;
ALTER USER c##ggs SET CONTAINER_DATA=ALL CONTAINER=CURRENT;

-- Test schema in the PDB
ALTER SESSION SET CONTAINER=pdb19c;
CREATE USER src19c IDENTIFIED BY src19c
  DEFAULT TABLESPACE users QUOTA UNLIMITED ON users;
GRANT CONNECT, RESOURCE TO src19c;

CREATE TABLE src19c.products (
  id    NUMBER PRIMARY KEY,
  sku   VARCHAR2(50),
  price NUMBER(12,2)
);
CREATE TABLE src19c.inventory (
  id           NUMBER PRIMARY KEY,
  product_id   NUMBER,
  warehouse_id NUMBER,
  qty          NUMBER
);
```

### 3.3 Install OGG 19c for Oracle (classic architecture)

```bash
mkdir -p /u01/app/oracle/gghome
cd /u01/app/oracle/gghome
unzip /stage/V983658-01.zip -d /tmp/ogg19
cd /tmp/ogg19/fbo_ggs_Linux_x64_shiphome/Disk1
./runInstaller -silent -nowait \
  INSTALL_OPTION=ORA19c \
  SOFTWARE_LOCATION=/u01/app/oracle/gghome \
  START_MANAGER=false
```

`.bash_profile` for `oracle`:

```bash
export ORACLE_SID=orcl19c
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export GGHOME=/u01/app/oracle/gghome
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$GGHOME:$LD_LIBRARY_PATH
export PATH=$GGHOME:$ORACLE_HOME/bin:$PATH
```

```bash
cd $GGHOME && ./ggsci <<'EOF'
CREATE SUBDIRS
EXIT
EOF
```

### 3.4 GLOBALS, credentials, checkpoint table

`tnsnames.ora` — add an entry for the PDB:

```text
PDB19C_LOCAL =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = lab-ora19c)(PORT = 1521))
    (CONNECT_DATA = (SERVER = DEDICATED)(SERVICE_NAME = pdb19c))
  )

ORCL19C_LOCAL =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = lab-ora19c)(PORT = 1521))
    (CONNECT_DATA = (SERVER = DEDICATED)(SERVICE_NAME = orcl19c))
  )
```

In GGSCI:

```text
GGSCI> EDIT PARAMS ./GLOBALS
```

```text
GGSCHEMA C##GGS
CHECKPOINTTABLE PDB19C.C##GGS.GGS_CHECKPOINT
```

```text
GGSCI> ADD CREDENTIALSTORE
GGSCI> ALTER CREDENTIALSTORE ADD USER c##ggs@orcl19c_local, PASSWORD ggsGGS123, ALIAS ggs
GGSCI> ALTER CREDENTIALSTORE ADD USER c##ggs@pdb19c_local, PASSWORD ggsGGS123, ALIAS ggspdb
GGSCI> DBLOGIN USERIDALIAS ggspdb
GGSCI> ADD CHECKPOINTTABLE PDB19C.C##GGS.GGS_CHECKPOINT
```

### 3.5 Manager params

```text
GGSCI> EDIT PARAMS MGR
```

```text
PORT 7809
DYNAMICPORTLIST 15000-15200
USERIDALIAS ggs
PURGEOLDEXTRACTS ./dirdat/*, MINKEEPDAYS 2, FREQUENCYMINUTES 30
LAGREPORTHOURS 1
LAGINFOMINUTES 30
LAGCRITICALMINUTES 45
STARTUPVALIDATIONDELAYCSECS 10
AUTOSTART ER *
AUTORESTART ER *, RETRIES 5, WAITMINUTES 2, RESETMINUTES 60
```

```text
GGSCI> START MGR
GGSCI> DBLOGIN USERIDALIAS ggs
GGSCI> ADD SCHEMATRANDATA PDB19C.SRC19C ALLCOLS
GGSCI> REGISTER EXTRACT ext_kfk DATABASE CONTAINER (pdb19c)
```

### 3.6 Integrated Extract + Pump (19c uses integrated capture)

```text
GGSCI> EDIT PARAMS ext_kfk
```

```text
EXTRACT ext_kfk
USERIDALIAS ggs
TRANLOGOPTIONS MININGUSERALIAS ggs
TRANLOGOPTIONS INTEGRATEDPARAMS (MAX_SGA_SIZE 512, PARALLELISM 2, _CKPT_RETENTION_CHECK_FREQ 1200)
EXTTRAIL ./dirdat/kf
DISCARDFILE ./dirrpt/ext_kfk.dsc, APPEND, MEGABYTES 200
DISCARDROLLOVER AT 02:00 ON FRIDAY
LOGALLSUPCOLS
UPDATERECORDFORMAT FULL
STATOPTIONS RESETREPORTSTATS
REPORT AT 00:01
REPORTROLLOVER AT 00:01
REPORTCOUNT EVERY 1000 RECORDS
REPORTCOUNT EVERY 60 MINUTES, RATE
SOURCECATALOG PDB19C
TABLE SRC19C.* GETBEFORECOLS (ON UPDATE ALL, ON DELETE ALL);
```

```text
GGSCI> ADD EXTRACT ext_kfk, INTEGRATED TRANLOG, BEGIN NOW
GGSCI> ADD EXTTRAIL ./dirdat/kf, EXTRACT ext_kfk, MEGABYTES 200
```

```text
GGSCI> EDIT PARAMS pmp_kfk
```

```text
EXTRACT pmp_kfk
USERIDALIAS ggs
RMTHOST lab-kafka, MGRPORT 7809, COMPRESS, TCPBUFSIZE 2266875, TCPFLUSHBYTES 2266875
RMTTRAIL ./dirdat/src19c/rt
PASSTHRU
SOURCECATALOG PDB19C
TABLE SRC19C.*;
```

```text
GGSCI> ADD EXTRACT pmp_kfk, EXTTRAILSOURCE ./dirdat/kf
GGSCI> ADD RMTTRAIL ./dirdat/src19c/rt, EXTRACT pmp_kfk, MEGABYTES 200
GGSCI> START ER *
GGSCI> INFO ALL
```

Same as on 11g: both extracts will be RUNNING; the pump will abend until the Kafka VM is ready.

---

## 4. Target — Kafka + OGG Big Data (`lab-kafka`)

Everything here runs as `ggscid` unless I say otherwise.

### 4.1 Install JDK 8 and Kafka

As `oracle` (only for Kafka — keeps it separate from the GG user):

```bash
cd /oracle/app
tar xvfz /stage/kafka_2.12-2.5.0.tgz
cd /oracle/app/kafka_2.12-2.5.0/config

# Two zookeepers, two brokers — one pair per source
cp zookeeper.properties src11g_zookeeper.properties
cp zookeeper.properties src19c_zookeeper.properties
cp server.properties    src11g_server.properties
cp server.properties    src19c_server.properties

mkdir -p /oracle/app/kafka_2.12-2.5.0/tmp/src11g-kafka-logs
mkdir -p /oracle/app/kafka_2.12-2.5.0/tmp/src19c-kafka-logs
mkdir -p /oracle/app/kafka_2.12-2.5.0/tmp/src11g_zookeeper
mkdir -p /oracle/app/kafka_2.12-2.5.0/tmp/src19c_zookeeper

# ---- src11g (zookeeper 2185, broker 9095) ----
sed -i 's#dataDir=/tmp/zookeeper#dataDir=/oracle/app/kafka_2.12-2.5.0/tmp/src11g_zookeeper#' src11g_zookeeper.properties
sed -i 's/clientPort=2181/clientPort=2185/' src11g_zookeeper.properties
sed -i 's#log.dirs=/tmp/kafka-logs#log.dirs=/oracle/app/kafka_2.12-2.5.0/tmp/src11g-kafka-logs#' src11g_server.properties
sed -i 's/zookeeper.connect=localhost:2181/zookeeper.connect=localhost:2185/' src11g_server.properties
sed -i 's|#listeners=PLAINTEXT://:9092|listeners=PLAINTEXT://:9095|' src11g_server.properties

# ---- src19c (zookeeper 2186, broker 9096) ----
sed -i 's#dataDir=/tmp/zookeeper#dataDir=/oracle/app/kafka_2.12-2.5.0/tmp/src19c_zookeeper#' src19c_zookeeper.properties
sed -i 's/clientPort=2181/clientPort=2186/' src19c_zookeeper.properties
sed -i 's#log.dirs=/tmp/kafka-logs#log.dirs=/oracle/app/kafka_2.12-2.5.0/tmp/src19c-kafka-logs#' src19c_server.properties
sed -i 's/zookeeper.connect=localhost:2181/zookeeper.connect=localhost:2186/' src19c_server.properties
sed -i 's|#listeners=PLAINTEXT://:9092|listeners=PLAINTEXT://:9096|' src19c_server.properties

# ---- Broker IDs must differ ----
echo 'broker.id=0' >> src11g_server.properties   # replace the existing broker.id line if present
echo 'broker.id=1' >> src19c_server.properties

# ---- Consumer configs for quick verification ----
cat > src11g_consumer.properties <<EOF
bootstrap.servers=localhost:9095
group.id=src11g-consumer-group
EOF
cat > src19c_consumer.properties <<EOF
bootstrap.servers=localhost:9096
group.id=src19c-consumer-group
EOF
```

Start script:

```bash
mkdir -p ~/scripts
cat > ~/scripts/start-kafka.sh <<'EOF'
#!/bin/bash
K=/oracle/app/kafka_2.12-2.5.0
nohup $K/bin/zookeeper-server-start.sh $K/config/src11g_zookeeper.properties  > /tmp/zk11g.log 2>&1 &
nohup $K/bin/zookeeper-server-start.sh $K/config/src19c_zookeeper.properties  > /tmp/zk19c.log 2>&1 &
sleep 10
nohup $K/bin/kafka-server-start.sh     $K/config/src11g_server.properties     > /tmp/br11g.log 2>&1 &
nohup $K/bin/kafka-server-start.sh     $K/config/src19c_server.properties     > /tmp/br19c.log 2>&1 &
EOF
chmod +x ~/scripts/start-kafka.sh
~/scripts/start-kafka.sh
```

Verify:

```bash
# Should show four java processes (2 zk + 2 brokers)
jps
ss -tlnp | grep -E '2185|2186|9095|9096'
```

### 4.2 Install OGG for Big Data 19c

As `ggscid`:

```bash
cat > ~/.bash_profile <<'EOF'
export JAVA_HOME=/ggscid/app/product/jdk
export GGHOME=/ggscid/app/product/gghome
export PATH=$GGHOME:$JAVA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$JAVA_HOME/jre/lib/amd64/server:$LD_LIBRARY_PATH
EOF
source ~/.bash_profile

mkdir -p /ggscid/app/product
cd /ggscid/app/product
tar xvfz /stage/jdk-8u171-linux-x64.tar.gz
mv jdk1.8.0_171 jdk

mkdir -p $GGHOME && cd $GGHOME
unzip /stage/V983760-01.zip
tar xvf OGG_BigData_Linux_x64_19.1.0.0.1.tar

./ggsci <<'EOF'
CREATE SUBDIRS
EXIT
EOF

# Separate trail dirs so the two streams never collide
mkdir -p dirdat/src11g dirdat/src19c
```

### 4.3 Manager + Kafka producer props + handler props + replicats

```bash
cd $GGHOME/dirprm
```

**mgr.prm**:

```bash
cat > mgr.prm <<'EOF'
PORT 7809
DYNAMICPORTLIST 15000-15200
PURGEOLDEXTRACTS ./dirdat/*, MINKEEPDAYS 1, FREQUENCYMINUTES 30
LAGREPORTHOURS 1
LAGINFOMINUTES 30
LAGCRITICALMINUTES 45
STARTUPVALIDATIONDELAYCSECS 10
AUTOSTART ER *
AUTORESTART ER *, RETRIES 2, WAITMINUTES 10, RESETMINUTES 180
EOF
```

**Producer properties — one per source** (pointing at each broker):

```bash
cat > kfksrc11g_kafka_producer.properties <<'EOF'
bootstrap.servers=localhost:9095
acks=1
compression.type=gzip
reconnect.backoff.ms=1000
value.serializer=org.apache.kafka.common.serialization.ByteArraySerializer
key.serializer=org.apache.kafka.common.serialization.ByteArraySerializer
batch.size=102400
linger.ms=0
EOF

cat > kfksrc19c_kafka_producer.properties <<'EOF'
bootstrap.servers=localhost:9096
acks=1
compression.type=gzip
reconnect.backoff.ms=1000
value.serializer=org.apache.kafka.common.serialization.ByteArraySerializer
key.serializer=org.apache.kafka.common.serialization.ByteArraySerializer
batch.size=102400
linger.ms=0
EOF
```

**Handler properties (`.props`) — the JSON + Kafka handler definitions**:

```bash
cat > kfksrc11g.props <<'EOF'
gg.handlerlist=kafkahandler
gg.handler.kafkahandler.type=kafka
gg.handler.kafkahandler.KafkaProducerConfigFile=kfksrc11g_kafka_producer.properties
gg.handler.kafkahandler.topicMappingTemplate=${schemaName}
gg.handler.kafkahandler.keyMappingTemplate=${primaryKeys}
gg.handler.kafkahandler.format=json
gg.handler.kafkahandler.SchemaTopicName=SRC11G_SCHEMA
gg.handler.kafkahandler.BlockingSend=false
gg.handler.kafkahandler.includeTokens=false
gg.handler.kafkahandler.mode=op
gg.handler.kafkahandler.format.insertOpKey=I
gg.handler.kafkahandler.format.updateOpKey=U
gg.handler.kafkahandler.format.deleteOpKey=D

goldengate.userexit.writers=javawriter
javawriter.stats.display=TRUE
javawriter.stats.full=TRUE
gg.log=log4j
gg.log.level=INFO
gg.report.time=30sec
gg.classpath=dirprm/:/oracle/app/kafka_2.12-2.5.0/libs/*
javawriter.bootoptions=-Xmx512m -Xms32m -Djava.class.path=ggjava/ggjava.jar
EOF

cat > kfksrc19c.props <<'EOF'
gg.handlerlist=kafkahandler
gg.handler.kafkahandler.type=kafka
gg.handler.kafkahandler.KafkaProducerConfigFile=kfksrc19c_kafka_producer.properties
gg.handler.kafkahandler.topicMappingTemplate=${schemaName}
gg.handler.kafkahandler.keyMappingTemplate=${primaryKeys}
gg.handler.kafkahandler.format=json
gg.handler.kafkahandler.SchemaTopicName=SRC19C_SCHEMA
gg.handler.kafkahandler.BlockingSend=false
gg.handler.kafkahandler.includeTokens=false
gg.handler.kafkahandler.mode=op
gg.handler.kafkahandler.format.insertOpKey=I
gg.handler.kafkahandler.format.updateOpKey=U
gg.handler.kafkahandler.format.deleteOpKey=D

goldengate.userexit.writers=javawriter
javawriter.stats.display=TRUE
javawriter.stats.full=TRUE
gg.log=log4j
gg.log.level=INFO
gg.report.time=30sec
gg.classpath=dirprm/:/oracle/app/kafka_2.12-2.5.0/libs/*
javawriter.bootoptions=-Xmx512m -Xms32m -Djava.class.path=ggjava/ggjava.jar
EOF
```

> `topicMappingTemplate=${schemaName}` means data from `SRC11G.CUSTOMERS` lands in topic `SRC11G`, and `SRC19C.PRODUCTS` lands in topic `SRC19C`. Switch to `${tableName}` (or `${schemaName}_${tableName}`) if you want a topic per table.

**Replicat parameter files**:

```bash
cat > kfksrc11g.prm <<'EOF'
REPLICAT kfksrc11g
TARGETDB LIBFILE libggjava.so SET property=dirprm/kfksrc11g.props
REPORTCOUNT EVERY 1 MINUTES, RATE
GROUPTRANSOPS 10000
MAP SRC11G.*, TARGET SRC11G.*;
EOF

cat > kfksrc19c.prm <<'EOF'
REPLICAT kfksrc19c
TARGETDB LIBFILE libggjava.so SET property=dirprm/kfksrc19c.props
REPORTCOUNT EVERY 1 MINUTES, RATE
GROUPTRANSOPS 10000
MAP PDB19C.SRC19C.*, TARGET SRC19C.*;
EOF
```

Register the replicats:

```bash
cd $GGHOME
./ggsci <<'EOF'
ADD REPLICAT kfksrc11g, EXTTRAIL ./dirdat/src11g/rt
ADD REPLICAT kfksrc19c, EXTTRAIL ./dirdat/src19c/rt
START MGR
INFO ALL
EXIT
EOF
```

---

## 5. Bring it up end-to-end

### 5.1 Start order

1. On `lab-kafka`: Kafka brokers (already started) → OGG Big Data MGR (already started above).
2. On `lab-ora11g`: `ggsci> START ER *` (if not already running).
3. On `lab-ora19c`: `ggsci> START ER *` (if not already running).
4. On `lab-kafka`: `ggsci> START REPLICAT kfksrc11g` and `START REPLICAT kfksrc19c`.

Check `INFO ALL` on each side — everything should be **RUNNING** with zero lag.

### 5.2 Smoke test from 11g

On `lab-ora11g` as `src11g`:

```sql
INSERT INTO src11g.customers(id, name, email) VALUES (1, 'Alice', 'alice@example.com');
INSERT INTO src11g.customers(id, name, email) VALUES (2, 'Bob',   'bob@example.com');
UPDATE  src11g.customers SET email='alice@corp.com' WHERE id=1;
COMMIT;
```

On `lab-kafka`:

```bash
/oracle/app/kafka_2.12-2.5.0/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9095 \
  --topic SRC11G --from-beginning
```

You should see JSON events with `"op_type":"I"` and `"op_type":"U"`.

### 5.3 Smoke test from 19c

On `lab-ora19c`, inside the PDB, as `src19c`:

```sql
INSERT INTO src19c.products(id, sku, price) VALUES (1, 'SKU-001', 9.99);
INSERT INTO src19c.products(id, sku, price) VALUES (2, 'SKU-002', 19.99);
DELETE FROM src19c.products WHERE id=2;
COMMIT;
```

On `lab-kafka`:

```bash
/oracle/app/kafka_2.12-2.5.0/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9096 \
  --topic SRC19C --from-beginning
```

Expected: insert/insert/delete events in JSON.

### 5.4 Useful verification commands

```bash
# List topics on each broker
kafka-topics.sh --bootstrap-server localhost:9095 --list
kafka-topics.sh --bootstrap-server localhost:9096 --list

# Current lag per replicat
./ggsci -e "INFO REPLICAT kfksrc11g, DETAIL"
./ggsci -e "INFO REPLICAT kfksrc19c, DETAIL"

# Current lag per extract/pump
./ggsci -e "INFO EXTRACT ext_kfk, DETAIL"
./ggsci -e "INFO EXTRACT pmp_kfk, DETAIL"

# Trail contents on the target side
./logdump
Logdump> OPEN ./dirdat/src11g/rt000000000
Logdump> POS 0
Logdump> DETAIL DATA
Logdump> NEXT
```

---

## 6. Troubleshooting cheatsheet

| Symptom                                                              | Likely cause                                                                            | Fix                                                                               |
| -------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| Pump on source ABENDs, `OGG-01224 Connection refused`                | Kafka-VM MGR not running, or firewall/SELinux still enforcing on `lab-kafka`            | Start MGR; confirm `ss -tlnp | grep 7809`; disable firewalld + SELinux as in §1.2 |
| Replicat ABENDs with `OGG-01161: Bad column index`                   | `ADD SCHEMATRANDATA ... ALLCOLS` not done before first DML                              | Stop extract, redo `ADD SCHEMATRANDATA ... ALLCOLS`, re-add extract `BEGIN NOW`   |
| Replicat starts but no Kafka messages appear                         | Classpath wrong in `.props`; broker unreachable; topic creation disabled                | Check `gg.classpath` points at your Kafka `libs/*`; tail `ggserr.log`            |
| `OGG-10141 Unable to create/register the MBean` warnings             | Monitoring enabled but not needed                                                       | Remove `ENABLEMONITORING` from `./GLOBALS` in the lab                             |
| `ORA-01031 insufficient privileges` during integrated capture on 19c | Missing `DBMS_GOLDENGATE_AUTH` grant or CDB-wide grants                                 | Re-run the `GRANT_ADMIN_PRIVILEGE` + container-wide grants in §3.2                |
| Trail mismatch errors on target replicat                             | Source OGG version newer than target BD, or mixed trail formats                         | Use OGG BD **19.1 or newer** on target — it reads older trails, not the reverse  |
| 11g pump can't connect to BD MGR but `telnet lab-kafka 7809` works   | BD MGR allocated dynamic port outside `DYNAMICPORTLIST` range                           | Widen `DYNAMICPORTLIST` on BD `mgr.prm` and restart MGR                           |
| Kafka broker won't start, `InconsistentBrokerIdException`            | Both brokers defaulted to `broker.id=0`                                                 | Set distinct `broker.id` values (I used 0 and 1 above)                            |

---

## 7. What to do once the lab works

- **Try Avro schema registry** — swap `format=json` for `format=avro_op` and add a Confluent schema registry container.
- **Try per-table topics** — switch `topicMappingTemplate` to `${schemaName}_${tableName}` and watch new topics auto-create.
- **Simulate a failover** — stop the 19c pump, generate DML, restart it, and confirm no message loss on Kafka (default is at-least-once; expect possible duplicates).
- **Add a DDL test** — enable `DDL INCLUDE MAPPED` on the Oracle-side extract and observe how DDL flows through (Big Data replicat will log them but won't apply schema changes to Kafka, since Kafka is schemaless at the topic level).
- **Move to OGG Microservices** — same topology, but managed via the web UI on port 9100+ with distribution paths instead of pump extracts. Your 19c source is the right candidate to migrate first.

---

## Appendix A — Reference-doc alignment

If you want to compare this guide directly against your attached doc:

| Reference doc term         | This lab's equivalent           |
| -------------------------- | ------------------------------- |
| `legacy` (11g UDB)         | `src11g`                        |
| `reeng` (18c)              | `src19c`                        |
| Broker `9095` / zk `2185`  | Same (kept deliberately)        |
| Broker `9096` / zk `2186`  | Same (kept deliberately)        |
| `./dirdat/legacy/rt`       | `./dirdat/src11g/rt`            |
| `./dirdat/reeng/rt`        | `./dirdat/src19c/rt`            |
| `kfklgcy` / `kfkreeng`     | `kfksrc11g` / `kfksrc19c`       |
| `cidkafka` pump            | `pmp_kfk` on each source        |
| `ext_kfk` on each source   | Same name retained              |
| `192.168.42.120` (BD host) | `lab-kafka` / `192.168.56.20`   |

Everything else — producer props, handler props template, `REPORTCOUNT`/`GROUPTRANSOPS`, user grants, ASM vs filesystem tablespace choice — follows the same pattern as your existing production setup.
