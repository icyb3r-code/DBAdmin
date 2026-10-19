# MongoDB 8.3 Enterprise Replica Set (prd-rst) - 3 HQ Nodes + 3 DR Nodes + Ops Manager 9.0 Monitoring - Oracle Linux 10.2 - No TLS

**HOW TO READ THIS FILE**

Every step says where to run it:

- `ALL NODES` - run on hqmngodb01, hqmngodb02 and hqmngodb03 (and on drmngodb01, drmngodb02 and drmngodb03 when you build the DR site in STEP 32)
- `DR NODES` - run on drmngodb01, drmngodb02 and drmngodb03 (STEP 32)
- `hqmngodb01 ONLY` - run only on the first node
- `PER NODE` - run on every node, but change the value at the top of the block (`MY_IP`)
- `mongosh` blocks (marked **(mongosh)**) are pasted into the MongoDB shell, not into bash

Run all bash commands as root (`sudo -i`). Copy a whole block and paste it at the shell prompt. Never paste a block into vi/nano: the commands are meant for the shell, not for a file.

## Environment

```
OS                : Oracle Linux 10.2 (Red Hat Compatible Kernel - NOT UEK)
MongoDB           : Enterprise 8.3.13 (el10 packages) - all 6 nodes (HQ and DR) must run the same version
Replica set name  : prd-rst  (lowercase - names are case-sensitive) - ONE replica set across both sites
Port              : 27017
TLS               : NOT used. Authentication = keyFile (between nodes) + users (authorization enabled)
Firewall          : firewalld ENABLED (port 27017 opened in STEP 4 on every node, HQ and DR)
SELinux           : DISABLED (verified / disabled in STEP 3)
Data volume       : /dev/mapper/mngovg-data mounted on /data (9.9 GB, XFS)

HQ site (production)
Node 1  hqmngodb01  10.10.21.30  preferred primary (priority 2, votes 1, tag dc:HQ)
Node 2  hqmngodb02  10.10.21.31  secondary         (priority 1, votes 1, tag dc:HQ)
Node 3  hqmngodb03  10.10.21.32  secondary         (priority 1, votes 1, tag dc:HQ)

DR site (STEP 32) - replace the 10.10.22.x IPs with the real DR IPs everywhere in this file
Node 4  drmngodb01  10.10.22.30  DR secondary      (priority 0, votes 1, tag dc:DR)
Node 5  drmngodb02  10.10.22.31  DR secondary      (priority 0, votes 1, tag dc:DR)
Node 6  drmngodb03  10.10.22.32  DR secondary      (priority 0, votes 0, tag dc:DR)

OM      hqmngoom01  10.10.21.40  Ops Manager 9.0 + its Application Database (MongoDB 9.0) on the SAME server - monitoring and alerting only (STEPS 25-30). Replace 10.10.21.40 with the real IP.

Folders: /data/mongodb/data (database files), /data/mongodb/keyfile (replica-set key file),
         /var/log/mongodb (mongod.log on the root filesystem, so logs can never fill /data)

```

### Notes before you start

1. Use the el10 RPMs. The el8 package is not the right build for Oracle Linux 10.
2. 8.3 is a minor (rapid) release with a shorter support horizon than 8.0. The steps are identical for 8.0.x.
3. /data is only 9.9 GB. Keep data below about 60 percent, extend the LVM volume early, and store backups on SEPARATE storage (STEP 17).
4. Without TLS, passwords and data travel unencrypted on the network. Keep port 27017 reachable only from networks you trust if you can restrict it later.
5. Passwords below are placeholders (<ROOT_PASSWORD> etc). mongosh asks for them with passwordPrompt(), so they are never stored in a file.
6. Read "Version and support validation" below BEFORE building. It lists what is officially supported and what is only an inference.
7. STEPS 1-24 build the replica set at HQ. STEPS 25-30 build Ops Manager (monitoring and alerting only). STEP 31 is patching. STEP 32 joins the DR site (drmngodb01-03) to prd-rst and covers the DR switchover, DR activation and failback.

## Version and support validation

```
Checked against MongoDB documentation on 17 Oct 2026. "Supported" = stated in the docs. "Inference" = not stated, derived from a rule. Re-check before sign-off.

1. Oracle Linux 10 + MongoDB server (replica set nodes)
   Supported. MongoDB's Enterprise platform page lists "RHEL/Rocky/Alma/Oracle Linux 10, x86_64" as supported for 9.x, 8.x and 7.x.
   Condition: Oracle Linux must run the Red Hat Compatible Kernel (RHCK). UEK is NOT supported.
   Also: the CPU must expose AVX (MongoDB 5.0+). Kernels 6.19 through 7.0.13 are incompatible with MongoDB (7.0.14+ fixed it).

2. MongoDB 8.0 on Oracle Linux 10
   NOT AVAILABLE from the yum repo: https://repo.mongodb.com/yum/redhat/10/mongodb-enterprise/8.0/ returns 404 (confirmed on hqmngoom01).
   So on el10 the server choices are 8.3 (rapid release) and 9.0 only.

3. Replica set nodes: MongoDB 8.3.13
   Supported on OL 10 (item 1). 8.3 is a rapid release with a shorter support horizon than a major release - plan patching (STEP 31).
   Monitoring by Ops Manager 9.0: INFERENCE. The OM 9.0 compatibility table lists only the series 7.0, 8.0 and 9.0 and says support covers the full series. 8.3 is not named. (OM 8.0.23 release notes explicitly enable 8.3 for managed deployments - that is OM 8.0, not 9.0.)
   Action: confirm with MongoDB Support if you need written support for OM 9.0 monitoring 8.3.13.

4. Ops Manager 9.0.x (use 9.0.1, released 2026-10-05)
   9.0.0 (2026-09-29) added RHEL 10 support for the OM application and the MongoDB Agent.
   OM application OS list: RHEL 8, 9, 10. Oracle Linux is NOT listed for the OM application (it IS listed for the MongoDB Agent: RHEL/Oracle Linux 7-10).
   Verdict: OL 10.2 is RHEL-compatible and will normally work, but it is not a listed platform for the OM server. For strict vendor support build hqmngoom01 on RHEL 10 - every command below is identical.

5. Application Database (the "repository" of Ops Manager)
   OM 9.0 backing database versions: MongoDB 8.0 and 9.0 supported (7.0 deprecated). MongoDB 8.2 and 8.3 are NOT supported. Use a major release and its patches only.
   Because 8.0 has no el10 repo (item 2), the only supported Application Database on el10 is MongoDB 9.0.x. This is separate from the 8.3.13 replica set; the versions do not need to match.
   Ops Manager 8.0 is not an alternative on el10: it needs a 7.0 or 8.0 Application Database.
   Topology: the docs require a dedicated replica set (3 data-bearing members recommended; one member may sit on the OM host). A standalone is documented as a test setup only. This guide builds a single-node replica set on hqmngoom01: it meets the replica-set requirement but has NO failover. Adding two more members later is a rs.add() with no rebuild.
   TLS: the docs say to require TLS from OM to the Application Database. This guide omits TLS by your decision; the database listens only on the server's own IP and port 27017 is not opened in the firewall.

6. Ops Manager sizing (monitoring only, backup disabled, up to 400 hosts): application 4+ cores, about 15 GB RAM, 10 GB in /opt, 20 GiB free in /tmp, about 30 GB per month of logs; Application Database 4 cores, RAM of 8 GB plus mongod needs, 200 GB SSD, WiredTiger. Same server = add the requirements together.

Summary of what is NOT fully vendor-supported in this design (accepted risks): (a) OL instead of RHEL for the OM server, (b) OM 9.0 monitoring of MongoDB 8.3.13 (inference), (c) single-node Application Database (no HA), (d) no TLS to the Application Database.
```

---

## STEP 1 - Check the kernel and the data volume

**Run on:** `ALL NODES`

The kernel name must NOT contain "uek" (UEK is not supported by MongoDB).

```bash
uname -r
grep -m1 -o avx /proc/cpuinfo
```

The second command must print avx (MongoDB 5.0+ needs an AVX-capable CPU; on VMware set the VM CPU compatibility so AVX is exposed). Kernels 6.19 through 7.0.13 are incompatible with MongoDB.

Data volume checks.

```bash
lsblk
df -hT /data
findmnt /data
grep /data /etc/fstab
```

Expected fstab line (XFS is required, noatime is recommended): /dev/mapper/mngovg-data /data xfs defaults,noatime 0 0  
If noatime is missing, add it to the options in /etc/fstab, then remount:

```bash
mount -o remount /data
```

### OPTIONAL - only if /data does NOT exist yet (LVM + XFS)

Replace /dev/sdX with the real new disk. This DESTROYS data on that disk. First create one partition of type 8e with the interactive command: fdisk /dev/sdX (n, p, 1, Enter, Enter, t, 8e, w). Then:

```bash
pvcreate /dev/sdX1
vgcreate mngovg /dev/sdX1
lvcreate mngovg -n data -l 100%FREE
mkfs.xfs /dev/mapper/mngovg-data
mkdir -p /data
echo '/dev/mapper/mngovg-data /data xfs defaults,noatime 0 0' >> /etc/fstab
mount -a
df -h /data
```

---

## STEP 2 - Hostname, hosts file and time

**Run on:** `ALL NODES`

Add the hosts of BOTH sites (HQ and DR), so every node can resolve every member. The loop adds only the names that are missing, so it is safe to run again.

```bash
for e in "10.10.21.30     hqmngodb01" "10.10.21.31     hqmngodb02" "10.10.21.32     hqmngodb03" \
         "10.10.22.30     drmngodb01" "10.10.22.31     drmngodb02" "10.10.22.32     drmngodb03"; do
  grep -qw "${e##* }" /etc/hosts || echo "$e" >> /etc/hosts
done
```

Set the hostname. Change the name on each node (hqmngodb01 / hqmngodb02 / hqmngodb03; drmngodb01 / drmngodb02 / drmngodb03 at DR).

```bash
hostnamectl set-hostname hqmngodb01
```

Check name resolution.

```bash
getent hosts hqmngodb01 hqmngodb02 hqmngodb03 drmngodb01 drmngodb02 drmngodb03
```

Time sync: edit /etc/chrony.conf and set server <internal-ntp-ip> iburst then:

```bash
systemctl enable --now chronyd
chronyc tracking
```

---

## STEP 3 - SELinux - verify, and disable if it is not already

**Run on:** `ALL NODES`

Check the current state.

```bash
getenforce
sestatus
```

If it shows Enforcing or Permissive, disable it permanently, confirm the file, and stop enforcing right now (until the reboot in STEP 5). setenforce prints an error if SELinux is already disabled - that is harmless.

```bash
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
grep '^SELINUX=' /etc/selinux/config
setenforce 0
```

Expected from grep: SELINUX=disabled. The state becomes fully "Disabled" only after the reboot in STEP 5.

---

