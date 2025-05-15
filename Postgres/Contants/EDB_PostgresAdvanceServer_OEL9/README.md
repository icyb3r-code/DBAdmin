
# EDB PostgreSQL EPAS  HA Cluster 


## System Design

### Diagram

### System Details

| Role      | OS  | Hostname | IP          |   Port    | CPU | RAM |
| :-------- | --- | -------: | ----------- | :-------: | --- | --- |
| Primary   | OL9 |  pgedb01 | 10.10.20.11 |   5444    | 4   | 4   |
| Standby   | OL9 |  pgedb02 | 10.10.20.12 |   5444    | 4   | 4   |
| Standby   | OL9 |  pgedb03 | 10.10.20.13 |   5444    | 4   | 4   |
| pgBouncer | OL9 |  pgbsr01 | 10.10.20.14 | 7800,7809 | 4   | 4   |
| pgBouncer | OL9 |  pgbsr02 | 10.10.20.14 | 7800,7809 | 4   | 4   |

### Used Technologies

- EDB PostgreSQL Advance Server (EPAS)
- Native PostgreSQL Streaming Replication
- EDB FailOver Manager (EFM)
- EDB pgBouncer 


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
hostnamectl set-hostname pgbsr01

# pool node 2 
hostnamectl set-hostname pgbsr02
############################################################

## Update hosts file on all servers: 
############################################################
# using root user of sudo user 
vim /etc/hosts

# added by admin
10.10.20.11     pgedb01
10.10.20.12     pgedb02
10.10.20.13     pgedb03
10.10.20.14     pgbsr01
10.10.20.15     pgbsr02
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
## Create data directory on all three Database servers 
############################################################
# create dircetories using root and change permission and owner
mkdir -p /u01/pg16/pg_data
chown -R enterprisedb:enterprisedb /u01
chmod 755 /u01/pg16
chmod -R 0700 /u01/pg16/pg_data
############################################################

## Install EDB PostgreSQL On All Servers/Nodes:
############################################################
dnf install -y  edb-as16-server
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
############################################################


## Initialize the database on Primary 
############################################################
su - enterprisedb
/usr/edb/as16/bin/initdb -D /u01/pg16/pg_data/

rsync -av /u01/pg16/pg_data/pg_wal /u01/pg16/pg_wal
mv /u01/pg16/pg_data/pg_wal /u01/pg16/pg_data/pg_wal_bkp
ln -s /u01/pg16/pg_wal /u01/pg16/pg_data/pg_wal

############################################################


## Edit Parameters in postgresql.conf on Primary Only 
############################################################
# add here memory parameters adjusments 
add here the paramters you want to change or adjusts

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
psql -h /tmp
edb=# \password
Enter new password for user "enterprisedb": edb1

# update pg_hba.conf with this line to allow this subnet to access postgres server
su - enterprisedb 
vim $PGHBA 
host    all             all             10.10.20.0/24         scram-sha-256

# Restart or reload the edb-as-16 service 
sudo systemctl reload edb-as-16.service 

# or reload using psql
psql -h 172.16.204.11 -p 5444 -U enterprisedb edb -c "SELECT pg_reload_conf();"

# try to connect to database from all nodes using below command to make sure that you have access 
psql -h 10.10.20.11 -p 5444 -U enterprisedb edb 
############################################################

```

### Setup Streaming Replication

```bash

## Create a replication user on primary server 
############################################################
# create user called efm_repl using below command 
su - enterprisedb
psql -h 10.10.20.11 -p 5444 -U enterprisedb edb -c "CREATE ROLE efm_repl REPLICATION LOGIN PASSWORD '3fm_r3pl_123'";
############################################################


## add efm_repl record to pg_hba.conf file to be allowed
############################################################
# add efm_repl record to pg_hba.conf file to be allowed
su - enterprisedb
 vim $PGHBA
host    replication     efm_repl        10.10.20.0/24        scram-sha-256
############################################################


