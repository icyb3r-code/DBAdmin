# Setup Postgres Cluster (REPMGR)

## Overview 

OS: Oracle Linux 8
Postgres: PostgreSQL 16.2
REPMGR: repmgr16


## Setup Hostname (ALL)

Add the `hostname` you prefer using below command:

```bash
# add hostname 
 sudo hostnamectl set-hostname oel8-pg1
 sudo hostnamectl set-hostname oel8-pg2

# add to entry to hosts file 
 cat /etc/hosts
 sudo echo '10.10.200.7    oel8-pg2' >> /etc/hosts
 sudo echo '10.10.200.6    oel8-pg1' >> /etc/hosts
 cat /etc/hosts

```


## Install PostgreSQL & RepMGR (ALL)


```bash
# Install the repository RPM:
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# Disable the built-in PostgreSQL module:
sudo dnf -qy module disable postgresql

# Install PostgreSQL:
sudo dnf install -y postgresql16-server

# install replication manager 
sudo dnf install repmgr_16
```

### Get the Data & Config locations (Primary Only)

```bash
# get the location of data_directory from postgres
su - postgres
psql
psql (16.2)
postgres=# show config_file;
 /var/lib/pgsql/data/postgresql.conf

postgres=# show data_directory;
 /var/lib/pgsql/data
```

### Stop Postgres Systemd Service (Primary Only)

Stop the `postgresql-16` `systemd` service:

```bash
# postgres stop service 
systemctl start postgresql-16.service

```

### Create New Location (ALL)

```bash
# create new location on all nodes for data directory using root
mkdir -p /u01/pgdata
chown -R postgres:postgres /u01
chmod -R 700 /u01/pgdata
```

### Move Data to New Location (Primary Only)

```bash
su - postgres
rsync -av /var/lib/pgsql/data/ /u01/pgdata/data
```

### Add New Location To Config (Primary Only)

```bash
vim /u01/pgdata/data/postgresql.conf

# add this line 
data_directory = '/u01/pgdata/data'
```

### Edit the Postgres Systemd service (ALL)

```bash
# Edit systemd service 
vim  /lib/systemd/system/postgresql-16.service

### edit this line 
# Location of database directory
Environment=PGDATA=/u01/pgdata/data

## disable and enable service 
systemctl disable postgresql-16
systemctl enable postgresql-16

# start service & check status 
systemctl start postgresql-16.service
systemctl status postgresql-16.service
```

### Check Configuration Taken (Primary Only)

```bash
su - postgres
psql
postgres=# show config_file;
 /u01/pgdata/data/postgresql.conf

postgres=# show data_directory;
 /u01/pgdata/data
```

## Initialize Database (Primary Only)

```bash
# only on primary initialize the database
sudo /usr/pgsql-16/bin/postgresql-16-setup initdb -D /u01/pgdata/data
```

## Change Data Directory (ALL)

## Edit PostgreSQL Configuration (Primary Only)

Edit the `postgresql.conf` configuration file: 

```bash
mv /u01/pgdata/data/postgresql.conf /u01/pgdata/data/postgresql.conf.bkp
grep -v '^#'/u01/pgdata/data/postgresql.conf.bkp | grep '^[A-Za-z0-9]' > /u01/pgdata/data/postgresql.conf
chown postgres:postgres /u01/pgdata/data/postgresql.conf

vim /u01/pgdata/data/postgresql.conf
# add below configuration

listen_addresses = '0.0.0.0' # ipv4 only 
max_wal_senders = 10
max_replication_slots = 10
wal_level = 'replica' # or 'hot_standby' or 'logical'
hot_standby = on
archive_mode = on
archive_command = '/bin/true'
shared_preload_libraries = 'repmgr'
wal_log_hints = on

# start service
sudo systemctl enable --now postgresql-16
sudo systemctl status postgresql-16
```

Edit the `pg_hba.conf` configuration file: 

```bash
vim //u01/pgdata/data/pg_hba.conf
# TYPE  DATABASE        USER            ADDRESS          METHOD
host    replication     repmgr          10.10.200.0/24   trust
host    repmgr          repmgr          10.10.200.0/24   trust
```
## Create RepMGR User & Database (Primary Only)

```bash
su - postgres
createuser -s repmgr
createdb repmgr -O repmgr 

# or 
su - postgres
psql -c "CREATE USER repmgr WITH REPLICATION;"
psql -c "CREATRE DATABASE repmgr OWNER repmgr"
```

## Allow Postgres Port on Firewall (ALL)

```bash
# need sudo or root user 
firewall-cmd --add-port=5432/tcp --permanent --zone=public
firewall-cmd --reload
firewall-cmd --list-ports
```