## STEP 4 - Firewall (firewalld stays ENABLED) - open port 27017

**Run on:** `ALL NODES`

Port 27017/tcp is opened inbound from ALL source IPs (every application and every node) and on ALL interfaces.

```bash
systemctl enable --now firewalld
```

Open the port in EVERY active zone (covers all network interfaces).

```bash
for z in $(firewall-cmd --get-active-zones | grep -v '^ '); do firewall-cmd --permanent --zone=$z --add-port=27017/tcp; done
```

Also open it explicitly in the public zone (safe even if it is already covered), then apply.

```bash
firewall-cmd --permanent --zone=public --add-port=27017/tcp
firewall-cmd --reload
```

Verify: 27017/tcp must be listed for every active zone.

```bash
firewall-cmd --get-active-zones
firewall-cmd --list-all-zones | grep -E '^[a-z]|ports:'
```

To remove the rule later (replace <ZONE>):

```bash
firewall-cmd --permanent --zone=<ZONE> --remove-port=27017/tcp
firewall-cmd --reload
```

---

## STEP 5 - Kernel tuning, THP, limits, then REBOOT

**Run on:** `ALL NODES`

### 5.1 Swappiness and kernel settings

```bash
cat > /etc/sysctl.d/99-mongodb.conf <<'EOF'
vm.swappiness = 1
vm.overcommit_memory = 1
vm.max_map_count = 262144
net.ipv4.tcp_keepalive_time = 120
EOF
sysctl --system
cat /proc/sys/vm/swappiness
```

### 5.2 Transparent Huge Pages (MongoDB 8.x wants THP ENABLED)

Older MongoDB versions (4.4 - 7.0) disable THP. MongoDB 8.x uses per-CPU TCMalloc and the official TCMalloc page tells you to ENABLE it, as below.

```bash
cat > /etc/systemd/system/mongodb-thp.service <<'EOF'
[Unit]
Description=MongoDB 8.x Transparent Huge Page settings
DefaultDependencies=no
After=sysinit.target local-fs.target
Before=mongod.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo always > /sys/kernel/mm/transparent_hugepage/enabled; echo defer+madvise > /sys/kernel/mm/transparent_hugepage/defrag; echo 0 > /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none'
RemainAfterExit=yes

[Install]
WantedBy=basic.target
EOF
systemctl daemon-reload
systemctl enable --now mongodb-thp.service
```

Expected output: always, defer+madvise, 0

```bash
cat /sys/kernel/mm/transparent_hugepage/enabled /sys/kernel/mm/transparent_hugepage/defrag /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none
```

### 5.3 User limits

The mongod RPM service already sets 64000 limits; this file is only a safety net.

```bash
cat > /etc/security/limits.d/99-mongodb-nproc.conf <<'EOF'
mongod          soft    nproc     64000
mongod          hard    nproc     64000
mongod          soft    nofile    64000
mongod          hard    nofile    64000
mongod          soft    memlock   unlimited
mongod          hard    memlock   unlimited
EOF
```

### 5.4 Reboot (needed for SELinux). Reboot one node at a time.

```bash
reboot
```

AFTER THE REBOOT, on every node: getenforce must print Disabled, and THP must show [always].

```bash
getenforce
cat /sys/kernel/mm/transparent_hugepage/enabled
```

---

## STEP 6 - Dependency packages (checklist)

**Run on:** `ALL NODES`

Required by MongoDB Enterprise (from the MongoDB documentation): cyrus-sasl cyrus-sasl-gssapi cyrus-sasl-plain krb5-libs libcurl openldap openssl xz-libs  
Operational packages used in this guide: chrony firewalld policycoreutils lsof sysstat numactl tuned xfsprogs  
Old notes also list libpcap, lm_sensors-libs, net-snmp, net-snmp-agent-libs, rpm-libs and tcp_wrappers-libs. They were for old MongoDB versions and are not in the current 8.3 dependency list (tcp_wrappers-libs does not exist on OL10). Check your RPMs with: rpm -qpR <rpm-file>

Check what is installed or missing.

```bash
for p in cyrus-sasl cyrus-sasl-gssapi cyrus-sasl-plain krb5-libs libcurl openldap openssl xz-libs chrony firewalld policycoreutils lsof sysstat numactl tuned xfsprogs; do rpm -q "$p" >/dev/null 2>&1 && echo "OK       $p" || echo "MISSING  $p"; done
```

Install them (OL 10.2 ISO repo, local repo or internet repo).

```bash
dnf install -y cyrus-sasl cyrus-sasl-gssapi cyrus-sasl-plain krb5-libs libcurl openldap openssl xz-libs chrony firewalld policycoreutils lsof sysstat numactl tuned xfsprogs
```

---

## STEP 7 - Download the MongoDB packages (el10, 8.3.13) - AIR-GAPPED preparation only

**Run on:** `internet-connected OL 10.2 staging host`

Skip this step if your nodes use the official repo (STEP 8B). Packages needed (server 8.3.13; mongosh and database-tools have their own version numbers):  
mongodb-enterprise-server, mongodb-enterprise-database, mongodb-enterprise-mongos, mongodb-enterprise-tools, mongodb-enterprise-database-tools-extra, mongodb-database-tools, mongodb-mongosh (pulled in automatically by the tools package).  
Repo path (confirm exact file names there): https://repo.mongodb.com/yum/redhat/10/mongodb-enterprise/8.3/x86_64/RPMS/

```bash
mkdir -p /stage/mongodb /stage/os-deps
```

```bash
cat > /etc/yum.repos.d/mongodb-enterprise-8.3.repo <<'EOF'
[mongodb-enterprise-8.3]
name=MongoDB Enterprise Repository
baseurl=https://repo.mongodb.com/yum/redhat/10/mongodb-enterprise/8.3/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-8.0.asc
EOF
```

The signing key is server-8.0.asc. There is NO server-8.3.asc (that URL returns 404 and the install fails).

```bash
dnf download --resolve --alldeps --destdir=/stage/mongodb mongodb-enterprise-server-8.3.13 mongodb-enterprise-database-8.3.13 mongodb-enterprise-mongos-8.3.13 mongodb-enterprise-tools-8.3.13 mongodb-enterprise-database-tools-extra-8.3.13 mongodb-database-tools
```

```bash
dnf download --resolve --alldeps --destdir=/stage/os-deps cyrus-sasl cyrus-sasl-gssapi cyrus-sasl-plain krb5-libs libcurl openldap openssl xz-libs chrony firewalld policycoreutils lsof sysstat numactl tuned xfsprogs createrepo_c
```

Record the exact requirements of every MongoDB RPM, then create checksums and copy /stage to every node (for example to /opt/stage).

```bash
for f in /stage/mongodb/mongodb-*.rpm; do echo "== $f"; rpm -qpR "$f"; done > /stage/mongodb/rpm-requires.txt
cd /stage && find . -type f -not -name SHA256SUMS -exec sha256sum {} \; > SHA256SUMS
```

Shortcut for the OS packages: mount the Oracle Linux 10.2 ISO on each node and use its BaseOS and AppStream as a local dnf repo.

---

## STEP 8 - Install MongoDB

**Run on:** `ALL NODES`

### 8A. MANUAL / AIR-GAPPED (RPM files copied to /opt/stage)

```bash
cd /opt/stage && sha256sum -c SHA256SUMS
```

```bash
dnf install -y createrepo_c
createrepo_c /opt/stage/os-deps
createrepo_c /opt/stage/mongodb
```

```bash
cat > /etc/yum.repos.d/local-mongodb.repo <<'EOF'
[local-os-deps]
name=Local OS deps
baseurl=file:///opt/stage/os-deps
enabled=1
gpgcheck=0

[local-mongodb]
name=Local MongoDB Enterprise 8.3.13
baseurl=file:///opt/stage/mongodb
enabled=1
gpgcheck=0
EOF
```

```bash
dnf install -y mongodb-enterprise-server-8.3.13 mongodb-enterprise-database-8.3.13 mongodb-enterprise-mongos-8.3.13 mongodb-enterprise-tools-8.3.13 mongodb-enterprise-database-tools-extra-8.3.13 mongodb-database-tools
```

Without a local repo you can instead run: dnf install -y /opt/stage/os-deps/_.rpm then dnf install -y /opt/stage/mongodb/_.rpm (dnf resolves the order; do NOT use rpm --nodeps).

### 8B. AUTOMATIC / OFFICIAL MONGODB REPO (nodes with internet, proxy or mirror)

```bash
cat > /etc/yum.repos.d/mongodb-enterprise-8.3.repo <<'EOF'
[mongodb-enterprise-8.3]
name=MongoDB Enterprise Repository
baseurl=https://repo.mongodb.com/yum/redhat/10/mongodb-enterprise/8.3/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-8.0.asc
EOF
dnf clean all
```

Pin the SAME version on all three nodes. When dnf asks to import the GPG key, compare the fingerprint with MongoDB's documentation before answering y.

```bash
dnf install mongodb-enterprise-8.3.13 mongodb-enterprise-database-8.3.13 mongodb-enterprise-server-8.3.13 mongodb-enterprise-mongos-8.3.13 mongodb-enterprise-tools-8.3.13
```

### 8C. After either method

```bash
rpm -qa | grep -i mongo
mongod --version
mongosh --version
```

If mongosh fails to start with an OpenSSL error, swap to the system-OpenSSL build:

```bash
dnf remove -y mongodb-mongosh && dnf install -y mongodb-mongosh-shared-openssl3
```

Prevent accidental upgrades of MongoDB packages (run once per node):

```bash
echo 'exclude=mongodb-enterprise,mongodb-enterprise-database,mongodb-enterprise-server,mongodb-enterprise-shell,mongodb-enterprise-mongos,mongodb-enterprise-tools' >> /etc/dnf/dnf.conf
```

---

## STEP 9 - Create the MongoDB directories

**Run on:** `ALL NODES`

```bash
mkdir -p /data/mongodb/{data,keyfile}
mkdir -p /var/log/mongodb
chown -R mongod:mongod /data/mongodb /var/log/mongodb
chmod 750 /data/mongodb/data
```

---

## STEP 10 - Create the key file and copy it to the other nodes

**Run on:** `hqmngodb01 ONLY`

The key file lets the nodes authenticate to each other. Create it ONCE on hqmngodb01; all three nodes must have the identical file.

```bash
openssl rand -base64 741 > /data/mongodb/keyfile/mongo-keyfile
chmod 400 /data/mongodb/keyfile/mongo-keyfile
chown mongod:mongod /data/mongodb/keyfile/mongo-keyfile
```

Copy it to the other nodes (the folders already exist from STEP 9). If SSH between servers is not allowed, copy the file by your approved method.

```bash
for n in hqmngodb02 hqmngodb03; do scp /data/mongodb/keyfile/mongo-keyfile root@$n:/data/mongodb/keyfile/mongo-keyfile; done
```

---

