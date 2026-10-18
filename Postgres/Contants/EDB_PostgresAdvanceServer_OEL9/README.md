
# EDB PostgreSQL EPAS  HA Cluster 


## System Design

### Diagram

### System Details

| Role      | OS  | Hostname | IP          |   Port    | CPU | RAM |
| :-------- | --- | -------: | ----------- | :-------: | --- | --- |
| Primary   | OL9 |  pgedb01 | 10.10.21.11 |   5444    | 4   | 4   |
| Standby   | OL9 |  pgedb02 | 10.10.21.12 |   5444    | 4   | 4   |
| Standby   | OL9 |  pgedb03 | 10.10.21.13 |   5444    | 4   | 4   |
| pgBouncer | OL9 | pgbnsr01 | 10.10.21.14 | 7800,7809 | 4   | 4   |
| pgBouncer | OL9 | pgbnsr02 | 10.10.21.15 | 7800,7809 | 4   | 4   |
| Barman    | OL9 | pgbrmn01 | 10.10.21.16 |    NA     | 4   | 4   |

### Used Technologies

- EDB PostgreSQL Advance Server (EPAS)
- Native PostgreSQL Streaming Replication
- EDB FailOver Manager (EFM)
- EDB pgBouncer.
- EDB pgBarman.
- PG_Bench to Test Performance. 


## Setup Database Servers & Streaming Replication

### Prepare Servers for Setup

```bash

## Set Hostname for each server 
############################################################
# db node 1 
hostnamectl set-hostname pgedb01

# db node 2
hostnamectl set-hostname pgedb02

# db node 3 
hostnamectl set-hostname pgedb03

# pool node 1
hostnamectl set-hostname ppbnsr01

# pool node 2 
hostnamectl set-hostname ppbnsr02

# backup node 1 
hostnamectl set-hostname pgbrmn01

############################################################

## Update hosts file on all servers: 
############################################################
# using root user of sudo user 
vim /etc/hosts

# added by admin
10.10.21.11     pgedb01
10.10.21.12     pgedb02
10.10.21.13     pgedb03
10.10.21.14     pgbnsr01
10.10.21.15     pgbnsr02
10.10.21.16     pgbrmn01
############################################################

## Add EDB Repo to all servers Will allow us to install
############################################################
# install epel 
sudo dnf install epel-release

# enable crb
#/usr/bin/crb enable

# install EDB Repo on all Servers 
curl -1sSLf 'https://downloads.enterprisedb.com/uEsw33GAQRegfOuBeTEzGqyBnIJwqi0J/enterprise/setup.rpm.sh' | sudo -E bash

# cache the metadata 
dnf makecache
############################################################

## Format disk and use LVM to create Logical Volumes
############################################################
# warning format disk is critical task you need to be aware about what you are doing here, you may format the OS disk 
# using root user or sudo user you can run below commands 
# list disks added to system
lsblk

# formate the disk you want to use it 
fdisk /dev/sdb
n
enter
enter
enter
enter 
t
8e
p
w
enter
q

# create physical volume 
pvcreate /dev/sdb

# create volume group 
vgcreate pgdata /dev/sdb1

# create logical volume and mount point 
mkdir -p /u01/pg16/pg_data
mkdir -p /u01/pg16/pg_wal
mkdir -p /u01/pg16/pg_arch
lvcreate pgdata -n pg_wal -L 2G
lvcreate pgdata -n pg_arch -L 3G
lvcreate pgdata -n pg_data -l 100%FREE

# make file system xfs for this logical volume 
mkfs.xfs /dev/pgdata/pg_data
mkfs.xfs /dev/pgdata/pg_wal
mkfs.xfs /dev/pgdata/pg_arch

# get the UUID of logical Volume 
blkid | grep pgdata

# result of above commandd 
/dev/mapper/pgdata-pg_data: UUID="9a382ed0-6d2c-4fd2-a3a2-00d6fbc5ecd8" TYPE="xfs"
/dev/mapper/pgdata-pg_wal: UUID="9a382ed0-6d2c-4fd2-a3a2-00d6fbc5ecd8" TYPE="xfs"
/dev/mapper/pgdata-pg_arch: UUID="9a382ed0-6d2c-4fd2-a3a2-00d6fbc5ecd8" TYPE="xfs"

# add this to fstab as shown 
vim /etc/fstab

UUID=9a382ed0-6d2c-4fd2-a3a2-00d6fbc5ecd8 /dev/pgdata/pg_data  xfs     defaults        0 0
UUID=9a382ed0-6d2c-4fd2-a3a2-00d6fbc5ecd8 /dev/pgdata/pg_wal  xfs     defaults        0 0
UUID=9a382ed0-6d2c-4fd2-a3a2-00d6fbc5ecd8 /dev/pgdata/pg_arch  xfs     defaults        0 0


# reload systemd service and mount 
systemctl daemon-reload
mount -a 

# check if the mount point is found df command 
df -h  | grep pgdata
/dev/mapper/pgdata-pg_data  15G 175M  15G  1% /u01/pg16/pg_data
/dev/mapper/pgdata-pg_wal   2G  175M   2G  1% /u01/pg16/pg_wal
/dev/mapper/pgdata-pg_arch  3G  175M   3G  1% /u01/pg16/pg_arch

############################################################

## Check the timezone for all servers
############################################################
# before we initalize the postgres cluster we need to check the timezone 
ls -l /etc/localtime
/etc/localtime -> ../usr/share/zoneinfo/America/New_York

# if not correct create correct softlink using root on all nodes 
ln -fs /usr/share/zoneinfo/Africa/Kampala /etc/localtime
############################################################


############################################################
## TuneD installation
############################################################
sudo dnf install tuned tuned-profiles-postgresql
systemctl enable --now tuned
tuned-adm active 
tuned-adm profile postgresql 
tuned-adm active 
############################################################
```

###  Install & Configure Database Servers 