## Configure RepMGR (ALL)

Backup the original file:

```bash 
mv /etc/repmgr/16/repmgr.conf /etc/repmgr/16/repmgr.conf.bkp
```

### On primary

You need to make sure that below parameters have correct value to do so you need to edit below parameters accordingly:
* node_id
* node_name
* conninfo
* data_direcotry
* pg_bindir
* promote_command
* follow_command
* repmgrd_service_start_command
* repmgrd_service_stop_command
* service_start_command
* service_stop_command
* service_restart_command
* service_reload_command

**Simple Config**:

```bash
vim /etc/repmgr/16/repmgr.conf
node_id=1
node_name=oel8-pg1
conninfo='host=oel8-pg1 user=repmgr dbname=repmgr connect_timeout=2'
data_directory='/var/lib/pgsql/data'
failover=automatic
promote_command='repmgr -f /etc/repmgr/16/repmgr.conf standby promote'
follow_command='repmgr -f /etc/repmgr/16/repmgr.conf standby follow'
```

**Advanced Config**:

```bash
vim /etc/repmgr/16/repmgr.conf
node_id=1
node_name='oel8-pg1'
conninfo='host=oel8-pg1 port = 5432 user=repmgr dbname=repmgr connect_timeout=2'
data_directory='/u01/pgdata/data' ## chamge this
pg_bindir='/usr/pgsql-16/bin/'
ssh_options='-q -o ConnectTimeout=10'
failover=automatic
promote_command='/usr/pgsql-16/bin/repmgr standby promote -f /etc/repmgr/16/repmgr.conf --log-to-file'
follow_command='/usr/pgsql-16/bin/repmgr standby follow -f /etc/repmgr/16/repmgr.conf --log-to-file --upstream-node-id=%n'
use_replication_slots=true
connection_check_type='ping'
log_file='/var/log/repmgr/repmgr.log'
monitoring_history=yes
log_status_interval=60
primary_visibility_consensus=true
repmgrd_service_start_command='sudo /usr/bin/systemctl start repmgr-16.service'
repmgrd_service_stop_command='sudo /usr/bin/systemctl stop repmgr-16.service'
service_start_command='sudo /usr/bin/systemctl start postgresql-16.service'
service_stop_command='sudo /usr/bin/systemctl stop postgresql-16.service'
service_restart_command='sudo /usr/bin/systemctl restart postgresql-16.service'
service_reload_command='sudo /usr/bin/systemctl reload postgresql-16.service'
```

### On Standby

**Simple**

```bash
vim /etc/repmgr/16/repmgr.conf
node_id=2
node_name=oel8-pg2
conninfo='host=oel8-pg2 user=repmgr dbname=repmgr connect_timeout=2'
data_directory='/var/lib/pgsql/data'
failover=automatic
promote_command='/usr/pgsql-16/bin/repmgr -f /etc/repmgr/16/repmgr.conf standby promote'
follow_command='/usr/pgsql-16/bin/repmgr -f /etc/repmgr/16/repmgr.conf standby follow'
```

**Advanced Config**:

```bash
vim /etc/repmgr/16/repmgr.conf
node_id=2
node_name='oel8-pg2'
conninfo='host=oel8-pg2 port = 5432 user=repmgr dbname=repmgr connect_timeout=2'
data_directory='/u01/pgdata/data' ## chamge this
pg_bindir='/usr/pgsql-16/bin/'
ssh_options='-q -o ConnectTimeout=10'
failover=automatic
promote_command='/usr/pgsql-16/bin/repmgr standby promote -f /etc/repmgr/16/repmgr.conf --log-to-file'
follow_command='/usr/pgsql-16/bin/repmgr standby follow -f /etc/repmgr/16/repmgr.conf --log-to-file --upstream-node-id=%n'
use_replication_slots=true
connection_check_type='ping'
log_file='/var/log/repmgr/repmgr.log'
monitoring_history=yes
log_status_interval=60
primary_visibility_consensus=true
repmgrd_service_start_command='sudo /usr/bin/systemctl start repmgr-16.service'
repmgrd_service_stop_command='sudo /usr/bin/systemctl stop repmgr-16.service'
service_start_command='sudo /usr/bin/systemctl start postgresql-16.service'
service_stop_command='sudo /usr/bin/systemctl stop postgresql-16.service'
service_restart_command='sudo /usr/bin/systemctl restart postgresql-16.service'
service_reload_command='sudo /usr/bin/systemctl reload postgresql-16.service'
```


## Add Postgres Bin Dir to Postgres User PATH (ALL)

Add the postgres `bin` directory to the `PATH` so you can run command directly from terminal: 