## STEP 11 - Fix ownership and permissions of the key file

**Run on:** `ALL NODES`

```bash
chown mongod:mongod /data/mongodb/keyfile/mongo-keyfile
chmod 400 /data/mongodb/keyfile/mongo-keyfile
ls -l /data/mongodb/keyfile/
```

---

## STEP 12 - /etc/mongod.conf

**Run on:** `PER NODE`

Set MY_IP to THIS server's IP, then paste the WHOLE block at the shell prompt (not inside vi/nano). The first line (MY_IP=...) is a shell command, not part of the config file; if it ends up inside /etc/mongod.conf, mongod fails with: Error parsing INI config file: unrecognised option 'MY_IP'  
hqmngodb01 -> 10.10.21.30 hqmngodb02 -> 10.10.21.31 hqmngodb03 -> 10.10.21.32

```bash
MY_IP=10.10.21.30

[ -f /etc/mongod.conf.orig ] || cp -a /etc/mongod.conf /etc/mongod.conf.orig
cat > /etc/mongod.conf <<EOF
# mongod.conf  (MongoDB 8.3 - no "journal" section, it was removed in 7.0)

# where to write logging data
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
  logRotate: reopen

# where and how to store data
storage:
  dbPath: /data/mongodb/data

# how the process runs
processManagement:
  pidFilePath: /var/run/mongodb/mongod.pid
  timeZoneInfo: /usr/share/zoneinfo

# network interfaces (this node's IP + localhost; the firewall allows 27017)
net:
  port: 27017
  bindIp: 127.0.0.1,$MY_IP
  maxIncomingConnections: 1000

replication:
  replSetName: prd-rst
  oplogSizeMB: 1024

security:
  authorization: enabled
  keyFile: /data/mongodb/keyfile/mongo-keyfile
EOF
```

Check the file: bindIp must show this node's real IP, and the last command must print 0.

```bash
cat /etc/mongod.conf
grep -n 'bindIp' /etc/mongod.conf
grep -c 'MY_IP' /etc/mongod.conf
```

---

## STEP 13 - Allocator setting for MongoDB 8.x, then start MongoDB

**Run on:** `ALL NODES`

MongoDB 8.x uses per-CPU TCMalloc caches. On a system whose glibc registers rseq (OL10 does), the official TCMalloc page says to set GLIBC_TUNABLES=glibc.pthread.rseq=0 before mongod starts. Create a systemd drop-in so it is set on every start:

```bash
mkdir -p /etc/systemd/system/mongod.service.d
cat > /etc/systemd/system/mongod.service.d/override.conf <<'EOF'
[Service]
Environment="GLIBC_TUNABLES=glibc.pthread.rseq=0"
EOF
systemctl daemon-reload
```

Start MongoDB.

```bash
systemctl enable mongod
systemctl start mongod
systemctl status mongod --no-pager
tail -n 30 /var/log/mongodb/mongod.log
```

Do not continue until mongod is running on ALL three nodes. If mongod was ALREADY running before you created the drop-in, restart it ONE node at a time (secondaries first; on the primary run rs.stepDown(60) in mongosh first), then verify the variable:

```bash
systemctl restart mongod
tr '\0' '\n' < /proc/$(pidof mongod)/environ | grep GLIBC_TUNABLES
```

---

## STEP 14 - Initiate the replica set and create the root user

**Run on:** `hqmngodb01 ONLY`

Connect locally on hqmngodb01. The "localhost exception" lets you create the first user even though authorization is enabled.

```bash
mongosh --host localhost --port 27017
```

Initiate the replica set. The _id MUST equal replSetName in mongod.conf (prd-rst, lowercase). The tag dc:HQ marks the site of each member; the backup (STEP 17) uses it to read from HQ only, and the DR members get dc:DR in STEP 32.

**(mongosh)**

```javascript
rs.initiate({
  _id: "prd-rst",
  members: [
    { _id: 0, host: "hqmngodb01:27017", priority: 2, tags: { dc: "HQ" } },
    { _id: 1, host: "hqmngodb02:27017", priority: 1, tags: { dc: "HQ" } },
    { _id: 2, host: "hqmngodb03:27017", priority: 1, tags: { dc: "HQ" } }
  ]
})
```

Wait about 10 seconds: one PRIMARY and two SECONDARY should appear.

**(mongosh)**

```javascript
rs.status().members.map(m => [m.name, m.stateStr, m.health])
```

Create the root user on the PRIMARY (you are prompted for the password), then authenticate. "use admin" is needed because the root role lives in the admin database and db.auth checks the current database.

**(mongosh)**

```javascript
use admin
db.createUser({ user: "root", pwd: passwordPrompt(), roles: [ { role: "root", db: "admin" } ] })
db.auth("root", passwordPrompt())
```

---

## STEP 15 - Create the other users

**Run on:** `hqmngodb01 ONLY (mongosh, as root)`

Reconnect as root through the replica-set connection string (you are prompted for the password).

```bash
mongosh "mongodb://hqmngodb01:27017,hqmngodb02:27017,hqmngodb03:27017/?replicaSet=prd-rst&authSource=admin" --username root
```

Replace <APP> with your application name. Users that carry clusterMonitor must be created in the admin database.

**(mongosh)**

```javascript
use admin

db.createUser({ user: "clusterMonitor", pwd: passwordPrompt(), roles: [ { role: "clusterMonitor", db: "admin" } ] })

db.createUser({ user: "backupAdmin", pwd: passwordPrompt(), roles: [ { role: "backup", db: "admin" }, { role: "restore", db: "admin" } ] })

db.createUser({ user: "<APP>-admin", pwd: passwordPrompt(), roles: [ { role: "dbOwner", db: "<APP>DB" }, { role: "clusterMonitor", db: "admin" } ] })

db.createUser({ user: "<APP>-user", pwd: passwordPrompt(), roles: [ { role: "readWrite", db: "<APP>DB" }, { role: "clusterMonitor", db: "admin" } ] })
```

To list the users you created with their roles, see STEP 22.

---

## STEP 16 - Log rotation and shell aliases

**Run on:** `ALL NODES`

```bash
cat > /etc/logrotate.d/mongodb <<'EOF'
/var/log/mongodb/mongod.log {
size 100M
rotate 10
missingok
compress
delaycompress
notifempty
create 640 mongod mongod
sharedscripts
postrotate
/bin/kill -SIGUSR1 `cat /var/run/mongodb/mongod.pid 2>/dev/null` >/dev/null 2>&1
endscript
}
EOF
```

Test it (forces one rotation).

```bash
logrotate -v -f /etc/logrotate.d/mongodb
```

Aliases (no password stored - you are prompted). Usage: mongosh-root

```bash
cat >> ~/.bash_profile <<'EOF'

alias mongosh-root='mongosh --host $(hostname) --port=27017 --username=root --authenticationDatabase=admin'
alias mongostat-root='mongostat --host $(hostname) --port=27017 --username=root --authenticationDatabase=admin'
alias mongotop-root='mongotop --host $(hostname) --port=27017 --username=root --authenticationDatabase=admin 5'
EOF
source ~/.bash_profile
```

---

## STEP 17 - Backup and restore (mongodump / mongorestore)

**Run on:** `hqmngodb02 (backup node)`

Backups must go to SEPARATE storage - /data is only 9.9 GB. The script reads from a SECONDARY and keeps 7 days. Replace <BACKUP_PASSWORD> with the password of the backupAdmin user.

The URI prefers an HQ secondary (readPreferenceTags=dc:HQ), so once the DR site is added (STEP 32) the dump is never pulled across the WAN. The second, empty readPreferenceTags= is the fallback: any secondary, if no HQ secondary is available.

```bash
mkdir -p /backup
echo 'MNG_PWD="<BACKUP_PASSWORD>"' > /root/.mongo_backup.env
chmod 600 /root/.mongo_backup.env
```

```bash
cat > /usr/local/bin/mongo_backup.sh <<'EOF'
#!/bin/bash
# Full backup of the replica set from a secondary - keeps 7 days
source /root/.mongo_backup.env
BACKUP_DIR=/backup
STAMP=$(date +"%Y-%m-%d_%H-%M-%S")
URI="mongodb://hqmngodb01:27017,hqmngodb02:27017,hqmngodb03:27017/?replicaSet=prd-rst&readPreference=secondary&readPreferenceTags=dc:HQ&readPreferenceTags=&authSource=admin"

mongodump --uri="$URI" --username=backupAdmin --password="$MNG_PWD" --archive=$BACKUP_DIR/mongofullbackup_$STAMP.dump --gzip 2> $BACKUP_DIR/mongofullbackup_$STAMP.log

# keep the dump files for 7 days (change -mtime to keep more or less)
find $BACKUP_DIR -name 'mongofullbackup_*.dump' -mtime +7 -delete
find $BACKUP_DIR -name 'mongofullbackup_*.log' -mtime +7 -delete
EOF
chmod 700 /usr/local/bin/mongo_backup.sh
```

Run it once to test, then check the dump and log files.

```bash
/usr/local/bin/mongo_backup.sh
ls -lh /backup
```

Schedule it daily at 02:00.

```bash
( crontab -l 2>/dev/null; echo '0 2 * * * /usr/local/bin/mongo_backup.sh' ) | crontab -
```

### Restore examples (mongorestore)

```bash
export MNG_PWD='<BACKUP_PASSWORD>'
RS_URI="mongodb://hqmngodb01:27017,hqmngodb02:27017,hqmngodb03:27017/?replicaSet=prd-rst&authSource=admin"
```

Restore one database from the archive:

```bash
mongorestore --uri="$RS_URI" --username=backupAdmin --password="$MNG_PWD" --archive=/backup/<FileName>.dump --nsInclude='<DBNAME>.*' --gzip
```

Restore one database under a NEW name:

```bash
mongorestore --uri="$RS_URI" --username=backupAdmin --password="$MNG_PWD" --archive=/backup/<FileName>.dump --nsFrom='<OLDDB>.*' --nsTo='<NEWDB>.*' --nsInclude='<OLDDB>.*' --gzip
```

---

## STEP 18 - Validation

**Run on:** `any node (mongosh as root)`

Connect: mongosh-root (or the replica-set connection string from STEP 15).

Members, health and priorities. Expected (HQ only): 1 PRIMARY + 2 SECONDARY, health 1, priorities 2 / 1 / 1, votes 1 / 1 / 1. After the DR site is added (STEP 32): 1 PRIMARY + 5 SECONDARY, priorities 2 / 1 / 1 / 0 / 0 / 0, votes 1 / 1 / 1 / 1 / 1 / 0.

**(mongosh)**

```javascript
rs.status().members.map(m => [m.name, m.stateStr, m.health])
rs.conf().members.map(m => [m.host, m.priority, m.votes])
```

Replication lag and oplog (lag should be 0 to a few seconds).

**(mongosh)**

```javascript
rs.printSecondaryReplicationInfo()
rs.printReplicationInfo()
```