## add the pgpass hidden file to enterprisedb os user home
############################################################
# add the pgpass hidden file to enterprisedb os user home on all node as showen below 
cat > ~/.pgpass << _EOF_
10.10.20.11:5444:*:efm_repl:3fm_r3pl_123
10.10.20.12:5444:*:efm_repl:3fm_r3pl_123
10.10.20.13:5444:*:efm_repl:3fm_r3pl_123
_EOF_

chmod 0600 ~/.pgpass

# check the access to EFM_REPL from all nodes 
psql -U efm_repl -h 10.10.20.11 -p 5444   -c "IDENTIFY_SYSTEM"   replication=1
############################################################


## edit postgresql.conf file to allow replication
############################################################
# edit postgresql.conf file to allow replication and other important parameter on primary only 
vim $PGCONF

# enable replication by uncomment and adjust as per needed 
wal_level = replica
max_wal_senders = 10
max_replication_slots = 5
wal_keep_size = 1024 # increase if the system is busy 
hot_standby = on # open replica for readonly

# postgresql.conf on all nodes to allow sync
# check application.name=edbpg1 
cluster_name = 'edbpg1' # change this per node
synchronous_commit = on   #default if you face issue in performance go with
synchronous_commit = remote_write
synchronous_standby_names = 'ANY 1 (edbpg2, edbpg3)' # this should be on first node
############################################################

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
pg_basebackup -D ${PGDATA} -h 10.10.20.13 -U efm_repl -p 5444  -Xs -R -P

# edit the postgresql.conf 
vim $PGCONF
cluster_name = 'edbpg2' # change this per node
synchronous_standby_names = 'ANY 1 (edbpg1, edbpg3)' # this should be on first node
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
pg_basebackup -D /u01/pg16/pg_data -h 10.10.20.11 -U efm_repl -p 5444  -Xs -R -P

# edit the postgresql.conf 
vim $PGCONF
cluster_name = 'edbpg3' # change this per node
synchronous_standby_names = 'ANY 1 (edbpg1, edbpg2)' # this should be on first node
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

# on 3 nodes remove the enterprisedb password for security
# using root user or sudo 
passwd -d enterprisedb
############################################################
```

### Streaming Replication with Slot

 ✅ **Production Recommendation**

| Feature                         | With Slots (✔ Recommended)        | Without Slots                   |
| ------------------------------- | --------------------------------- | ------------------------------- |
| Resilience to replica downtime  | ✔ High                            | ❌ Low                           |
| WAL disk management             | ❌ Requires monitoring             | ✔ Simpler                       |
| Ease of rejoining after failure | ✔ Automatic resume                | ❌ May require base backup again |
| Operational simplicity          | ❌ Slightly complex                | ✔ Simpler but riskier           |
| Best use case                   | ✔ Long-lived replicas, HA systems | ✔ Ephemeral replicas (dev, QA)  |

```bash
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

```



### Pause the Replication 

https://www.postgresql.org/docs/current/functions-admin.html#FUNCTIONS-RECOVERY-CONTROL-TABLE


```bash