```bash
## Install EDB PostgreSQL On All Servers/Nodes:
############################################################
dnf install -y  edb-as16-server
############################################################

## Create data directory on all three Database servers 
############################################################
# create dircetories using root and change permission and owner
mkdir -p /u01/pg16/pg_data
chown -R enterprisedb:enterprisedb /u01
chmod 755 /u01/pg16
chmod -R 0700 /u01/pg16/pg_data
############################################################

## Edit the `edb-as-16` on All Servers/Replicas
############################################################
# edit the systemd service edb-as-16
vim /usr/lib/systemd/system/edb-as-16.service
# add below line and comment the original one
Environment=PGDATA=/u01/pg16/pg_data
############################################################


## Create Environment Variables on All DB Servers/Replicas
############################################################
# Create PostgreSQL environment variables in `enterprisedb` home:
su - enterprisedb
cat > ~/.enterprisedb_profile << _EOF_
PATH=/usr/edb/as16/bin:\$PATH:\$HOME/.local/bin:\$HOME/bin
export PATH
export PGDATA=/u01/pg16/pg_data/
export PGUSER=enterprisedb
export PGPASSWORD=
export PGPORT=5444
export PGDATABASE=edb
export PGCONF=/u01/pg16/pg_data/postgresql.conf
export PGHBA=/u01/pg16/pg_data/pg_hba.conf
_EOF_
exit
############################################################


## Initialize the database on Primary 
############################################################
su - enterprisedb
/usr/edb/as16/bin/initdb -D /u01/pg16/pg_data/

# if you like to separate the wal and arch from data dir
rsync -av /u01/pg16/pg_data/pg_wal /u01/pg16/pg_wal
mv /u01/pg16/pg_data/pg_wal /u01/pg16/pg_data/pg_wal_bkp
ln -s /u01/pg16/pg_wal /u01/pg16/pg_data/pg_wal

############################################################

```

### Configure PostgreSQL Parameters in Organized way 

```bash
## Edit Parameters in postgresql.conf on Primary Only 
############################################################
"I retained the original `postgresql.conf` file unchanged and included our modifications in the `conf.d` directory. Please note that the following configurations are working in my environment; make sure to thoroughly review and understand each parameter before applying them to your own setup."

# If you're setting up PostgreSQL for a single instance in a test environment, you can simply adjust the following parameters to allow connections to the server on port 5444:
port = 5444
listen_addresses = '*'   

# To Organize the configuration and the paramters you can follow below structure. 

su - enterprisedb
mkdir $PGDATA/conf.d
chmod -R 0700 $PGDATA/conf.d

vim $PGDATA/postgresql.conf
include_dir = 'conf.d'

cd $PGDATA/conf.d

# this section to adjust the memeory of postgres 
# check the parameters and the read about them before change them if there is no need don't change anything. 
vim 01_memory.conf

shared_buffers = 1GB
work_mem = 8MB  # 8MB * 100 active connections ≈ 800MB
maintenance_work_mem = 256GB     # For VACUUM/CREATE INDEX, etc.
effective_cache_size = 2GB    # 75% of RAM used by filesystem cache
#wal_buffers = -1            # The default setting of -1 selects a size equal to 1/32nd (about 3%) of shared_buffers
temp_buffers = 16MB			# min 800kB


# adjust logging parameter dont apply them to your env only there is a need to do that.
vim 02_logging.conf

# Logging Settings
logging_collector = on              # Required to collect logs
log_timezone = 'Africa/Kampala'
log_directory = 'log'              # Or a custom path (e.g., /var/log/postgresql)
log_filename = 'enterprisedb-%Y-%m-%d_%H%M%S_%a.log' # Rotate logs daily (%a = day of week)
log_file_mode = 0640
log_rotation_age = 1d              # Rotate daily
log_rotation_size = 0              # Don't rotate by size
# what to log
log_min_duration_statement = 500  # Log statements taking > 1 second (in ms)
log_statement = 'ddl'             # Avoid full logging unless auditing it can be 'all', 'mod', 'ddl', 'none'
log_duration = off                 # Avoid duplicate logs with above setting
log_checkpoints = on               # Checkpoint performance
log_lock_waits = on               # Detect blocked queries
log_temp_files = 0                # Log all temporary files (can indicate bad queries)
#log_autovacuum_min_duration = 500 # Log slow autovacuums
log_recovery_conflict_waits = on
log_line_prefix = '%t [%p]: db=%d,user=%u,app=%a,client=%h '
#log_checkpoints = on
log_connections = on
log_disconnections = on
#log_lock_waits = on
#log_temp_files = 0
log_autovacuum_min_duration = 0
log_error_verbosity = default


# this will change the connection parameters tune them as needed
vim 03_connections.conf

# connections  
max_connections = 150
port = 5444
superuser_reserved_connections = 5
listen_addresses = '*'          # what IP address(es) to listen on;
# Client connection settings
#tcp_keepalives_idle = 60
#tcp_keepalives_interval = 30
#tcp_keepalives_count = 10
# Authentication timeout
#authentication_timeout = 60


vim 04_workers.conf

# background worker Tuning for production keep them commented for testing env 

# max_worker_processes = 4
# max_parallel_workers = 6
# max_parallel_workers_per_gather = 4
# max_parallel_maintenance_workers = 4
# parallel_setup_cost = 1000
# parallel_tuple_cost = 0.1


# this part is needed if you want to setup replication or archiveing. 
vim 05_replication.conf

# wal & replication
wal_level = logical              # Use 'replica' physical only or 'logical' physical and logical replication if needed
wal_compression = on
# synchronous_commit = on          # if you want to enable sync replication
# synchronous_standby_names = 'ANY 1 (pgmsp1, pgmsp2, pgmsp3)' # this is to select any node to sync  
max_wal_senders = 20
wal_keep_size = 4GB              # Prevent WAL loss for standbys
hot_standby = on                 # open standby for read only operations
archive_mode = on
archive_command = '/bin/true'
# checkpoint tunning
checkpoint_timeout = 15min
checkpoint_completion_target = 0.9
max_wal_size = 10GB
min_wal_size = 4GB


vim 06_autovacuum.conf

# autvacuum Tuning 
autovacuum = on
autovacuum_max_workers = 4
autovacuum_naptime = 10s
autovacuum_vacuum_cost_limit = 2000
autovacuum_vacuum_threshold = 50
autovacuum_analyze_threshold = 50


vim 07_others.conf

# other inportant tuning
effective_io_concurrency = 300     # For SSDs
random_page_cost = 1.1             # Lower if using SSD
default_statistics_target = 100
cluster_name = 'pgnode1' # you need to change this for each node
shared_preload_libraries = '$libdir/dbms_pipe,$libdir/edb_gen,$libdir/dbms_aq,$libdir/pg_stat_statements'
pg_stat_statements.max = 10000
pg_stat_statements.track = all
track_activity_query_size = '4096'


############################################################

## Enable and start service on Primary only 
############################################################
# using root start service 
systemctl enable edb-as-16 
systemctl status edb-as-16
systemctl start edb-as-16
############################################################


## Allow Port 5444 on all Nodes 
############################################################
# enable port on firewall on all nodes 
sudo firewall-cmd --zone=public --add-port=5444/tcp --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
############################################################


## Set Password & Edit HBA file On Primary Only
############################################################
# set a enterprisedb password 
su - enterprisedb
psql -h /tmp
edb=# \password
Enter new password for user "enterprisedb": edb1
\q

# update pg_hba.conf with this line to allow this subnet to access postgres server
su - enterprisedb 
vim $PGHBA 
host    all             all             10.10.21.0/24         scram-sha-256

# Restart or reload the edb-as-16 service 
sudo systemctl reload edb-as-16.service 

# or reload using psql
psql -h 10.10.21.11 -p 5444 -U enterprisedb edb -c "SELECT pg_reload_conf();"

# try to connect to database from all nodes using below command to make sure that you have access 
psql -h 10.10.21.11 -p 5444 -U enterprisedb edb 
############################################################

```