Allocator (expected: true) and startup warnings (expected: none).

**(mongosh)**

```javascript
db.serverStatus().tcmalloc.usingPerCPUCaches
db.adminCommand({ getLog: "startupWarnings" })
```

Version (expected 8.3.13 on every member).

**(mongosh)**

```javascript
db.version()
```

Shell checks on ALL NODES: disk, SELinux, THP.

```bash
df -h /data
getenforce
cat /sys/kernel/mm/transparent_hugepage/enabled
```

What a healthy rs.status() shows: ok: 1; set: prd-rst; one member with stateStr PRIMARY and two SECONDARY (five with the DR site); every member health: 1; votingMembersCount: 3, majorityVoteCount: 2, writeMajorityCount: 2 (with the DR site: 5, 3 and 3); the same configVersion on all members; optime values equal or within a few seconds; syncSourceHost of the secondaries pointing at the primary; empty infoMessage and lastHeartbeatMessage.

---

## STEP 19 - Failover, switchover and switch back

**Run on:** `see each block`

Terms: SWITCHOVER = planned, graceful change of primary (no data loss). FAILOVER = automatic election when the primary fails (takes about 10-12 seconds, the default election timeout is 10 s). During a primary change there is a short moment with no primary; applications using retryWrites=true reconnect automatically. After rs.stepDown() the shell prints a connection error - that is normal, mongosh reconnects.

### 19.1 Who is primary now? (run on any node; asks for the root password)

```bash
mongosh --host hqmngodb01 --port 27017 --username root --authenticationDatabase admin --eval 'rs.status().members.map(m => [m.name, m.stateStr])'
```

### 19.2 Planned SWITCHOVER from hqmngodb01 to hqmngodb02

Step 1 - on hqmngodb03: connect and freeze it, so it cannot be elected for 120 seconds.

```bash
mongosh --host hqmngodb03 --port 27017 --username root --authenticationDatabase admin
```

**(mongosh)**

```javascript
rs.freeze(120)
```

Step 2 - on hqmngodb01 (the current primary): connect and step down for 120 seconds. hqmngodb02 becomes the new primary.

```bash
mongosh --host hqmngodb01 --port 27017 --username root --authenticationDatabase admin
```

**(mongosh)**

```javascript
rs.stepDown(120)
```

Step 3 - verify on any node.

**(mongosh)**

```javascript
rs.status().members.map(m => [m.name, m.stateStr])
```

IMPORTANT: hqmngodb01 has priority 2, so once its 120 seconds are over and it has caught up, it automatically takes the primary role BACK. To keep hqmngodb02 primary longer (for example during maintenance on hqmngodb01), use a longer period in Step 2, for example rs.stepDown(3600) (one hour). Or change the priorities permanently - see 19.4.

### 19.3 SWITCH BACK to hqmngodb01

Option A - automatic: wait until the step-down period has expired; hqmngodb01 (priority 2) takes the primary role back by itself once it is in sync.

Option B - immediate: (1) on hqmngodb01 make it eligible again, (2) on hqmngodb03 freeze it, (3) on hqmngodb02 (the current primary) step down.

```bash
mongosh --host hqmngodb01 --port 27017 --username root --authenticationDatabase admin
```

**(mongosh)**

```javascript
rs.freeze(0)
```

```bash
mongosh --host hqmngodb03 --port 27017 --username root --authenticationDatabase admin
```

**(mongosh)**

```javascript
rs.freeze(120)
```

```bash
mongosh --host hqmngodb02 --port 27017 --username root --authenticationDatabase admin
```

**(mongosh)**

```javascript
rs.stepDown(120)
```

Verify: hqmngodb01 must be PRIMARY.

**(mongosh)**

```javascript
rs.status().members.map(m => [m.name, m.stateStr])
```

### 19.4 Permanent preferred primary (change priorities)

Run on the PRIMARY. Example: make hqmngodb02 the preferred primary. The current primary steps down by itself when it no longer has the highest priority. To restore the original order, set 2 / 1 / 1 again.

**(mongosh)**

```javascript
cfg = rs.conf()
cfg.members[0].priority = 1
cfg.members[1].priority = 2
cfg.members[2].priority = 1
rs.reconfig(cfg)
```

### 19.5 Unplanned FAILOVER test (before go-live)

On the current primary (for example hqmngodb01) stop MongoDB:

```bash
systemctl stop mongod
```

On another node check that a new primary was elected within about 10-12 seconds and that writes work.

```bash
mongosh --host hqmngodb02 --port 27017 --username root --authenticationDatabase admin --eval 'rs.status().members.map(m => [m.name, m.stateStr, m.health])'
```

Start MongoDB again on the stopped node. It rejoins as SECONDARY, catches up, and (priority 2) takes the primary role back, which causes one more short primary change.

```bash
systemctl start mongod
```

---

## STEP 20 - Remove and add a node

**Run on:** `see each block`

### 20.1 Remove a node (example: hqmngodb03)

Run on the PRIMARY. If the node to remove is the primary, step it down first (STEP 19). WARNING: with only 2 members left, a majority is 2 of 2 - if either member fails the set has no primary. Remove a node only temporarily or when you are adding another.

**(mongosh)**

```javascript
rs.remove("hqmngodb03:27017")
rs.conf().members.map(m => [m._id, m.host])
```

On the REMOVED node: stop MongoDB.

```bash
systemctl stop mongod
```

If you will add this node back later, wipe its data first so it does a clean initial sync. DESTRUCTIVE - run only on the REMOVED node, never on a member of the set.

```bash
rm -rf /data/mongodb/data/*
```

### 20.2 Add a node (a new hqmngodb04, or hqmngodb03 again)

Prepare the new node first: STEP 1-9 and STEP 11-13 (same OS settings, the SAME MongoDB version, the same mongod.conf with replSetName prd-rst and its own bindIp), the identical key file copied from an existing node, and port 27017 open. Add the new name and IP to /etc/hosts on ALL nodes. Example for a new node (replace the IP):

```bash
echo "10.10.21.33     hqmngodb04" >> /etc/hosts
scp /data/mongodb/keyfile/mongo-keyfile root@hqmngodb04:/data/mongodb/keyfile/mongo-keyfile
```

Start MongoDB on the new node with an EMPTY data directory (systemctl start mongod). Do NOT run rs.initiate on it. Then, on the PRIMARY, add it:

**(mongosh)**

```javascript
rs.add({ host: "hqmngodb04:27017", priority: 1, votes: 1 })
```

Watch the initial sync: the new member goes STARTUP2 -> SECONDARY. The time depends on the data size.

**(mongosh)**

```javascript
rs.status().members.map(m => [m.name, m.stateStr, m.health])
```

Voting: a 4th VOTING member does not add fault tolerance (4 voters still tolerate only 1 failure). Add even-numbered members as non-voting, or add two at once to reach 5 voters. Non-voting example:

**(mongosh)**

```javascript
rs.add({ host: "hqmngodb04:27017", priority: 0, votes: 0 })
```

---

## STEP 21 - Check voting, priority and majority

**Run on:** `any node (mongosh as root)`

Votes, priority and member type of every node (from the configuration):

**(mongosh)**

```javascript
rs.conf().members.map(m => ({ _id: m._id, host: m.host, votes: m.votes, priority: m.priority, arbiterOnly: m.arbiterOnly, hidden: m.hidden, secondaryDelaySecs: m.secondaryDelaySecs }))
```

Voting counts as the replica set sees them right now:

**(mongosh)**

```javascript
(() => { const s = rs.status(); return { set: s.set, votingMembersCount: s.votingMembersCount, writableVotingMembersCount: s.writableVotingMembersCount, majorityVoteCount: s.majorityVoteCount, writeMajorityCount: s.writeMajorityCount }; })()
```

Primary, hosts and this node's role:

**(mongosh)**

```javascript
db.hello()
```

Rule: majority = floor(voters / 2) + 1. 3 voters -> majority 2 -> tolerates 1 failure. 4 voters -> majority 3 -> tolerates 1. 5 voters -> majority 3 -> tolerates 2. A replica set can have at most 7 voting members. Keep the number of voters ODD.

Change votes or priority of a member (run on the PRIMARY). Example: make the 3rd member non-voting (a non-voting member must have priority 0):

**(mongosh)**

```javascript
cfg = rs.conf()
cfg.members[2].votes = 0
cfg.members[2].priority = 0
rs.reconfig(cfg)
```

---

## STEP 22 - List the users and their roles

**Run on:** `any node (mongosh as root)`

All users of ALL databases, one readable line each (user@database -> role@database):

**(mongosh)**

```javascript
db.getSiblingDB("admin").runCommand({ usersInfo: { forAllDBs: true } }).users.map(u => `${u.user}@${u.db} -> ${u.roles.map(r => `${r.role}@${r.db}`).join(", ")}`)
```

Same list as full documents:

**(mongosh)**

```javascript
db.getSiblingDB("admin").runCommand({ usersInfo: { forAllDBs: true } }).users.map(u => ({ user: u.user, db: u.db, roles: u.roles }))
```

Only the users defined in the admin database, and one user in detail:

**(mongosh)**

```javascript
use admin
db.getUsers()
db.getUser("root")
```

Other user administration (run in the admin database; replace <USER> and <DB>):

**(mongosh)**

```javascript
use admin
db.changeUserPassword("<USER>", passwordPrompt())
db.grantRolesToUser("<USER>", [ { role: "readWrite", db: "<DB>" } ])
db.revokeRolesFromUser("<USER>", [ { role: "readWrite", db: "<DB>" } ])
db.dropUser("<USER>")
```

---

## STEP 23 - Application connection string

**Run on:** `applications`

```bash
mongodb://<APP>-user:<PASSWORD>@hqmngodb01:27017,hqmngodb02:27017,hqmngodb03:27017/<APP>DB?authSource=admin&replicaSet=prd-rst&w=majority&retryWrites=true
```

The replica set name is case-sensitive: replicaSet=prd-rst.

With the DR site (STEP 32), list the DR nodes in the seed list too. The driver always writes to the primary wherever it is, so the same string keeps working after a DR activation (STEP 32.11) without changing the application:

```bash
mongodb://<APP>-user:<PASSWORD>@hqmngodb01:27017,hqmngodb02:27017,hqmngodb03:27017,drmngodb01:27017,drmngodb02:27017,drmngodb03:27017/<APP>DB?authSource=admin&replicaSet=prd-rst&w=majority&retryWrites=true
```

If the application reads from secondaries, add readPreferenceTags=dc:HQ so normal reads stay at HQ and do not cross the WAN.

---

## STEP 24 - Day-2 commands

**Run on:** `any node`

```bash
systemctl status mongod --no-pager
journalctl -u mongod -n 100 --no-pager
tail -f /var/log/mongodb/mongod.log
rpm -qa | grep -i mongo
```