```

### Tune PostgreSQL parameters

#### Referances

- PostgreSQL Performance Tuning: Optimize Your Database Server [link](https://www.enterprisedb.com/postgres-tutorials/introduction-postgresql-performance-tuning-and-optimization)
- Comprehensive Guide on How to Tune Database Parameters [link](https://www.enterprisedb.com/postgres-tutorials/comprehensive-guide-how-tune-database-parameters-and-configuration-postgresql)
- Configure and Tune EPAS and PostgreSQL Database Servers on Linux [link](https://www.enterprisedb.com/blog/general-configuration-and-tuning-recommendations-edb-postgres-advanced-server-and-postgresql)
 
#### Parameters

##### Memory Parameters:

To tune these parameters you need to understand that 
```bash 
shared_buffer # where data stored in RAM
work_mem # use for join sort operations
maintenance_work_mem # for vaccum create indes, add forgien key
autovacuum_work_mem # vacuuming operation 
effective_cache_size # OS caching check how pg memory works 
effective_io_concurrency 
```

 ##### Connection Parameters

Tune below parameter for better connection note that you need to check if your system specs::

```bash
max_connections # max number of concurrent connections
superuser_reserved_connections # number of connection for DBA
```
 
##### Write-Ahead Log

```bash
wal_compression
wal_log_hints
wal_buffers
checkpoint_timeout
checkpoint_completion_target
max_wall_size
archive_mode
archive_command
```

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
psql -h 10.10.20.11 -p 5444 -U enterprisedb edb -f /tmp/efm-role.sql

# once finish remove the file    
rm -f /tmp/efm-role.sql
############################################################



## add hba file entry to allow the efm user to connect 
############################################################
su - enterprisedb
vim $PGHBA
host    all             efm             10.10.20.0/24           scram-sha-256

# try to connect from all nodes  
 psql -h 10.10.20.11 -p 5444 -U efm edb
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

### Configure EFM OS User 

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

### Configure EFM 

```bash
## Create EFM Cluster Password
############################################################
# create export efmpass
su - efm 
export EFMPASS=3fmUs3r123
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
bind.address=10.10.20.11:7800 # for node 1
user.email=username@example.com
from.email=pgedb01@efm-epas # to know its come from node1
notification.text.prefix=[EPAS/EFM]
is.witness=false
encrypt.agent.messages=true
virtual.ip=10.10.20.30
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
bind.address=10.10.20.12:7800 # for node 2
user.email=username@example.com
from.email=pgedb02@efm-epas # to know its come from node1
notification.text.prefix=[EPAS/EFM]
is.witness=false
encrypt.agent.messages=true
virtual.ip=10.10.20.30
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
bind.address=10.10.20.13:7800 # for node 3
user.email=username@example.com
from.email=pgedb03@efm-epas # to know its come from node1
notification.text.prefix=[EPAS/EFM]
is.witness=false
encrypt.agent.messages=true
virtual.ip=10.10.20.30
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
 vim $EFMC 
10.10.20.11:7800 10.10.20.12:7800 10.10.20.13:7800

# allow nodes on primary using efm command 
su - efm 
efm allow-node efm 10.10.20.12
efm allow-node efm 10.10.20.13

# start services on both standby servers 
systemctl enable edb-efm-4.10.service
systemctl start edb-efm-4.10.service

# check the status of cluster using efm command 
su - efm 
efm cluster-status efm 
############################################################

```

### Tune EFM parameters 

## Setup pgBouncer 

### Install pgBouncer

```bash
## Install pgbouncer postgresql client using root or sudo
############################################################
sudo dnf install pgbouncer edb-as16-server-client 
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
sudo firewall-cmd --reloads
sudo firewall-cmd --list-ports
############################################################

## Enable SSH passwordless for enterprisedb OS user
############################################################
# using root or sudo Node 1
passwd enterprisedb
su - enterprisedb
ssh-keygen -t ed25519
ssh-copy-id pgbsr02

# using root or sudo Node 2
passwd enterprisedb
su - enterprisedb
ssh-keygen -t ed25519
ssh-copy-id pgbsr02
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
app_db1 = host=10.10.20.30 port=5444 user=app_user1 dbname=app_db1
logfile = /var/log/edb/pgbouncer1.24/edb-pgbouncer-1.24.log
pidfile = /run/edb/pgbouncer1.24/edb-pgbouncer-1.24.pid
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = md5
auth_file = /etc/edb/pgbouncer1.24/userlist.txt
admin_users = enterprisedb
stats_users = enterprisedb
ignore_startup_parameters = application_name


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

### Monitor pgBouncer

https://www.pgbouncer.org/usage.html

```bash
# connect to pgbouncer db 
psql -h 10.10.20.14 -U enterprisedb -p 6432 -d pgbouncer

```

## Stop & Start Sequence and Best Practice


### Steps to Stop/Start EFM Cluster