### Setup Streaming Replication

```bash

## Create a replication user on primary server 
############################################################
# create user called efm_repl using below command 
su - enterprisedb
psql -h 10.10.21.11 -p 5444 -U enterprisedb edb -c "CREATE ROLE efm_repl REPLICATION LOGIN PASSWORD '3fm_r3pl_123'";
############################################################


## add efm_repl record to pg_hba.conf file to be allowed
############################################################
# add efm_repl record to pg_hba.conf file to be allowed
su - enterprisedb
 vim $PGHBA
host    replication     efm_repl        10.10.21.0/24        scram-sha-256
############################################################


## add the pgpass hidden file to enterprisedb os user home
############################################################
# add the pgpass hidden file to enterprisedb os user home on all node as showen below 
cat > ~/.pgpass << _EOF_
10.10.21.11:5444:*:efm_repl:3fm_r3pl_123
10.10.21.12:5444:*:efm_repl:3fm_r3pl_123
10.10.21.13:5444:*:efm_repl:3fm_r3pl_123
_EOF_

chmod 0600 ~/.pgpass

# check the access to EFM_REPL from all nodes 
psql -U efm_repl -h 10.10.21.11 -p 5444   -c "IDENTIFY_SYSTEM"   replication=1
############################################################


## edit postgresql.conf file to allow replication
############################################################
# go to conf.d and edit  05_replication.conf file to allow replication and other important parameter on primary only 
vim $PGADATA/conf.d/05_replication.conf

# enable replication by uncomment and adjust as per needed 
wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
wal_keep_size = 1024 # increase if the system is busy 
hot_standby = on # open replica for readonly

## Restart service on Primary only 
############################################################
# using root start service 
systemctl start edb-as-16
############################################################

## Create first standby servers 
############################################################
# use enterprisedb user 
su - enterprisedb

# Create First Standby Server using pg_basebackup 
pg_basebackup -D ${PGDATA} -h 10.10.21.11 -U efm_repl -p 5444  -Xs -R -P

# edit the postgresql.conf or 07_others.conf
vim postgresql.conf / vim conf.d/07_others.conf
cluster_name = 'edbpg2' # change this per node
############################################################

## Enable and start service on First standby 
############################################################
# using root start service 
systemctl enable edb-as-16 
systemctl status edb-as-16
systemctl start edb-as-16
############################################################

##  Create Second standby servers 
############################################################
# Create Second Standby Server using pg_basebackup 
pg_basebackup -D /u01/pg16/pg_data -h 10.10.21.11 -U efm_repl -p 5444  -Xs -R -P

# edit the postgresql.conf or 07_others.conf
vim postgresql.conf / vim conf.d/07_others.conf
cluster_name = 'edbpg2' # change this per node
############################################################

## Enable and start service on Second standby
############################################################
# using root start service 
systemctl enable edb-as-16 
systemctl status edb-as-16
systemctl start edb-as-16
############################################################

## check the replicas from primary using below command 
############################################################
select application_name, client_addr,state, sync_state, reply_time from pg_stat_replication;
psql -h /tmp -c 'SELECT client_addr, state FROM pg_stat_replication;'
psql -h /tmp -c 'select * from pg_stat_replication;'
psql -h /tmp -c 'SELECT client_addr, state FROM pg_stat_replication;'
psql -h /tmp -c 'select application_name, client_addr, state, sync_state, reply_time from pg_stat_replication;'
psql -h /tmp -c 'select pg_wal_lsn_diff(sent_lsn, replay_lsn) from pg_stat_replication;' # for gaps 
############################################################
```

### Password-less SSH Configuration EnterpriseDB User

```bash
## Create SSH Passwordless connection between servers
############################################################
# using root user set a pass forenterprisedb on all DB servers
passwd enterprisedb
su - enterprisedb
ssh-keygen -t ed25519 # press enter till the ssh-keygen finish

# node 1 
su - enterprisedb
ssh-copy-id pgedb02
ssh-copy-id pgedb03

# node 2 
su - enterprisedb
ssh-copy-id pgedb01
ssh-copy-id pgedb03

# node 3 
su - enterprisedb
ssh-copy-id pgedb01
ssh-copy-id pgedb02

# check the permission on all nodes or apply below 
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

# on 3 nodes remove the enterprisedb password for security
# using root user or sudo 
passwd -d enterprisedb
############################################################
```

### \[Optional\] Synchronous Streaming Replication.

```bash
## Optional Enable sync replication between nodes
############################################################
# this should be applied on all nodes
# to enable sync replication you need to tune below parameters
# accepted values : on/off/remote_apply/remote_write/local
synchronous_commit = on   #default if you face issue in performance go with remote_write

#You can adjust `ANY 1`, `FIRST 1`, or full quorum depending on your sync policy.
synchronous_standby_names = 'ANY 1 (edbpg1, edbpg2, edbpg3)' 
############################################################
```

### \[Optional\] Streaming Replication with Slot 

 ✅ **Production Recommendation**