Patching: upgrade the DR nodes and the HQ secondaries first, then rs.stepDown(60) on the primary and upgrade it; keep all nodes (HQ and DR) on the same version (details in STEP 31). Raise the feature compatibility version only after ALL members are upgraded and validated.

---

## STEP 25 - Ops Manager server - plan, VM specs and OS preparation

**Run on:** `hqmngoom01 ONLY`

Ops Manager (OM) here is for MONITORING AND ALERTING ONLY (no backup, no automation). OM and its Application Database run on the SAME server, hqmngoom01. Read "Version and support validation" at the top first.

### 25.1 VM specification (from the OM 9.0 requirements page, backup disabled)

CPU: 8 vCPU (OM needs 4+, Application Database needs 4 - same server, so add them)  
RAM: 32 GB (OM about 15 GB + Application Database: 8 GB + what mongod uses)  
Disk 1 (OS, /opt, /tmp): 60 GB or more - /opt needs 10 GB, /tmp needs 20 GiB free  
Disk 2 (XFS, mounted on /data, SSD): 200 GB - Application Database, independent volume  
Disk 3 or LVM volume for logs: 30-50 GB (OM logs about 30 GB per month)  
OS: RHEL 10 (fully listed) or Oracle Linux 10.2 on RHCK. CPU must expose AVX.  
Network: hqmngoom01 -> DB nodes on 27017; DB nodes -> hqmngoom01 on 8080.

### 25.2 Checks

```bash
uname -r
grep -m1 -o avx /proc/cpuinfo
df -hT /data
findmnt /data
```

Expected: kernel name has no "uek" and is not between 6.19 and 7.0.13; the avx command prints avx; /data is XFS (add noatime in /etc/fstab, see STEP 1).

### 25.3 Hostname, hosts and time

```bash
hostnamectl set-hostname hqmngoom01
for e in "10.10.21.30     hqmngodb01" "10.10.21.31     hqmngodb02" "10.10.21.32     hqmngodb03" \
         "10.10.22.30     drmngodb01" "10.10.22.31     drmngodb02" "10.10.22.32     drmngodb03" \
         "10.10.21.40     hqmngoom01"; do
  grep -qw "${e##* }" /etc/hosts || echo "$e" >> /etc/hosts
done
getent hosts hqmngoom01
systemctl enable --now chronyd
chronyc tracking
```

getent must return the server's real IP, not 127.0.0.1 or 127.0.1.1. Also add the line 10.10.21.40 hqmngoom01 to /etc/hosts on every DB node (hqmngodb01-03 and drmngodb01-03), and use a lowercase name.

### 25.4 SELinux and firewall (OM web port 8080 only)

```bash
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
grep '^SELINUX=' /etc/selinux/config
setenforce 0
systemctl enable --now firewalld
for z in $(firewall-cmd --get-active-zones | grep -v '^ '); do firewall-cmd --permanent --zone=$z --add-port=8080/tcp; done
firewall-cmd --reload
firewall-cmd --list-all-zones | grep -E '^[a-z]|ports:'
```

Port 27017 is NOT opened on this server: the Application Database is used only by OM on the same server. Port 8443 is not used (no TLS).

### 25.5 Kernel tuning, THP and limits

```bash
cat > /etc/sysctl.d/99-mongodb.conf <<'EOF'
vm.swappiness = 1
vm.overcommit_memory = 1
vm.max_map_count = 262144
net.ipv4.tcp_keepalive_time = 120
EOF
sysctl --system

cat > /etc/systemd/system/mongodb-thp.service <<'EOF'
[Unit]
Description=MongoDB Transparent Huge Page settings
DefaultDependencies=no
After=sysinit.target local-fs.target
Before=mongod.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo always > /sys/kernel/mm/transparent_hugepage/enabled; echo defer+madvise > /sys/kernel/mm/transparent_hugepage/defrag; echo 0 > /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none'
RemainAfterExit=yes

[Install]
WantedBy=basic.target
EOF
systemctl daemon-reload
systemctl enable --now mongodb-thp.service

cat > /etc/security/limits.d/99-mongodb-nproc.conf <<'EOF'
mongod          soft    nofile    64000
mongod          hard    nofile    64000
mongod          soft    nproc     64000
mongod          hard    nproc     64000
mongodb-mms     soft    nproc     200000
mongodb-mms     hard    nproc     500000
EOF
```

The THP values follow the 8.x guidance used for the replica set. I did not find separate 9.0 guidance; check startup warnings after the first start (STEP 26).

### 25.6 Packages, then reboot

```bash
dnf install -y cyrus-sasl cyrus-sasl-gssapi cyrus-sasl-plain krb5-libs libcurl openldap openssl xz-libs chrony firewalld policycoreutils lsof sysstat numactl tuned xfsprogs initscripts
bash --version | head -1
reboot
```

OM needs Bash 4.2 or later (OL 10 has it) and the initscripts package. After the reboot: getenforce must print Disabled.

```bash
getenforce
cat /sys/kernel/mm/transparent_hugepage/enabled
```

---

## STEP 26 - Ops Manager Application Database - MongoDB 9.0 (same server)

**Run on:** `hqmngoom01 ONLY`

MongoDB 9.0 is the only supported Application Database version available for el10 (see validation). It is a DEDICATED mongod: nothing else may be stored in it. Do not use the 8.3 repo here: 8.2/8.3 are not supported as backing databases.

### 26.1 Repository and install (online method)

```bash
rm -f /etc/yum.repos.d/mongodb-enterprise-8.0.repo /etc/yum.repos.d/mongodb-enterprise-8.3.repo
cat > /etc/yum.repos.d/mongodb-enterprise-9.0.repo <<'EOF'
[mongodb-enterprise-9.0]
name=MongoDB Enterprise Repository
baseurl=https://repo.mongodb.com/yum/redhat/10/mongodb-enterprise/9.0/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-9.asc
EOF
dnf clean all
dnf makecache
dnf list --showduplicates mongodb-enterprise-server
```

The GPG key for 9.0 is server-9.asc. Pick the newest 9.0.x patch shown by the last command (a major release and its patches only - never a rapid/minor release for the Application Database), then install it. Replace 9.0.X with the real number:

```bash
dnf install -y mongodb-enterprise-server-9.0.X mongodb-enterprise-database-9.0.X mongodb-enterprise-tools-9.0.X mongodb-enterprise-mongos-9.0.X mongodb-enterprise-database-tools-extra-9.0.X
mongod --version
rpm -qa | grep -i mongo
```

Air-gapped: download the same RPMs on a staging host with dnf download --resolve --alldeps (as in STEP 7), copy them to /opt/stage and install with dnf from a local repo (as in STEP 8A). Prevent accidental upgrades:

```bash
echo 'exclude=mongodb-enterprise,mongodb-enterprise-database,mongodb-enterprise-server,mongodb-enterprise-shell,mongodb-enterprise-mongos,mongodb-enterprise-tools' >> /etc/dnf/dnf.conf
```

### 26.2 Directories and key file

A replica set with authentication needs a key file, even with one member.

```bash
mkdir -p /data/mmsappdb/{data,keyfile}
mkdir -p /var/log/mongodb
openssl rand -base64 741 > /data/mmsappdb/keyfile/keyfile
chmod 400 /data/mmsappdb/keyfile/keyfile
chown -R mongod:mongod /data/mmsappdb /var/log/mongodb
chmod 750 /data/mmsappdb/data
ls -l /data/mmsappdb/keyfile/
```

### 26.3 Allocator setting

Kept from the 8.x procedure (STEP 13). I did not find a 9.0 statement either way: keep it and check the result in 26.6.

```bash
mkdir -p /etc/systemd/system/mongod.service.d
cat > /etc/systemd/system/mongod.service.d/override.conf <<'EOF'
[Service]
Environment="GLIBC_TUNABLES=glibc.pthread.rseq=0"
EOF
systemctl daemon-reload
```

### 26.4 /etc/mongod.conf

Set MY_IP to the IP of hqmngoom01, then paste the WHOLE block at the shell prompt (not in vi/nano). The database listens on localhost and the server's own IP so the member name hqmngoom01:27017 works now and when members are added later. Port 27017 stays closed in the firewall.

```bash
MY_IP=10.10.21.40

[ -f /etc/mongod.conf.orig ] || cp -a /etc/mongod.conf /etc/mongod.conf.orig
cat > /etc/mongod.conf <<EOF
# Ops Manager Application Database (MongoDB 9.0) - dedicated, single-node replica set
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
  logRotate: reopen

storage:
  dbPath: /data/mmsappdb/data

processManagement:
  pidFilePath: /var/run/mongodb/mongod.pid
  timeZoneInfo: /usr/share/zoneinfo

net:
  port: 27017
  bindIp: 127.0.0.1,$MY_IP

replication:
  replSetName: mmsappdb

security:
  authorization: enabled
  keyFile: /data/mmsappdb/keyfile/keyfile
EOF
grep -n 'bindIp' /etc/mongod.conf
grep -c 'MY_IP' /etc/mongod.conf
```

The last command must print 0.

### 26.5 Start MongoDB

```bash
systemctl enable --now mongod
systemctl status mongod --no-pager
tail -n 30 /var/log/mongodb/mongod.log
```

### 26.6 Initiate the replica set and create the Ops Manager user

The localhost exception allows rs.initiate and the first user while authorization is on. The member name MUST resolve to this server.

```bash
mongosh --host localhost --port 27017
```

**(mongosh)**

```javascript
rs.initiate({ _id: "mmsappdb", members: [ { _id: 0, host: "hqmngoom01:27017" } ] })
```

Wait about 10 seconds until it shows PRIMARY, then create the user. These are the roles the docs list for a non-sharded Application Database. Use a password with letters and digits only, because it goes into a connection string.

**(mongosh)**

```javascript
use admin
db.createUser({ user: "mmsAppDbUser", pwd: passwordPrompt(), roles: [ { role: "readWriteAnyDatabase", db: "admin" }, { role: "dbAdminAnyDatabase", db: "admin" }, { role: "clusterMonitor", db: "admin" } ] })
db.auth("mmsAppDbUser", passwordPrompt())
rs.status().members.map(m => [m.name, m.stateStr])
db.version()
db.serverStatus().tcmalloc.usingPerCPUCaches
db.adminCommand({ getLog: "startupWarnings" })
```

Expected: hqmngoom01:27017 PRIMARY, the 9.0.x version, and no startup warnings. Do NOT start mongod with --notablescan. Keep the Application Database on its own volume: if it cannot write, OM stops.

---

## STEP 27 - Install Ops Manager 9.0.1 and connect it to the Application Database

**Run on:** `hqmngoom01 ONLY`

Download mongodb-mms-9.0.1-<build>.x86_64.rpm from the MongoDB Download Center (Ops Manager, RPM) on an internet-connected PC and copy it to /opt/stage on hqmngoom01. The upgrade page I read still lists RHEL 8 and 9 as download platforms; OM 9.0.0 release notes add RHEL 10, so check that the download is offered for RHEL 10 / the 9.0.1 RPM installs cleanly. Check the file integrity as described on MongoDB's "Verify Integrity of Ops Manager Packages" page.