in case we are required to stop EFM services  across of all nodes for maintenance purposes `stop-cluster` command will stop all service on all nodes.

```bash
su - efm 
efm stop-cluster efm 
```

### Steps to Stop/Start PostgreSQL & EFM Services

#### Stop On Standby Nodes

- Stop EFM Services
- Stop PostgreSQL Services
#### Stop on Primary Node

- Stop EFM Services
- Stop PostgreSQL services

#### Start on Primary Node

- Start EFM Services
- Start PostgreSQL Service.

#### Start on Standby Nodes

- Start EFM Services.
- Start PostgreSQL Service.


### TODO

- Check the Archive WAL in all nodes [link](https://knowledge.enterprisedb.com/hc/en-us/articles/13523417119132-WAL-Archiving-Best-practices). 
- failover test scenarios.
- tune database parameters [link](https://www.enterprisedb.com/blog/general-configuration-and-tuning-recommendations-edb-postgres-advanced-server-and-postgresql) [link](https://www.enterprisedb.com/postgres-tutorials/comprehensive-guide-how-tune-database-parameters-and-configuration-postgresql). 
- check auto failover .
- Add references .
- Fill Pause replication from documentation
- tune postgresql parameters [link](https://www.enterprisedb.com/postgres-tutorials/introduction-postgresql-performance-tuning-and-optimization) 
- tune pgbouncer parameters 
- tune efm parameters for better failover
- Check the pgbench 
- Create Slot and remove slots 
- Streaming Replication / 



### Organize the postgresql.conf

```bash
###########################################################################
# CONNECTIONS AND AUTHENTICATION
###########################################################################

listen_addresses = '*'             # Listen on all IPs (secure using pg_hba.conf)
port = 5432
max_connections = 500             # Depends on workload and memory
superuser_reserved_connections = 3
password_encryption = scram-sha-256

###########################################################################
# RESOURCE USAGE
###########################################################################

shared_buffers = 8GB              # 25–40% of RAM typically
work_mem = 16MB                   # Per sort/hash operation
maintenance_work_mem = 512MB
effective_cache_size = 24GB      # Roughly 70–80% of total memory

###########################################################################
# WRITE-AHEAD LOGGING (WAL)
###########################################################################

wal_level = replica               # Use 'logical' if needed
wal_compression = on
wal_keep_size = 2GB
archive_mode = on
archive_command = 'cp %p /var/lib/pgsql/wal_archive/%f'
archive_timeout = 60
max_wal_size = 4GB
min_wal_size = 1GB
full_page_writes = on

###########################################################################
# REPLICATION
###########################################################################

max_wal_senders = 10
max_replication_slots = 5
hot_standby = on
wal_sender_timeout = 60s
wal_receiver_timeout = 60s

###########################################################################
# CHECKPOINTS
###########################################################################

checkpoint_timeout = 15min
checkpoint_completion_target = 0.9
checkpoint_warning = 30s

###########################################################################
# QUERY TUNING
###########################################################################

default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
parallel_tuple_cost = 0.1
parallel_setup_cost = 1000
max_parallel_workers = 8
max_parallel_workers_per_gather = 4

###########################################################################
# LOGGING
###########################################################################

logging_collector = on
log_directory = 'pg_log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 0
log_min_duration_statement = 1000     # log slow queries >1s
log_line_prefix = '%t [%p]: [%l-1] db=%d,user=%u '
log_connections = on
log_disconnections = on

###########################################################################
# AUTOVACUUM
###########################################################################

autovacuum = on
log_autovacuum_min_duration = 1000
autovacuum_naptime = 1min
autovacuum_vacuum_threshold = 50
autovacuum_analyze_threshold = 50
autovacuum_vacuum_cost_limit = 2000

###########################################################################
# BACKUP & PITR
###########################################################################

archive_mode = on
archive_command = 'cp %p /var/lib/pgsql/wal_archive/%f'
restore_command = 'cp /var/lib/pgsql/wal_archive/%f %p'

###########################################################################
# CLIENT CONNECTION DEFAULTS
###########################################################################

datestyle = 'iso, mdy'
timezone = 'UTC'
lc_messages = 'en_US.UTF-8'
lc_monetary = 'en_US.UTF-8'
lc_numeric = 'en_US.UTF-8'
lc_time = 'en_US.UTF-8'

###########################################################################
# ERROR HANDLING & MONITORING
###########################################################################

log_checkpoints = on
log_lock_waits = on
deadlock_timeout = 1s

###########################################################################
# CUSTOM EXTENSIONS / MODULES
###########################################################################

shared_preload_libraries = 'pg_stat_statements'   # Or others like timescaledb, auto_explain
pg_stat_statements.max = 10000
pg_stat_statements.track = all

```


Tuned one 

```bash
###########################################################################
# CONNECTIONS AND AUTHENTICATION
###########################################################################

listen_addresses = '*'             # Listen on all IPs (secure using pg_hba.conf)
port = 5432
max_connections = 500             # Depends on workload and memory
superuser_reserved_connections = 3
password_encryption = scram-sha-256

###########################################################################
# RESOURCE USAGE
###########################################################################

shared_buffers = 8GB              # 25–40% of RAM typically
work_mem = 16MB                   # Per sort/hash operation
maintenance_work_mem = 512MB
effective_cache_size = 24GB      # Roughly 70–80% of total memory

###########################################################################
# WRITE-AHEAD LOGGING (WAL)
###########################################################################

wal_level = replica               # Use 'logical' if needed
wal_compression = on
wal_keep_size = 2GB
archive_mode = on
archive_command = 'cp %p /var/lib/pgsql/wal_archive/%f'
archive_timeout = 60
max_wal_size = 4GB
min_wal_size = 1GB
full_page_writes = on

###########################################################################
# REPLICATION
###########################################################################

max_wal_senders = 10
max_replication_slots = 5
hot_standby = on
wal_sender_timeout = 60s
wal_receiver_timeout = 60s

###########################################################################
# CHECKPOINTS
###########################################################################

checkpoint_timeout = 15min
checkpoint_completion_target = 0.9
checkpoint_warning = 30s

###########################################################################
# QUERY TUNING
###########################################################################

default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
parallel_tuple_cost = 0.1
parallel_setup_cost = 1000
max_parallel_workers = 8
max_parallel_workers_per_gather = 4

###########################################################################
# LOGGING
###########################################################################

logging_collector = on
log_directory = 'pg_log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 0
log_min_duration_statement = 1000     # log slow queries >1s
log_line_prefix = '%t [%p]: [%l-1] db=%d,user=%u '
log_connections = on
log_disconnections = on

###########################################################################
# AUTOVACUUM
###########################################################################

autovacuum = on
log_autovacuum_min_duration = 1000
autovacuum_naptime = 1min
autovacuum_vacuum_threshold = 50
autovacuum_analyze_threshold = 50
autovacuum_vacuum_cost_limit = 2000

###########################################################################
# BACKUP & PITR
###########################################################################

archive_mode = on
archive_command = 'cp %p /var/lib/pgsql/wal_archive/%f'
restore_command = 'cp /var/lib/pgsql/wal_archive/%f %p'

###########################################################################
# CLIENT CONNECTION DEFAULTS
###########################################################################

datestyle = 'iso, mdy'
timezone = 'UTC'
lc_messages = 'en_US.UTF-8'
lc_monetary = 'en_US.UTF-8'
lc_numeric = 'en_US.UTF-8'
lc_time = 'en_US.UTF-8'

###########################################################################
# ERROR HANDLING & MONITORING
###########################################################################

log_checkpoints = on
log_lock_waits = on
deadlock_timeout = 1s

###########################################################################
# CUSTOM EXTENSIONS / MODULES
###########################################################################

shared_preload_libraries = 'pg_stat_statements'   # Or others like timescaledb, auto_explain
pg_stat_statements.max = 10000
pg_stat_statements.track = all

```