```bash
su - postgres
vim .bash_profile
export PATH=/usr/pgsql-16/bin:$PATH
# or 
echo "export PATH=/usr/pgsql-16/bin:\$PATH" >> .bash_profile
exit
```

## Register Primary Node (Primary Only)

```bash
# using postgres
su - postgres
repmgr primary register

#using root
sudo -u postgres /usr/pgsql-16/bin/repmgr -f /etc/repmgr/16/repmgr.conf primary register
```

Output

![](./attachments/Pasted%20image%2020240429133722.png)

```bash
repmgr cluster show
repmgr cluster event
repmgr cluster crosscheck
```

Output

![](./attachments/Pasted%20image%2020240429133637.png)

Output

![](attachments/Pasted%20image%2020240429133806.png)

## Clone & Register Standby Node (Standby Only)

```bash
# try the dry run from standby node 
 sudo -u postgres /usr/pgsql-16/bin/repmgr -h oel8-pg1 -U repmgr -d repmgr standby clone --dry-run

# you should revieved below message 
INFO: all prerequisites for "standby clone" are met

# clone the primary to standby server
sudo -u postgres /usr/pgsql-16/bin/repmgr -h oel8-pg1 -U repmgr -d repmgr standby clone

# the output 
INFO: executing:
  /usr/pgsql-16/bin/pg_basebackup -l "repmgr base backup"  -D /u01/pgdata/data -h oel8-pg1 -p 5432 -U repmgr -X stream
NOTICE: standby clone (using pg_basebackup) complete
NOTICE: you can now start your PostgreSQL server
HINT: for example: sudo /usr/bin/systemctl start postgresql-16.service
HINT: after starting the server, you need to register this standby with "repmgr standby register"
```

Start Postgres service on standby server

```bash
# start the service 
systemct enable postgresql-16
systemct start postgresql-16

# register the standby 
su - postgres
repmgr standby register

# output 
NOTICE: standby node "oel8-pg2" (ID: 2) successfully registered
```

## Passwordless SSH connectivity (ALL)

```bash
su - postgres
ssh-keygen -t ed25519
vim /var/lib/pgsql/.ssh

# using root user on all nodes 
passwd postgres

# use copy id  on all nodes 
# node 1
su - postgres
ssh-copy-id postgres@oel8-pg2

# node 2 
su - postgres
ssh-copy-id postgres@oel8-pg1

```

## Grant Postgres Privilege to control service (ALL) 

```bash
# add below file to sudoers using root  
sudo visudo -f /etc/sudoers.d/postgres

# Allow postgres user to manage postgresql-16.service
postgres ALL=(ALL) NOPASSWD: /bin/systemctl start postgresql-16.service, \
                               /bin/systemctl stop postgresql-16.service, \
                               /bin/systemctl reload postgresql-16.service, \
                               /bin/systemctl restart postgresql-16.service, \
                               /bin/systemctl status postgresql-16.service

# Allow postgres user to manage repmgr-16.service
postgres ALL=(ALL) NOPASSWD: /bin/systemctl start repmgr-16.service, \
                               /bin/systemctl stop repmgr-16.service, \
                               /bin/systemctl reload repmgr-16.service, \
                               /bin/systemctl restart repmgr-16.service, \
                               /bin/systemctl status repmgr-16.service


# No secure : add postgres to wheel group 
sudo usermod -aG wheel postgres
visudo
##### comment and uncomment samilar to below editing
## Allows people in group wheel to run all commands
# %wheel        ALL=(ALL)       ALL

## Same thing without a password
%wheel  ALL=(ALL)       NOPASSWD: ALL

# you can remove postgres from wheel group 
# check the groups 
groups postgres

gpasswd -d postgres wheel 


```


## RepMGR Commands 

You can find all the commands under this [link](https://www.repmgr.org/docs/5.3/index.html)

![](./attachments/Pasted%20image%2020240502003917.png)

## Scenarios & Test-Cases 

### Switchover 

```bash
# from standby server or node 
# --sbiligs-follow if you have more than on standby
repmgr standby switchover --siblings-follow --dry-run 

```

### Failover

```bash

# make sure the service ready for automatic failover 
repmgr service status 

# if the pausing is yes make it no 
repmgr service unpause 

# stop service on primary the standby will be promoted
sudo systemctl stop postgresql-16 
```

### Rejoined Failed Node

```bash
# on old primary 
repmgr node rejoin -d "host=oel8-pg1 port=5432 user=repmgr dbname=repmgr connect_timeout=2" --force-rewind --verbose --dry-run 
```

# Add HAProxy 

```bash
sudo dnf install haproxy
```

```bash
sudo dnf install lib
```