```bash
ls -l /opt/stage/mongodb-mms-*.rpm
rpm -ivh /opt/stage/mongodb-mms-9.0.1*.x86_64.rpm
id mongodb-mms
ls /opt/mongodb/mms/
```

The install creates /opt/mongodb/mms, the user mongodb-mms, /opt/mongodb/mms/conf/conf-mms.properties and /etc/mongodb-mms/gen.key. Do not create these folders yourself.

### 27.1 Back up the configuration and encryption key NOW

gen.key encrypts the Application Database content. If you lose it, the data cannot be read. Store a copy OFF this server (a safe share or vault).

```bash
mkdir -p /root/om-backup
cp -a /etc/mongodb-mms/gen.key /root/om-backup/gen.key
cp -a /opt/mongodb/mms/conf/conf-mms.properties /root/om-backup/conf-mms.properties.orig
chmod 600 /root/om-backup/*
ls -l /root/om-backup
```

### 27.2 Set the Application Database connection string

This prompts for the password (hidden), writes the connection string, and shows the line with the password masked. The password must contain only letters and digits.

```bash
read -rsp "Application DB password for mmsAppDbUser: " APPDB_PWD; echo
sed -i "s|^mongo.mongoUri=.*|mongo.mongoUri=mongodb://mmsAppDbUser:${APPDB_PWD}@hqmngoom01:27017/?replicaSet=mmsappdb\&authSource=admin|" /opt/mongodb/mms/conf/conf-mms.properties
unset APPDB_PWD
grep -n '^mongo.mongoUri' /opt/mongodb/mms/conf/conf-mms.properties | sed 's/:[^:@/]*@/:****@/'
```