| Feature                         | With Slots (✔ Recommended)        | Without Slots                   |
| ------------------------------- | --------------------------------- | ------------------------------- |
| Resilience to replica downtime  | ✔ High                            | ❌ Low                           |
| WAL disk management             | ❌ Requires monitoring             | ✔ Simpler                       |
| Ease of rejoining after failure | ✔ Automatic resume                | ❌ May require base backup again |
| Operational simplicity          | ❌ Slightly complex                | ✔ Simpler but riskier           |
| Best use case                   | ✔ Long-lived replicas, HA systems | ✔ Ephemeral replicas (dev, QA)  |

```bash
## Optional Use Slots with Physical replication between nodes
############################################################
# create slots on each node to server the others 
# Node 1 
SELECT pg_create_physical_replication_slot('edbpg2');
SELECT pg_create_physical_replication_slot('edbpg3');

# Node 2
SELECT pg_create_physical_replication_slot('edbpg1');
SELECT pg_create_physical_replication_slot('edbpg3');

# Node 3 
SELECT pg_create_physical_replication_slot('edbpg2');
SELECT pg_create_physical_replication_slot('edbpg1');

# Update the efm.properties on all nodes 
grep ^application.name /etc/edb/efm-4.10/efm.properties
grep ^update.physical.slots.period /etc/edb/efm-4.10/efm.properties
update.physical.slots.period=5

# to update value of slots period 
 sed -i 's/^update.physical.slots.period=0/update.physical.slots.period=5/' /etc/edb/efm-4.10/efm.properties

# update the postgresql.auto.conf on all server 

# Node1
vim postgresql.auto.conf
primary_slot_name = 'edbpg1'
show primary_slot_name ;

# Node 2 
vim postgresql.auto.conf
primary_slot_name = 'edbpg2'
show primary_slot_name ;

# Node 3
vim postgresql.auto.conf
primary_slot_name = 'edbpg3'
show primary_slot_name ;

# to activate the slot reload the service on all standby
systemctl reload edb-as-16


# check the slots if they are active on primary server 
psql
select * from pg_replication_slots;
############################################################
```

### Control the Physical Replication 