The grep must show exactly one mongo.mongoUri line with replicaSet=mmsappdb. If it shows nothing, edit /opt/mongodb/mms/conf/conf-mms.properties and add the line by hand (mongo.mongoUri=mongodb://mmsAppDbUser:<PASSWORD>@hqmngoom01:27017/?replicaSet=mmsappdb&authSource=admin).

### 27.3 Start Ops Manager

```bash
service mongodb-mms start
tail -f /opt/mongodb/mms/logs/mms0.log
```

Press Ctrl+C once the log shows the server has started (the first start can take a few minutes). Then verify the listener:

```bash
ss -tlnp | grep -E ':(8080|8443)\b'
systemctl is-enabled mongod
systemctl is-enabled mongodb-mms
```

Expected: a java process on 8080 and nothing on 8443 (HTTPS is not configured). Port 9090 on this server, owned by systemd, is the Cockpit console and is not Ops Manager; to remove it use: systemctl disable --now cockpit.socket

---

## STEP 28 - Ops Manager first login and configuration wizard

**Run on:** `browser`

Open http://hqmngoom01:8080 from an admin PC (add the host name to that PC's hosts file or use the IP). Then:

1. Click Sign Up and create the first user. This user becomes Global Owner. Use a strong password and keep it in your vault.
2. Complete the configuration wizard. Required fields are marked with an asterisk.
3. URL to Access Ops Manager: http://hqmngoom01:8080
4. Email: set the SMTP server, sender and recipients, and send a test email. Alerts are delivered by email, so this must work.
5. Do not enable Backup. Do not enable Automation for this deployment.
6. Air-gapped (no internet): the wizard offers MongoDB Version Management / Local Mode. For monitoring only no MongoDB binaries are needed. If the wizard insists on a Versions Directory, set it to the default and leave it empty.
7. When finished, the Deployment page opens.

Create a project for the cluster, for example PRD-MONGODB (Organization > Projects). Replica set names must be unique within a project.

---

## STEP 29 - Connect the prd-rst replica set to Ops Manager (monitoring only)

**Run on:** `see each block`

### 29.1 Create the monitoring user on prd-rst

Run on the PRIMARY of prd-rst, as root (mongosh). The password is prompted.

**(mongosh)**

```javascript
use admin
db.createUser({ user: "omMonitor", pwd: passwordPrompt(), roles: [ { role: "clusterMonitor", db: "admin" } ] })
```

MongoDB's page "Required Access for MongoDB Agent for Monitoring" is the authority for the exact roles; check it, because newer agents can need additional read access.

### 29.2 Network check

```bash
nc -zv hqmngodb01 27017
nc -zv hqmngodb02 27017
nc -zv hqmngodb03 27017
nc -zv hqmngoom01 8080
```

Run the first three on hqmngoom01 and the last one on each DB node (nc comes from the nmap-ncat package). 27017 is already open on the DB nodes (STEP 4); 8080 is open on hqmngoom01 (STEP 25).

### 29.3 Add the deployment in the Ops Manager UI

1. Open the project > Deployment > Add > Existing MongoDB Deployment.
2. Choose Monitoring only (not Monitoring and Automation).
3. The wizard shows the MongoDB Agent download link and install commands, served from Ops Manager. Run them as root on each of hqmngodb01, 02, 03 (or on one host that can reach all three). The agent runs as its own service.
4. Select the replica set prd-rst and finish the wizard.
5. Open the deployment menu > Monitoring Settings > Credentials. Enter authentication mechanism SCRAM-SHA, user omMonitor, and its password. Save.

The agent is on RHEL/Oracle Linux 10 (listed as supported). The agent version shipped with OM 9.0.1 is 109.0.1; whether it formally supports MongoDB 8.3.13 is the inference noted at the top.

### 29.4 Log rotation (important)

The OM docs say OM turns on its own log rotation for deployments it monitors and tells you to remove systemLog.logRotate and systemLog.logAppend from mongod.conf and to disable your own log rotation. Do this rolling, ONE node at a time (secondaries first, then rs.stepDown(60) on the primary), and only after the node shows in OM. On each DB node:

```bash
cp -a /etc/mongod.conf /etc/mongod.conf.beforeOM
sed -i '/^  logRotate: reopen$/d;/^  logAppend: true$/d' /etc/mongod.conf
rm -f /etc/logrotate.d/mongodb
grep -n -A4 '^systemLog' /etc/mongod.conf
systemctl restart mongod
```

Check rs.status() shows the node back as SECONDARY and caught up before the next node. Keep the file backup until all three are done.

### 29.5 Verify

In OM the deployment shows prd-rst with 1 PRIMARY and 2 SECONDARY and charts start to fill within a few minutes. If a host shows grey or stale: check the agent log (/var/log/mongodb-mms-automation/ on the DB node), port 8080 reachability, and the omMonitor credentials.

---

## STEP 30 - Alerts (email) for monitoring

**Run on:** `browser`

Project > Alerts > Alert Settings. Edit or add alerts and set the notification to Email with your DBA group address. Recommended minimum:

- Host is down / host has restarted
- Replica set has no primary
- Replica set elected a new primary
- Replication lag is high (for example above 60 seconds for 5 minutes)
- Oplog window is short
- Connections above 80 percent of the limit
- Disk used on /data above 70 percent warning, 85 percent critical (the volume is only 9.9 GB)
- Memory and CPU high  
    The default alerts that exist after the wizard can be kept; just add the email recipient to each.

Test an alert: stop mongod on ONE secondary for two minutes, confirm the email arrives and the alert closes after you start it again. Never test on the primary.

```bash
systemctl stop mongod
sleep 120
systemctl start mongod
```

Monitor Ops Manager itself: if hqmngoom01 is down, alerts stop. Add an external check (ping/port 8080) to your existing monitoring tool, and back up gen.key and conf-mms.properties after every change.

---

## STEP 31 - Patching - OS, MongoDB, Ops Manager and its database

**Run on:** `see each block`

RULES

1. Patch in a maintenance window, one server at a time.
2. Never patch the primary first: DR nodes first, then the HQ secondaries, then rs.stepDown(60), then the old primary.
3. All replica-set nodes (HQ and DR) must end on the SAME MongoDB version.
4. Keep Oracle Linux on RHCK; never let UEK become the default kernel.
5. Take a backup before you start (STEP 17) and confirm the set is healthy before AND after each node.
6. MongoDB and Ops Manager packages are excluded in /etc/dnf/dnf.conf, so a normal dnf update never upgrades them by accident.

### 31.1 Health check before and after every node (mongosh as root)

**(mongosh)**

```javascript
rs.status().members.map(m => [m.name, m.stateStr, m.health])
rs.printSecondaryReplicationInfo()
db.version()
```

Proceed only if: 1 PRIMARY + 2 SECONDARY (+ 3 DR SECONDARY with the DR site), health 1 everywhere, lag a few seconds at most (DR lag can be higher over the WAN, but must be steady and small).

### 31.2 OS patching - replica set nodes (RHCK kernel)

Order: drmngodb03, drmngodb02, drmngodb01 (DR nodes have priority 0 and never become primary), then hqmngodb03, then hqmngodb02, then hqmngodb01 (step it down first). Patch only ONE voting member at a time: with 5 voters the set tolerates 2 failures, but a DR node down during an HQ outage leaves fewer spares. On the node being patched:

```bash
dnf check-update
dnf update -y
grubby --default-kernel
dnf needs-restarting -r
```

grubby must show a kernel path WITHOUT uek. If a UEK kernel became the default, set an RHCK one with grubby --set-default <path of the vmlinuz that is not uek>. Reboot if needs-restarting asks for it (MongoDB starts by itself):

```bash
reboot
```

After the node is back: systemctl status mongod, then the health check in 31.1 until it is SECONDARY and caught up. For the PRIMARY node, connect to it first and step down, wait for a new primary, then patch it exactly as above:

**(mongosh)**

```javascript
rs.stepDown(60)
```

hqmngodb01 has priority 2, so it takes the primary role back by itself after it rejoins. Check kernel and THP after each reboot:

```bash
uname -r
getenforce
cat /sys/kernel/mm/transparent_hugepage/enabled
```

### 31.3 MongoDB patch release on the replica set (for example 8.3.13 to a newer 8.3.x)

This is for PATCH releases inside the same version line. Moving to a different line (8.4, 9.0) is an upgrade with its own procedure (feature compatibility version, compatibility check with Ops Manager) and is not covered here. 8.3 is a rapid release: check MongoDB's support policy for how long 8.3.x gets patches, and read the release notes of the target patch first. Pin the exact version on every node (replace 8.3.NN):

```bash
dnf list --showduplicates --disableexcludes=main mongodb-enterprise-server
dnf upgrade -y --disableexcludes=main mongodb-enterprise-server-8.3.NN mongodb-enterprise-database-8.3.NN mongodb-enterprise-mongos-8.3.NN mongodb-enterprise-tools-8.3.NN mongodb-enterprise-database-tools-extra-8.3.NN
systemctl restart mongod
mongod --version
```

Do it secondary by secondary in the order of 31.2 (DR nodes, HQ secondaries); the primary last after rs.stepDown(60). After each node run 31.1. At the end all nodes must report the same db.version() and the feature compatibility version must be unchanged:

**(mongosh)**

```javascript
db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })
```

### 31.4 Ops Manager server - OS patching (hqmngoom01)

There is one OM server, so monitoring and alerting stop during the window. Tell the team first. Stop OM, then the database, patch, reboot, and start in the right order.

```bash
service mongodb-mms stop
systemctl stop mongod
dnf update -y
grubby --default-kernel
dnf needs-restarting -r
reboot
```

After the reboot, start the database first, then OM (if they did not start by themselves), and check:

```bash
systemctl start mongod
sleep 15
service mongodb-mms start
ss -tlnp | grep ':8080'
tail -n 30 /opt/mongodb/mms/logs/mms0.log
```

Then log in at http://hqmngoom01:8080 and confirm prd-rst is green again.

### 31.5 Application Database patch release (MongoDB 9.0.x)

Stay inside 9.0 (major release and its patches only; never 8.2/8.3 or a rapid release). Back up first (31.6), stop OM, upgrade, start the database, start OM. Replace 9.0.NN:

```bash
service mongodb-mms stop
dnf list --showduplicates --disableexcludes=main mongodb-enterprise-server
dnf upgrade -y --disableexcludes=main mongodb-enterprise-server-9.0.NN mongodb-enterprise-database-9.0.NN mongodb-enterprise-mongos-9.0.NN mongodb-enterprise-tools-9.0.NN mongodb-enterprise-database-tools-extra-9.0.NN
systemctl restart mongod
mongod --version
service mongodb-mms start
```

The Application Database version may never be newer than the Ops Manager version.

### 31.6 Back up OM before any OM or database change

MongoDB states there is no officially supported backup method for the Application Database; mongodump is an extra precaution. gen.key and conf-mms.properties are the critical files because OM may delete them during an upgrade. Write the dump to separate storage (the password is prompted):

```bash
BK=/backup/om-$(date +%F)
mkdir -p $BK
cp -a /etc/mongodb-mms/gen.key $BK/
cp -a /opt/mongodb/mms/conf/conf-mms.properties $BK/
mongodump --host hqmngoom01 --port 27017 --username mmsAppDbUser --authenticationDatabase admin --out=$BK/appdb
ls -l $BK
```

### 31.7 Ops Manager upgrade (9.0.x to a newer 9.0.x, or later to a new major)

Rules from the OM upgrade page: follow the documented upgrade path; upgrade to the latest patch of your current line first, then the next major; do not skip majors; there is NO supported downgrade, so back up first (31.6). Download the new RPM and copy it to /opt/stage, then:

```bash
service mongodb-mms stop
rpm -Uvh /opt/stage/mongodb-mms-<NEW-VERSION>.x86_64.rpm
ls -l /opt/mongodb/mms/conf/
service mongodb-mms start
tail -n 50 /opt/mongodb/mms/logs/mms0.log
```

Since OM 5.0 an RPM upgrade keeps your conf-mms.properties and saves the new default as conf-mms.properties.rpmnew. If a new version needs new properties, add them by hand. If you changed ports or JVM options in mms.conf, re-apply them. Confirm gen.key still exists in /etc/mongodb-mms/; if it is missing, restore it from the backup BEFORE starting OM. Log in to confirm. A successful login means the upgrade worked.

### 31.8 Update the MongoDB Agents on the DB nodes

After an OM upgrade the UI shows the banner "One or more agents are out of date". Click Update Software Components and confirm. If you ever upgraded the agent hosts' OS, update the agents BEFORE upgrading OM.

### 31.9 After patching - checklist

```bash
uname -r
getenforce
systemctl is-active mongod
df -h /data
firewall-cmd --list-ports
tail -n 20 /var/log/mongodb/mongod.log
```

Run on every server (HQ, DR and hqmngoom01). Then confirm in mongosh: 1 PRIMARY + 2 SECONDARY (+ 3 DR SECONDARY), equal versions, no lag; in OM: all hosts green, no open alerts, test email works.

---

## STEP 32 - Add the DR site (drmngodb01-03) to prd-rst

**Run on:** `see each block`

The DR site joins the SAME replica set prd-rst as three more members. Data replicates from HQ to DR continuously over the WAN; nothing else (no second replica set, no extra tool) is needed.

Design:

```
Member       Site  _id  priority  votes  role
hqmngodb01   HQ    0    2         1      preferred primary
hqmngodb02   HQ    1    1         1      secondary
hqmngodb03   HQ    2    1         1      secondary
drmngodb01   DR    3    0         1      DR secondary - never primary automatically
drmngodb02   DR    4    0         1      DR secondary - never primary automatically
drmngodb03   DR    5    0         0      DR secondary - non-voting

Voting members: 5 (odd) -> majority 3. HQ alone holds 3 votes.
```

Why this design:

1. HQ keeps the majority (3 of 5 votes). If the DR site or the WAN link fails, HQ keeps its primary and the applications notice nothing.
2. priority 0 on DR: a DR node never becomes primary automatically, so the applications never end up writing across the WAN by accident. Making DR primary is a decision you take (32.10 and 32.11).
3. Two DR votes: the set survives the loss of ANY 2 members. Example: 2 HQ nodes down -> 1 HQ + 2 DR = 3 votes -> the remaining HQ node is still elected primary.
4. drmngodb03 is non-voting because the number of voters must stay odd: 6 voters need a majority of 4 and tolerate no more failures than 5 voters.
5. If the WHOLE HQ site is lost, DR has only 2 of 5 votes, so there is NO automatic primary at DR. You activate DR with a forced reconfiguration (32.11). This is the price of never having a split-brain.

Write concern: with 5 voters writeMajorityCount is 3. While all three HQ nodes are up, w:majority is satisfied by HQ alone and DR adds no write latency. If one HQ node is down, every majority write waits for a DR node, so its latency includes the WAN round-trip.

Recovery point: because HQ alone is a majority, a write acknowledged with w:majority can exist only at HQ. If HQ is lost, everything not yet replicated to DR is lost: the RPO equals the DR replication lag. Keep the replication-lag alert (STEP 30) active for the DR nodes.

### 32.1 Prerequisites and checks

1. Network: 27017/tcp open in BOTH directions between every HQ node and every DR node (members of a replica set all talk to each other), and DR nodes -> hqmngoom01:8080 for the MongoDB Agent. STEP 4 opens 27017 inbound on every node; any firewall between the sites must allow it too.
2. Name resolution: every node resolves every member (STEP 2 already contains the DR names; on a set built before, run the STEP 2 hosts loop again on every HQ node and on hqmngoom01 - it adds only the missing lines).
3. Same OS settings and the SAME MongoDB version (8.3.13) as HQ.
4. Oplog window: the initial sync of a DR node over the WAN, and any later WAN outage, must fit inside the oplog window, otherwise the DR node falls off the oplog and needs a full resync. Check it on the PRIMARY:

**(mongosh)**

```javascript
rs.printReplicationInfo()
```

"log length start to end" is the oplog window. It must be longer than the expected initial sync time PLUS the longest WAN outage you want to survive without a resync. If it is too short, enlarge the oplog (32.2).

Network check from each HQ node to each DR node and back (nc comes from the nmap-ncat package):

```bash
for n in hqmngodb01 hqmngodb02 hqmngodb03 drmngodb01 drmngodb02 drmngodb03; do nc -zv -w 3 $n 27017; done
```

### 32.2 (Optional) Enlarge the oplog

Run on EVERY member, one at a time, connected directly to it as root (mongosh-root). The size is in MB. /data is only 9.9 GB: the oplog lives on /data, so size it with care and extend the volume first if needed. Example: 4 GB.

**(mongosh)**

```javascript
db.adminCommand({ replSetResizeOplog: 1, size: 4096 })
db.getSiblingDB("local").oplog.rs.stats().maxSize / 1024 / 1024
```

Then set the same value in /etc/mongod.conf (oplogSizeMB: 4096) on every node, so the file matches reality. oplogSizeMB is used only when the oplog is first created; a DR node that starts empty creates its oplog with this size.

### 32.3 Prepare the DR nodes

**Run on:** `DR NODES`

Build the three DR nodes exactly like the HQ nodes:

- STEP 1 - kernel (RHCK, AVX) and the /data volume
- STEP 2 - hosts file (all six DB names) and hostname: drmngodb01 / drmngodb02 / drmngodb03, and time sync
- STEP 3 - SELinux
- STEP 4 - firewall, port 27017
- STEP 5 - kernel tuning, THP, limits, reboot
- STEP 6 - dependency packages
- STEP 7 / 8 - install MongoDB 8.3.13 (the SAME version as HQ) and the dnf exclude line
- STEP 9 - directories

Also add hqmngoom01 to /etc/hosts on the DR nodes (STEP 25.3).

Do NOT run STEP 10 (a new key file) on the DR nodes: they must use the key file of HQ (32.4). Do NOT run STEP 14 or STEP 15 at DR: the replica set and the users already exist and replicate to DR automatically.

### 32.4 Copy the key file from HQ to the DR nodes

**Run on:** `hqmngodb01 ONLY`

All members of prd-rst must have the IDENTICAL key file. If SSH between the sites is not allowed, copy the file by your approved method.

```bash
for n in drmngodb01 drmngodb02 drmngodb03; do scp /data/mongodb/keyfile/mongo-keyfile root@$n:/data/mongodb/keyfile/mongo-keyfile; done
```

Then on the DR NODES fix ownership and permissions (STEP 11) and confirm the file is identical to HQ (the checksum must be the same on all six nodes):

```bash
chown mongod:mongod /data/mongodb/keyfile/mongo-keyfile
chmod 400 /data/mongodb/keyfile/mongo-keyfile
sha256sum /data/mongodb/keyfile/mongo-keyfile
```

### 32.5 mongod.conf and first start of the DR nodes

**Run on:** `PER NODE (DR)`

Use the STEP 12 block unchanged except MY_IP: drmngodb01 -> 10.10.22.30, drmngodb02 -> 10.10.22.31, drmngodb03 -> 10.10.22.32. replSetName stays prd-rst and the keyFile path stays the same. If you enlarged the oplog in 32.2, set oplogSizeMB to the same value before the first start.

The data directory must be EMPTY before the first start, so the node does a clean initial sync from the set. This must print 0:

```bash
ls -A /data/mongodb/data | wc -l
```

Then run STEP 13 (allocator drop-in, enable and start mongod) and STEP 16 (log rotation and aliases).

The node starts and waits to be added: rs.status() on it reports NotYetInitialized, which is normal. Do NOT run rs.initiate() on a DR node: that would create a second, separate replica set.

### 32.6 Tag the HQ members and add the DR members (non-voting first)

**Run on:** `the PRIMARY (mongosh as root)`

Connect to the replica set as root:

```bash
mongosh "mongodb://hqmngodb01:27017,hqmngodb02:27017,hqmngodb03:27017/?replicaSet=prd-rst&authSource=admin" --username root
```

If the set was initiated before STEP 14 contained the tags, tag the HQ members now (safe to run again):

**(mongosh)**

```javascript
cfg = rs.conf()
cfg.members.forEach(m => { if (m.host.startsWith("hqmngodb")) m.tags = { dc: "HQ" } })
rs.reconfig(cfg)
```

Add the DR members ONE AT A TIME, as non-voting with priority 0. A non-voting member does not change the majority, so adding it has no effect on HQ while it syncs. One at a time keeps the initial sync traffic on the WAN under control.

**(mongosh)**

```javascript
rs.add({ _id: 3, host: "drmngodb01:27017", priority: 0, votes: 0, tags: { dc: "DR" } })
```

Watch it: the new member goes STARTUP2 (initial sync) -> SECONDARY. The time depends on the data size and the WAN bandwidth.

**(mongosh)**

```javascript
rs.status().members.map(m => [m.name, m.stateStr, m.health])
```

Initial sync progress, run on the DR node itself (mongosh-root on drmngodb01):

**(mongosh)**

```javascript
db.adminCommand({ replSetGetStatus: 1, initialSync: 1 }).initialSyncStatus
```

When drmngodb01 is SECONDARY, add the next one, and when that one is SECONDARY, the last one:

**(mongosh)**

```javascript
rs.add({ _id: 4, host: "drmngodb02:27017", priority: 0, votes: 0, tags: { dc: "DR" } })
```

**(mongosh)**

```javascript
rs.add({ _id: 5, host: "drmngodb03:27017", priority: 0, votes: 0, tags: { dc: "DR" } })
```

By default secondaries may sync from other secondaries (chaining), so drmngodb02 and drmngodb03 often choose drmngodb01 as their sync source. That is good: the data crosses the WAN only once.

### 32.7 Give the votes to drmngodb01 and drmngodb02

**Run on:** `the PRIMARY (mongosh as root)`

A single reconfiguration may add only ONE voting member, so the votes are given in two steps. The helper below changes the votes and priority of one member; define it once in each new mongosh session (32.10 - 32.12 use it too).

**(mongosh)**

```javascript
function setMember(host, votes, priority) {
  const cfg = rs.conf()
  const m = cfg.members.find(x => x.host === host)
  m.votes = votes
  m.priority = priority
  return rs.reconfig(cfg)
}
```

Give the votes (rs.reconfig waits until a majority has the new configuration before it returns):

**(mongosh)**

```javascript
setMember("drmngodb01:27017", 1, 0)
setMember("drmngodb02:27017", 1, 0)
```

drmngodb03 stays non-voting (votes 0, priority 0).

### 32.8 Validate the replica set with the DR site

**Run on:** `any node (mongosh as root)`

Configuration - must match the design table at the top of this step:

**(mongosh)**

```javascript
rs.conf().members.map(m => [m._id, m.host, m.priority, m.votes, JSON.stringify(m.tags)])
```

State, voting counts and sync sources. Expected: 1 PRIMARY + 5 SECONDARY, health 1; votingMembersCount 5, majorityVoteCount 3, writeMajorityCount 3.

**(mongosh)**

```javascript
rs.status().members.map(m => [m.name, m.stateStr, m.health, m.syncSourceHost])
(() => { const s = rs.status(); return { votingMembersCount: s.votingMembersCount, majorityVoteCount: s.majorityVoteCount, writeMajorityCount: s.writeMajorityCount }; })()
```

Replication lag of every secondary, DR included (should be steady and small):

**(mongosh)**

```javascript
rs.printSecondaryReplicationInfo()
```

Version (expected 8.3.13) - run db.version() on each DR node with mongosh-root.

### 32.9 Update the backup, the applications and Ops Manager

1. Backup (STEP 17): the URI must contain readPreferenceTags=dc:HQ&readPreferenceTags= so the dump reads from an HQ secondary and never pulls the data across the WAN. If your /usr/local/bin/mongo_backup.sh was created before this change, replace its URI line with the one in STEP 17.
2. Applications (STEP 23): add the DR nodes to the seed list, so the same connection string works after a DR activation.
3. Ops Manager:
   - Network: on hqmngoom01 run nc -zv drmngodb01 27017 (and 02, 03); on each DR node run nc -zv hqmngoom01 8080.
   - If you installed the MongoDB Agent on every DB node (STEP 29.3), install it on drmngodb01, 02 and 03 the same way (Deployment > Agents > Downloads & Settings shows the commands).
   - Ops Manager discovers the new members of prd-rst by itself. Check that the deployment shows 1 PRIMARY and 5 SECONDARY.
   - Log rotation (STEP 29.4): once each DR node shows in OM, apply 29.4 on it (one node at a time).
4. Patching (STEP 31) now includes the DR nodes: DR first, then the HQ secondaries, the primary last.

### 32.10 Planned switchover to DR (DR drill, both sites up)

**Run on:** `see each block`

Use this to test that the applications work from DR, or for planned HQ maintenance. Nothing is lost: the set stays healthy and HQ keeps voting.

Step 1 - on the PRIMARY (hqmngodb01), define setMember (32.7) and give drmngodb01 the highest priority. After it has caught up, drmngodb01 takes the primary role (priority 3 > 2), usually within seconds.

**(mongosh)**

```javascript
setMember("drmngodb01:27017", 1, 3)
```

Step 2 - verify (any node). drmngodb01 must be PRIMARY. Writes now cross the WAN from HQ applications, so expect higher latency.

**(mongosh)**

```javascript
rs.status().members.map(m => [m.name, m.stateStr])
```

Switch back. A primary cannot set its own priority to 0 (it would become unelectable), so lower it in two moves:

Step 3 - on drmngodb01 (the current primary), lower its priority to 1. hqmngodb01 (priority 2) takes the primary role back.

**(mongosh)**

```javascript
setMember("drmngodb01:27017", 1, 1)
```

Step 4 - on hqmngodb01 (the primary again), restore priority 0 for drmngodb01, then verify with 32.8.

**(mongosh)**

```javascript
setMember("drmngodb01:27017", 1, 0)
```

### 32.11 DR activation - the HQ site is lost (forced reconfiguration)

**Run on:** `see each block`

Use this ONLY when the HQ site is really down and will not come back soon. It is a management decision: writes that reached HQ but not DR are lost (see "Recovery point" at the top of this step).

Step 1 - make sure HQ cannot come back by itself. In the old configuration HQ holds 3 of 5 votes, so if the HQ nodes return while DR is primary, HQ elects its own primary: a SPLIT-BRAIN with two primaries. If the HQ servers are reachable at all, stop and disable mongod on them:

```bash
systemctl disable --now mongod
```

If they are not reachable, tell the HQ team: before the HQ servers or the WAN link come back, mongod must be disabled on hqmngodb01, 02 and 03.

Step 2 - on drmngodb01, connect DIRECTLY as root and confirm there is no primary:

```bash
mongosh --host drmngodb01 --port 27017 --username root --authenticationDatabase admin
```

**(mongosh)**

```javascript
rs.status().members.map(m => [m.name, m.stateStr, m.health])
```

Step 3 - forced reconfiguration: keep only the DR members and make all three voting, drmngodb01 preferred.

**(mongosh)**

```javascript
cfg = rs.conf()
cfg.members = cfg.members.filter(m => m.host.startsWith("drmngodb"))
cfg.members.forEach(m => { m.votes = 1; m.priority = (m.host === "drmngodb01:27017") ? 2 : 1 })
rs.reconfig(cfg, { force: true })
```

Within about 10-12 seconds drmngodb01 becomes PRIMARY. The set now has 3 voters (majority 2), all at DR, and tolerates 1 more failure.

**(mongosh)**

```javascript
rs.status().members.map(m => [m.name, m.stateStr, m.health])
db.hello().primary
```

Step 4 - applications: with the DR nodes in their seed list (STEP 23) they find the new primary by themselves. Applications with only HQ hosts in the connection string must be changed.

Step 5 - backups: until failback, run the STEP 17 script on a DR node (for example drmngodb02) with readPreferenceTags=dc:DR and the DR hosts in the URI, writing to storage at DR.

### 32.12 Failback - bring HQ back after a DR activation

**Run on:** `see each block`

The HQ nodes come back as NEW members with an empty data directory: they may hold writes that never reached DR, and those writes are discarded. If you must examine them, copy /data/mongodb/data of the old HQ primary to separate storage BEFORE wiping it, and ask MongoDB Support.

Step 1 - on each HQ node (mongod still disabled from 32.11): wipe the data and start mongod. DESTRUCTIVE - run only on the HQ nodes, never on a DR member.

```bash
systemctl stop mongod
rm -rf /data/mongodb/data/*
systemctl enable --now mongod
```

Step 2 - on the DR PRIMARY (drmngodb01, mongosh as root): add the HQ nodes one at a time as non-voting, waiting for SECONDARY each time (as in 32.6).

**(mongosh)**

```javascript
rs.add({ _id: 0, host: "hqmngodb01:27017", priority: 0, votes: 0, tags: { dc: "HQ" } })
rs.status().members.map(m => [m.name, m.stateStr, m.health])
```

```javascript
rs.add({ _id: 1, host: "hqmngodb02:27017", priority: 0, votes: 0, tags: { dc: "HQ" } })
```

```javascript
rs.add({ _id: 2, host: "hqmngodb03:27017", priority: 0, votes: 0, tags: { dc: "HQ" } })
```

Step 3 - restore the votes, one voting change per reconfiguration (define setMember from 32.7 first). The order keeps the number of voters at 4 or 5, never 6:

**(mongosh)**

```javascript
setMember("hqmngodb01:27017", 1, 0)
setMember("hqmngodb02:27017", 1, 0)
setMember("drmngodb03:27017", 0, 0)
setMember("hqmngodb03:27017", 1, 0)
```

Step 4 - move the primary back to HQ. Priority changes are not voting changes, so they go in one reconfiguration. drmngodb01 keeps priority 1 for now (the primary cannot make itself unelectable); hqmngodb01 (priority 2) takes over once it has caught up.

**(mongosh)**

```javascript
cfg = rs.conf()
prio = { "hqmngodb01:27017": 2, "hqmngodb02:27017": 1, "hqmngodb03:27017": 1, "drmngodb01:27017": 1, "drmngodb02:27017": 0, "drmngodb03:27017": 0 }
cfg.members.forEach(m => { m.priority = prio[m.host] })
rs.reconfig(cfg)
```

Step 5 - on hqmngodb01 (the primary again): give drmngodb01 priority 0, so the configuration matches the design table again.

**(mongosh)**

```javascript
setMember("drmngodb01:27017", 1, 0)
```

Step 6 - validate with 32.8, switch the backup back to HQ (STEP 17) and confirm in Ops Manager that all six hosts are green.