The full documentation for controlling the physical replication can be found here [FUNCTIONS-RECOVERY-CONTROL-TABLE](https://www.postgresql.org/docs/current/functions-admin.html#FUNCTIONS-RECOVERY-CONTROL-TABLE)

```bash
## Optional Control Physical replication between nodes
############################################################
# Check WAL Replay Status on Standbys
SELECT pg_is_wal_replay_paused();
SELECT pg_get_wal_replay_pause_state();

# Pause/Resume WAL Replay on Standbys (Hot Standby Use Case)
# Run as superuser (or granted user) on standby:
SELECT pg_wal_replay_pause();   # Freeze standby (WAL replay paused)
SELECT pg_wal_replay_resume();  # Resume standby
############################################################
```

### Tune PostgreSQL parameters

#### Referances

- PostgreSQL Performance Tuning: Optimize Your Database Server [link](https://www.enterprisedb.com/postgres-tutorials/introduction-postgresql-performance-tuning-and-optimization)
- Comprehensive Guide on How to Tune Database Parameters [link](https://www.enterprisedb.com/postgres-tutorials/comprehensive-guide-how-tune-database-parameters-and-configuration-postgresql)
- Configure and Tune EPAS and PostgreSQL Database Servers on Linux [link](https://www.enterprisedb.com/blog/general-configuration-and-tuning-recommendations-edb-postgres-advanced-server-and-postgresql)
## Setup EDB Failover Manager (EFM)

### Install EFM

```bash
## install efm on all database servers
############################################################
# use root or sudo user to install efm 
dnf install -y edb-efm410 java-17-openjdk
############################################################

## Create a EFM sql file to setup efm Role on primary server
############################################################
# create a file that has command to be run using psql to create efm user which will be used to manage edm cluster 
cat > /tmp/efm-role.sql << _EOF_
-- Create a role for EFM
CREATE ROLE efm LOGIN PASSWORD '3fmUs3r123';

-- Give privilege to 'efm' user to connect to a database
GRANT CONNECT ON DATABASE edb TO efm;

-- Give privilege to 'efm' user to do backup operations
GRANT EXECUTE ON FUNCTION pg_current_wal_lsn() TO efm;
GRANT EXECUTE ON FUNCTION pg_last_wal_replay_lsn() TO efm;
GRANT EXECUTE ON FUNCTION pg_wal_replay_resume() TO efm;
GRANT EXECUTE ON FUNCTION pg_wal_replay_pause() TO efm;
GRANT EXECUTE ON FUNCTION pg_reload_conf() TO efm;

-- Grant monitoring privilege to the 'efm' user
GRANT pg_monitor TO efm;
_EOF_

# run the command to execute the sql file on primary server 
psql -h 10.10.21.11 -p 5444 -U enterprisedb edb -f /tmp/efm-role.sql

# once finish remove the file    
rm -f /tmp/efm-role.sql
############################################################



## add hba file entry to allow the efm user to connect 
############################################################
su - enterprisedb
vim $PGHBA
host    all             efm             10.10.21.0/24           scram-sha-256

# try to connect from all nodes  
 psql -h 10.10.21.11 -p 5444 -U efm edb
############################################################

## try to create a copy of two below files 
############################################################
cp /etc/edb/efm-4.10/efm.properties.in /etc/edb/efm-4.10/efm.properties
cp /etc/edb/efm-4.10/efm.nodes.in /etc/edb/efm-4.10/efm.nodes
sudo chown efm:efm /etc/edb/efm-4.10/efm.nodes
sudo chmod 600 /etc/edb/efm-4.10/efm.nodes
sudo chown efm:efm /etc/edb/efm-4.10/efm.properties
sudo chmod a+r /etc/edb/efm-4.10/efm.properties
############################################################
```

### Password-less SSH Configure EFM OS User 

```bash
## Create EFM SSH Passwordless connection between servers
############################################################
# using root user set a pass for efm user on all DB servers
passwd efm
su - efm
ssh-keygen -t ed25519 # press enter till the ssh-keygen finish

# node 1 
su - efm
ssh-copy-id pgedb02
ssh-copy-id pgedb03

# node 2 
su - efm
ssh-copy-id pgedb01
ssh-copy-id pgedb03

# node 3 
su - efm
ssh-copy-id pgedb01
ssh-copy-id pgedb02

# check the permission on all nodes or apply below 
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

# Check the selinux context if var_t **NOT** the right type for SSH keys.

ls -lZ /var/efm/.ssh 
-rw-------. 1 efm efm system_u:object_r:var_t:s0 186 Aug 10 02:00 authorized_keys

# to fix the context
# If the type is `var_t`, SSH will **not** allow key-based login under SELinux enforcing mode — even if the file permissions are correct.
sudo semanage fcontext -a -t ssh_home_t "/var/efm/.ssh(/.*)?"
sudo restorecon -Rv /var/efm/.ssh


# on 3 nodes remove the efm password for security
# using root user or sudo 
passwd -d efm
############################################################

## Create EFM Environment variable
############################################################
# switch to efm user and create bash profile there 
su - efm
cat > ~/.bash_profile << _EOF_
export PATH=/usr/edb/efm-4.10/bin:$PATH
export EFMC=/etc/edb/efm-4.10/efm.properties
export EFMN=/etc/edb/efm-4.10/efm.nodes
_EOF_

# source the bash profile again 
source ~/.bash_profile

#run efm if you see this error 
efm
/usr/bin/which: no java in (/usr/edb/efm-4.10/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin)
Unable to find JRE in path.

# means you dont have jdk and you can install openjdk 
sudo dnf install tzdata-java 
# or  
sudo dnf install java-17-openjdk
############################################################


## Enable EFM Ports on all servers OS firewall
############################################################
# enable firewall role -- root user or sudo 
sudo firewall-cmd --zone=public --add-port=7800/tcp --permanent
sudo firewall-cmd --zone=public --add-port=7809/tcp --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
############################################################

```

### Configure EFM on 3 Nodes 

```bash
## Create EFM Cluster Password
############################################################
# create export efmpass
su - efm 
export EFMPASS=3fmUs3r123 # this is the pwd of efm db user 
efm encrypt efm --from-env
# output 
3300879ca6a026c34be750c25c2130ad
############################################################


## edit the efm.properties list below  
############################################################
su - efm 
vim $EFMC
# efm.properties node 1 -- primary 
db.user=efm
db.password.encrypted=3300879ca6a026c34be750c25c2130ad
db.port=5444
db.database=edb
application.name=edbpg1 # check cluster_name postgresql.conf
db.service.owner=enterprisedb
db.service.name=edb-as-16
db.bin=/usr/edb/as16/bin
db.data.dir=/u01/pg16/pg_data/
bind.address=10.10.21.11:7800 # for node 1
user.email=username@example.com
from.email=pgedb01@efm-epas # to know its come from node1
notification.text.prefix=[EPAS/EFM]
is.witness=false
encrypt.agent.messages=true
virtual.ip=10.10.21.30
virtual.ip.interface=ens160
virtual.ip.prefix=24

# efm.properties node 2 -- standby 
db.user=efm
db.password.encrypted=3300879ca6a026c34be750c25c2130ad
db.port=5444
db.database=edb
db.service.owner=enterprisedb
db.service.name=edb-as-16
application.name=edbpg2 # check cluster_name postgresql.conf
db.bin=/usr/edb/as16/bin
db.data.dir=/u01/pg16/pg_data/
bind.address=10.10.21.12:7800 # for node 2
user.email=username@example.com
from.email=pgedb02@efm-epas # to know its come from node1
notification.text.prefix=[EPAS/EFM]
is.witness=false
encrypt.agent.messages=true
virtual.ip=10.10.21.30
virtual.ip.interface=ens160
virtual.ip.prefix=24

# efm.properties node 3 -- standby 
db.user=efm
db.password.encrypted=3300879ca6a026c34be750c25c2130ad
db.port=5444
db.database=edb
db.service.owner=enterprisedb
db.service.name=edb-as-16
application.name=edbpg3 # check cluster_name postgresql.conf
db.bin=/usr/edb/as16/bin
db.data.dir=/u01/pg16/pg_data/
bind.address=10.10.21.13:7800 # for node 3
user.email=username@example.com
from.email=pgedb03@efm-epas # to know its come from node1
notification.text.prefix=[EPAS/EFM]
is.witness=false
encrypt.agent.messages=true
virtual.ip=10.10.21.30
virtual.ip.interface=ens160
virtual.ip.prefix=24
############################################################
```

### Enable EFM Service and Join Nodes

```bash
## Enable Start EFM Service on Primary server 
############################################################
systemctl enable edb-efm-4.10.service
systemctl start edb-efm-4.10.service
systemctl status edb-efm-4.10.service

# check cluster status 
su - efm 
efm cluster-status efm

# check logs if the service failed
tail -f  /var/log/efm-4.10/efm.log
tail -f  /var/log/efm-4.10/startup-efm.log
############################################################

## add the standby servers to the cluster EFM
############################################################
 vim /etc/edb/efm-4.10/efm.nodes
 # or if you add env variable in bash profile on all 3 nodes 
 vim $EFMN
10.10.21.11:7800 10.10.21.12:7800 10.10.21.13:7800

# allow nodes on primary using efm command 
su - efm 
efm allow-node efm 10.10.21.12
efm allow-node efm 10.10.21.13

# start services on both standby servers 
systemctl enable edb-efm-4.10.service
systemctl start edb-efm-4.10.service

# check the status of cluster using efm command 
su - efm 
efm cluster-status efm 
############################################################

```

### Tune EFM parameters 

if you are using Physical slots in the physical replication between nodes you need to set below parameters:

```bash
# apply below changes on all nodes change the app name to match the cluster name. 
update.physical.slots.period=0
application.name=edbpg1
```


## Setup pgBouncer 


### Edit Hosts file 

```bash
vim /etc/hosts

# added by admin
10.10.21.11     pgedb01
10.10.21.12     pgedb02
10.10.21.13     pgedb03
10.10.21.14     pgbnsr01
10.10.21.15     pgbnsr02
10.10.21.16     pgbrmn01
```

### Create SSH Passwordless 

```bash
## Create SSH Passwordless connection between servers
############################################################
# using root user set a pass forenterprisedb on all DB servers
passwd enterprisedb
su - enterprisedb
ssh-keygen -t ed25519 # press enter till the ssh-keygen finish

# node 1 
su - enterprisedb
ssh-copy-id pgbnsr02


# node 2 
su - enterprisedb
ssh-copy-id pgbnsr01
```

### Install pgBouncer

```bash
## Install pgbouncer postgresql client using root or sudo
############################################################
sudo dnf install edb-pgbouncer124 edb-as16-server-client 
############################################################
```

### Configure pgBouncer

```bash
## check if edb dir created
############################################################
ls -l /var/lib/edb
# if not create it using command below: 
mkdir /var/lib/edb
# change the ownership of this dir to enterprisedb
chown -R enterprisedb:enterprisedb /var/lib/edb
############################################################

## chown the /etc/edb/pgbouncer1.23/
############################################################
chown -R enterprisedb:enterprisedb /etc/edb/pgbouncer1.24/
chmod 0700 /etc/edb/pgbouncer1.24

## Allow 6432 port using firewall-cmd
############################################################
sudo firewall-cmd --zone=public --add-port=6432/tcp --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
############################################################

## Enable SSH passwordless for enterprisedb OS user
############################################################
# using root or sudo Node 1
passwd enterprisedb
su - enterprisedb
ssh-keygen -t ed25519
ssh-copy-id ppbnsr02

# using root or sudo Node 2
passwd enterprisedb
su - enterprisedb
ssh-keygen -t ed25519
ssh-copy-id ppbnsr02
############################################################
```

### Use pgBouncer with DB

```bash
## Create user & Database on Primary Database
############################################################
create user app_user1 with login password 'app_us3r123';
create database app_db1 owner app_user1;
create user app_user2 with login password 'app_us3r1234';
create user app_user3 with login password 'app_us3r1235';
############################################################

## Edit pgBouncer edb-pgbouncer-1.24.ini
############################################################
vim /etc/edb/pgbouncer1.24/edb-pgbouncer-1.24.ini
# add below changes  
app_db1 = host=10.10.21.30 port=5444 user=app_user1 dbname=app_db1
logfile = /var/log/edb/pgbouncer1.24/edb-pgbouncer-1.24.log
pidfile = /run/edb/pgbouncer1.24/edb-pgbouncer-1.24.pid
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = md5
auth_file = /etc/edb/pgbouncer1.24/userlist.txt
admin_users = enterprisedb
stats_users = enterprisedb
pool_mode = transaction
ignore_startup_parameters = application_name,extra_float_digits
max_client_conn = 10000
max_db_connections = 100


## Edit pgBouncer userlist.txt
############################################################
vim /etc/edb/pgbouncer1.24/userlist.txt
# add the username and password 
"app_user1" "app_us3r_123"
"enterprisedb" "edb1"
############################################################

## enable and start or reload pgbouncer service 
############################################################
systemctl enable edb-pgbouncer-1.24.service
systemctl start edb-pgbouncer-1.24.service
systemctl status edb-pgbouncer-1.24.service
# if you made any change your can reload 
 systemctl reload edb-pgbouncer-1.24.service
############################################################

```


### Tune pgBouncer parameters

```bash
# this is the database defintion with parameter 
app_db1 = host=10.10.21.20 port=5444 user=app_user1 dbname=app_db1 pool_mode=teansaction pool_size=4

# we can add anthor database as read only 
app_db1_ro = host=10.10.21.13 port=5444 user=app_user1 dbname=app_db1 pool_mode=session pool_size=4

#The maximum number of _client connections_ PgBouncer will accept (total, across all databases and users).
max_client_conn     = 500

#The default number of _server connections_ PgBouncer will keep open **per database-user pair**.
pool_size           = 50

# The absolute maximum number of _server connections_ PgBouncer will open **per database**,
max_db_connections  = 100


```

### Monitor pgBouncer

https://www.pgbouncer.org/usage.html

```bash
# make sure you are enterprisedb user 
su - enterprisedb

# create .pgpass  
vim .pgpass
10.10.21.14:6432:pgbouncer:enterprisedb:edb1

# change the .pgpass permission 
chmod 600 .pgpass 

# connect to pgbouncer db 
psql -h 10.10.21.14 -U enterprisedb -p 6432 -d pgbouncer

# show help menu 
show help;
NOTICE:  Console usage
DETAIL:  
	SHOW HELP|CONFIG|DATABASES|POOLS|CLIENTS|SERVERS|USERS|VERSION
	SHOW PEERS|PEER_POOLS
	SHOW FDS|SOCKETS|ACTIVE_SOCKETS|LISTS|MEM|STATE
	SHOW DNS_HOSTS|DNS_ZONES
	SHOW STATS|STATS_TOTALS|STATS_AVERAGES|TOTALS
	SET key = arg
	RELOAD
	PAUSE [<db>]
	RESUME [<db>]
	DISABLE <db>
	ENABLE <db>
	RECONNECT [<db>]
	KILL <db>
	KILL_CLIENT <client_id>
	SUSPEND
	SHUTDOWN
	SHUTDOWN WAIT_FOR_SERVERS|WAIT_FOR_CLIENTS
	WAIT_CLOSE [<db>]
```

## Setup Barman Server

### Setup the Server

```bash
# add network profile 
nmcli connection add type ethernet con-name ens192 ifname ens192 ipv4.addresses 10.10.21.16/24 ipv4.method manual connection.autoconnect yes

# set hostname 
hostnamectl set-hostname pgbrmn01

# add server names to hosts file 
vim /etc/hosts


# install EDB Repo on barman server 
curl -1sSLf 'https://downloads.enterprisedb.com/uEsw33GAQRegfOuBeTEzGqyBnIJwqi0J/enterprise/setup.rpm.sh' | sudo -E bash

# install barman server 
sudo dnf install barman edb-as16-server-client 


# create barman backup dir 
mkdir -p /u01/backup

chown -R barman:barman /u01 
chmod -R 0700 /u01

```

### Configure Barman Server

```bash

### On Primary PostgreSQL Server 

# create postgres Replication user 
createuser -P --replication barman

# add this to pg_hba file on all nodes
host    replication     barman          10.10.21.0/24           scram-sha-256

# reload systemd service on all nodes 
systemctl reload edb-as-16.service

# test barman user  
psql -U barman -h 10.10.21.20 -p 5444 -c "IDENTIFY_SYSTEM" replication=1

### On Barman Server 

# create pgpass for auto login
su - barman
echo "*:5444:*:barman:edb1" >> ~/.pgpass
chmod 0600 ~/.pgpass

# test barman user should work without a need for password 
psql -U barman -h 10.10.21.20 -p 5444 -c "IDENTIFY_SYSTEM" replication=1
```

## Administration Manual

## Stop & Start Sequence and Best Practice


### Steps to Stop/Start EFM Cluster

#### Stop EFM Cluster

in case we are required to stop EFM services  across of all nodes for maintenance purposes `stop-cluster` command will stop all service on all nodes.

```bash
su - efm 
efm stop-cluster efm 
```

#### Start EFM Cluster on Primary 

Start EFM Service.

	> systemctl start edb-efm-4.10
#### Start EFM Cluster on Standby Nodes

Start EFM Service.

	> systemctl start edb-efm-4.10


### Steps to Stop/Start PostgreSQL & EFM Services

#### Stop On Standby Nodes

- Stop EFM Services
	> systemctl stop edb-efm-4.10
- Stop PostgreSQL Services
	> systemctl stop edb-as-16
#### Stop on Primary Node

- Stop EFM Services
	> systemctl stop edb-efm-4.10
- Stop PostgreSQL services
	> systemctl stop edb-as-16
#### Start on Primary Node

- Start PostgreSQL Services
	> systemctl start edb-as-16
- Start EFM Service.
	> systemctl start edb-efm-4.10
#### Start on Standby Nodes

- Start PostgreSQL Services.
	> systemctl start edb-as-16
- Start EFM Service.
	> systemctl start edb-efm-4.10


## Extensions

### PG_SQUEEZE

PG Squeeze (`pg_squeeze`) is an extension released as open source software under the PostgreSQL License.

`pg_squeeze` removes unused space from a table and optionally sorts tuples according to a particular index (as if a `CLUSTER` command were executed concurrently with regular reads and writes). In fact, `pg_squeeze` tries to replace the `pg_repack` extension. While providing very similar functionality, `pg_squeeze` takes a different approach by:

- Implementing functionality solely on the server side. This approach makes both configuration and use simpler than `pg_repack`, which uses both server- and client-side code. Server-side implementation also allows for smooth implementation of unattended processing using background workers.
    
- Using recent improvements of the PostgreSQL database server. Most notably, besides the use of background workers, `pg_squeeze` uses logical decode instead of triggers to capture concurrent changes.
> Reference [link](https://www.enterprisedb.com/docs/pg_extensions/pg_squeeze/)
#### Installing 

```bash
sudo dnf install edb-as16-pg-squeeze1.x86_64
```

#### Configuring

```js
# add this to the configuration file 
shared_preload_libraries = 'pg_squeeze'

# make sure using these settings 
wal_level = logical
max_replication_slots = 1 # ... or add 1 to the current value.

# create the extension in the database that you want to squeeze.
CREATE EXTENSION pg_squeeze;
```
#### Using

```sql
-- ========================================
-- PostgreSQL Bloat Simulation with pg_squeeze
-- ========================================

-- Step 1: Create Test Database
CREATE DATABASE bloat_lab;
\c bloat_lab

-- Step 2: Create Sample Table
CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    name TEXT,
    department TEXT,
    salary NUMERIC,
    updated_at TIMESTAMP DEFAULT now()
);
alter table employees set (autovacuum_enabled = false, toast.autovacuum_enabled = false);

select relname, n_dead_tup, n_live_tup, 100*n_dead_tup/n_live_tup as Percent, left (last_vacuum::text,16) as last_vacuum, left(last_autovacuum::text,16) as last_autovacuum, last_analyze,left(last_autoanalyze::text,16) as last_autoanalyze, now() from pg_stat_user_tables;

-- Step 3: Insert Sample Data
INSERT INTO employees (name, department, salary)
SELECT
    'Employee_' || i,
    CASE 
        WHEN i % 3 = 0 THEN 'HR'
        WHEN i % 3 = 1 THEN 'IT'
        ELSE 'Finance'
    END,
    50000 + (random() * 10000)::int
FROM generate_series(1, 100000) AS i;

\dt+

-- Step 4: Simulate Bloat
-- 4a: Update a large portion of rows
UPDATE employees
SET 
    salary = salary + 1000,
    updated_at = now()
WHERE id % 2 = 0;

-- 4b: Delete a portion of rows
DELETE FROM employees
WHERE id % 5 = 0;

-- Step 5: Check Table Size and Bloat
SELECT 
    schemaname,
    relname,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    pg_size_pretty(pg_relation_size(relid)) AS table_size,
    pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) AS indexes_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;

SELECT
    schemaname || '.' || relname AS table_name,
    n_live_tup AS live_tuples,
    n_dead_tup AS dead_tuples,
	ROUND((n_dead_tup::numeric / (n_live_tup + n_dead_tup)::numeric) * 100, 2) AS dead_tuple_percentage
FROM
    pg_stat_user_tables
WHERE
    n_live_tup > 0 -- Exclude empty tables
    AND n_dead_tup > 0 -- Exclude tables with no dead tuples
ORDER BY
    dead_tuple_percentage DESC;
    
-- index size
SELECT
    i.relname AS index_name,
    pg_size_pretty(pg_relation_size(i.oid)) AS index_size,
    pg_relation_size(i.oid) AS index_size_bytes
FROM pg_class t
JOIN pg_namespace ns ON ns.oid = t.relnamespace
JOIN pg_index ix ON t.oid = ix.indrelid
JOIN pg_class i ON i.oid = ix.indexrelid
WHERE t.relname = 'employees'
  AND ns.nspname = 'public'  -- change schema if needed
ORDER BY pg_relation_size(i.oid) DESC;

-- Step 6: Reclaim Space Using pg_squeeze
-- Note: Ensure the pg_squeeze extension is installed and configured
SELECT squeeze.table_squeeze('public', 'employees');

----------------------------------------------------

-- Create test table
DROP TABLE IF EXISTS testTB;

CREATE TABLE testTB (
    id SERIAL PRIMARY KEY,
    title VARCHAR(10) NOT NULL,
    toppings TEXT NOT NULL,
    thoughts TEXT NOT NULL,
    code VARCHAR(4) NOT NULL,
    UNIQUE(title, toppings)
);

alter table testTB set (autovacuum_enabled = false, toast.autovacuum_enabled = false);

-- Insert 1 million rows with pseudo-random data
INSERT INTO testTB (title, toppings, thoughts, code)
SELECT 
    LEFT(md5(i::text), 10),
    md5(random()::text),
    md5(random()::text),
    LEFT(md5(random()::text), 4)
FROM generate_series(1, 1000000) AS s(i);

-- Update operations to simulate changes (introduce dead tuples for bloat simulation)
UPDATE testTB SET thoughts = md5(random()::text) WHERE id < 10000;

UPDATE testTB SET thoughts = md5(random()::text) WHERE id BETWEEN 10000 AND 20000;

UPDATE testTB SET thoughts = md5(random()::text) WHERE id BETWEEN 800000 AND 900000;

UPDATE testTB SET thoughts = md5(random()::text) WHERE id BETWEEN 600000 AND 700000;

DELETE FROM testTB WHERE id BETWEEN 600000 AND 700000;

SELECT reltoastrelid::regclass AS toast_table
FROM pg_class
WHERE relname = 'testTB';

select * from pgstattuple('public.testtb');

select relname, n_dead_tup, n_live_tup, left (last_vacuum::text,16) as last_vacuum, left(last_autovacuum::text,16) as last_autovacuum, last_analyze,left(last_autoanalyze::text,16) as last_autoanalyze, now() from pg_stat_user_tables;



--- list toast tables in the database
SELECT nspname || '.' || relname AS "relation"
       ,pg_size_pretty(pg_relation_size(C.oid)) AS "size" 
 FROM pg_class C 
     LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace) 
 WHERE nspname NOT IN ('pg_catalog', 'information_schema') 
 ORDER BY pg_relation_size(C.oid) DESC 
 LIMIT 20;



```


### PG_STAT_STATEMENTS

### Installing

#### Configuring

```sql

```

#### Using

```sql
-- high cpu 

SELECT
	query,
	calls,
	total_exec_time,
	rows
FROM
	pg_stat_statements
ORDER BY
	total_exec_time DESC
LIMIT
	5;

-- Top 10 time-consuming queries
SELECT 
pss.userid::regrole, 
pd.datname, 
pss.query
FROM pg_stat_statements as pss
INNER JOIN pg_database AS pd
ON pss.dbid = pd.oid
ORDER BY pss.min_exec_time DESC
LIMIT 10;

SELECT 
pss.userid::regrole, 
pd.datname, 
pss.query
FROM pg_stat_statements as pss
INNER JOIN pg_database AS pd
ON pss.dbid = pd.oid
ORDER BY pss.total_exec_time DESC
LIMIT 10;



 --Top 10 response-time outliers

SELECT 
pss.userid::regrole, 
pd.datname, 
pss.query
FROM pg_stat_statements as pss
INNER JOIN pg_database AS pd
ON pss.dbid = pd.oid
ORDER BY pss.stddev_exec_time DESC
LIMIT 10;




 --Top 10 queries by memory usage

SELECT 
pss.userid::regrole, 
pd.datname, 
pss.query
FROM pg_stat_statements as pss
INNER JOIN pg_database AS pd
ON pss.dbid = pd.oid
ORDER BY (pss.shared_blks_hit + pss.shared_blks_dirtied) DESC
LIMIT 10;

--Top 10 consumers of temporary space

SELECT 
pss.userid::regrole, 
pd.datname, 
pss.query
FROM pg_stat_statements as pss
INNER JOIN pg_database AS pd
ON pss.dbid = pd.oid
ORDER BY pss.temp_blks_written DESC
LIMIT 10;

--Top 10 long executed queries

SELECT
pd.datname,
pss.query AS SQLQuery,
pss.rows AS TotalRowCount,
(pss.total_exec_time / 1000 / 60) AS TotalMinute,
((pss.total_exec_time / 1000 / 60)/calls) as TotalAverageTime               
FROM pg_stat_statements AS pss
INNER JOIN pg_database AS pd
ON pss.dbid = pd.oid
ORDER BY 5 DESC 
LIMIT 10;

--List queries with total no. of calls, total rows & rows returned etc:

SELECT
pd.datname,
pss.query,
pss.calls,
pss.total_exec_time, 
pss.rows,
100.0 * pss.shared_blks_hit / nullif(pss.shared_blks_hit + pss.shared_blks_read, 0) AS hit_percent 
FROM pg_stat_statements AS pss
INNER JOIN pg_database AS pd
ON pss.dbid = pd.oid 
ORDER BY pss.total_exec_time DESC 
LIMIT 10;

--The most hit and read objects:

SELECT 
pd.datname,
pss.query, 
pss.calls, 
pss.total_exec_time, 
pss.rows, 
100.0 * pss.shared_blks_hit / nullif(pss.shared_blks_hit + pss.shared_blks_read, 0) AS hit_percent 
FROM pg_stat_statements AS pss
INNER JOIN pg_database AS pd
ON pss.dbid = pd.oid 
ORDER BY pss.total_exec_time DESC
LIMIT 10;

--List queries by total_time & see which query spends most time in the database:

SELECT
pd.datname,
round(pss.total_exec_time*1000)/1000 AS total_time,
pss.query 
FROM pg_stat_statements AS pss
INNER JOIN pg_database AS pd
ON pss.dbid = pd.oid 
ORDER BY pss.total_exec_time DESC
LIMIT 10;

--List queries on 'per execution' basis & try to sample them over time

SELECT 
pd.datname,
pss.queryid, 
pss.query, 
pss.calls, 
pss.total_exec_time/pss.calls, 
pss.rows/pss.calls, 
pss.temp_blks_read/pss.calls, 
pss.temp_blks_written/pss.calls
FROM pg_stat_statements AS pss
INNER JOIN pg_database AS pd
ON pss.dbid = pd.oid 
WHERE pss.calls != 0
ORDER BY pss.total_exec_time DESC
LIMIT 10;

```

### TODO

* Extensions 
	*  edb-as16-system-stats3.x86_64
	* pg_stat_statements
- Check the Archive WAL in all nodes [link](https://knowledge.enterprisedb.com/hc/en-us/articles/13523417119132-WAL-Archiving-Best-practices). 
- failover test scenarios.
- tune database parameters [link](https://www.enterprisedb.com/blog/general-configuration-and-tuning-recommendations-edb-postgres-advanced-server-and-postgresql) [link](https://www.enterprisedb.com/postgres-tutorials/comprehensive-guide-how-tune-database-parameters-and-configuration-postgresql). 
- check auto failover .
- Add references .
- Fill Pause replication from documentation
- tune efm parameters for better failover
- Check the pgbench to check performance 
- Create Slot and remove slots.

- setup barman and monitor it.
- add needed extensions.
- routine maintenance for database. 
- perform the PITR restoration.
- 


