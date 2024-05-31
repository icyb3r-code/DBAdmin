# Setup Postgres Cluster (REPMGR)


## Lab Overview 

This lab will help you to setup and configure a PostgreSQL 16.2, RepMGR 16, HAProxy and Keepalived  on three nodes, to reach the PostgreSQL database high availability.

Requirements:
* Oracle Linux 9 Three Nodes as Servers.
* PostgreSQL 16.2.
*  RepMGR 16.
* Oracle Linux 9 as Client 

| Server  | IP           | PG_Port | VIP          | RO_Port | RW_Port |
| ------- | ------------ | ------- | ------------ | ------- | ------- |
| ol8-pg1 | 10.10.200.10 | 5432    | 10.10.200.20 | 5001    | 5000    |
| ol8-pg2 | 10.10.200.11 | 5432    | 10.10.200.20 | 5001    | 5000    |
| ol8-pg3 | 10.10.200.12 | 5432    | 10.10.200.20 | 5001    | 5000    |

![](attachments/Postgres_full_arch.gif)

## Prepare Nodes VMs

### Create Virtualbox Node Install OL9 

Follow this video link on my YouTube channel in order to create a VM and setup Oracle linux 9 server.

### Clone OL9 
Follow this video link on my YouTube channel in order to clone the VM to more 2 VM total 3 VMs. 

### Setup Static IP (ALL)

Follow the Youtube video link to assign Static IP address to 3 nodes.

### Setup Hostname (ALL)

Add the `hostname` you prefer using below command:

```bash
# add hostname 
 sudo hostnamectl set-hostname ol8-pg1
 sudo hostnamectl set-hostname ol8-pg2
 sudo hostnamectl set-hostname ol8-pg3
# add to entry to hosts file 
 cat /etc/hosts
 sudo echo '10.10.200.10    ol8-pg2' >> /etc/hosts
 sudo echo '10.10.200.11    ol8-pg1' >> /etc/hosts
 sudo echo '10.10.200.12    ol8-pg3' >> /etc/hosts
 cat /etc/hosts

```

### Access Nodes using SSH

Follow this video link on my YouTube channel in order to forward the ssh port to host OS. use any ssh client to access servers.
## Install & Configure PostgreSQL

### Install PostgreSQL (ALL)

```bash
# Install the repository RPM:
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm  

# Disable the built-in PostgreSQL module:
sudo dnf -qy module disable postgresql

# Install PostgreSQL:
sudo dnf install -y postgresql16-server
```

### Create New Location (ALL)

```bash
# create new location on all nodes for data directory using root
mkdir -p /u01/pgdata/data
chown -R postgres:postgres /u01
chmod -R 700 /u01/pgdata
```

### Initialize Database (Primary Only)

The `PGDATA` is an environment variable to set PostgreSQL data directory path location, in this setup the location path is `/u01/pgdata/data` 

```bash
# only on primary initialize the database
sudo PGDATA=/u01/pgdata/data /usr/pgsql-16/bin/postgresql-16-setup initdb 
```

### Migrate Data to New Location (Primary Only)

You can follow below steps to migrate initialized PostgreSQL with the default location to new location. If you are okay with the default location of PostgreSQL **you can skip this part**, below step by step data directory migration:

**Get Data directory and Config file location (Primary Only)**:

```bash
# get the location of data_directory from postgres
su - postgres
psql
psql (16.2)
postgres=# show config_file;
 /var/lib/pgsql/16/data/postgresql.conf

postgres=# show data_directory;
 /var/lib/pgsql/16/data
```

**Stop Postgres Systemd Service (Primary Only)**

Stop the `postgresql-16` `systemd` service:

```bash
# postgres stop service 
systemctl start postgresql-16.service
# if enabled you need to disable it
systemctl disable postgresql-16.service
```

**Move Data to New Location (Primary Only)**

```bash
su - postgres
rsync -av /var/lib/pgsql/16/data/ /u01/pgdata/data
```

**Add New Location To Config (Primary Only)**

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

# Enable the postgreSQL to startup automatically  
systemctl enable postgresql-16

# to enable and start in one command 
systemctl enable --now postgresql-16

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

### Configure PostgreSQL (Primary Only)

Edit the `postgresql.conf` configuration file: 

```bash
mv /u01/pgdata/data/postgresql.conf /u01/pgdata/data/postgresql.conf.bkp
grep -v '^#' /u01/pgdata/data/postgresql.conf.bkp | grep '^[A-Za-z0-9]' > /u01/pgdata/data/postgresql.conf
chown postgres:postgres /u01/pgdata/data/postgresql.conf

vim /u01/pgdata/data/postgresql.conf
# add below configuration

listen_addresses = '0.0.0.0' # ipv4 only 
max_wal_senders = 10
max_replication_slots = 10
wal_level = 'replica' #  or 'logical'
hot_standby = on
archive_mode = on
archive_command = '/bin/true'
shared_preload_libraries = 'repmgr'
wal_log_hints = on

# start service and enable the service
sudo systemctl enable postgresql-16
sudo systemctl start postgresql-16
sudo systemctl status postgresql-16
```

### Add Postgres Bin Dir to Postgres User PATH (ALL)

Add the postgres `bin` directory to the `PATH` so you can run command directly from terminal: 

```bash
su - postgres
sed -i "s/PGDATA=.*/PGDATA=\/u01\/pgdata\/data/" .bash_profile
vim .bash_profile
export PATH=/usr/pgsql-16/bin:$PATH
# or 
echo "export PATH=/usr/pgsql-16/bin:\$PATH" >> .bash_profile
exit
```

### Allow Postgres Port on Firewall (ALL)

```bash
# need sudo or root user 
firewall-cmd --add-port=5432/tcp --permanent --zone=public
firewall-cmd --reload
firewall-cmd --list-ports
```

## Install & Configure RepMGR

### Install RepMGR (ALL)

```bash
# install replication manager 
sudo dnf install repmgr_16
```


### Create RepMGR User & Database (Primary Only)

```bash
su - postgres
createuser -s repmgr
createdb repmgr -O repmgr 

# or need to be checked 
su - postgres
psql -c "CREATE USER repmgr WITH SUPERUSER;"
psql -c "CREATRE DATABASE repmgr OWNER repmgr"
```

### Edit PG_HBA File (Primary Only)

Edit the `pg_hba.conf` configuration file: 

```bash
vim /u01/pgdata/data/pg_hba.conf
# TYPE  DATABASE        USER            ADDRESS          METHOD
host    replication     repmgr          10.10.200.0/24   trust
host    repmgr          repmgr          10.10.200.0/24   trust
```


### Configure RepMGR (ALL)

Backup the original file:

```bash 
mv /etc/repmgr/16/repmgr.conf /etc/repmgr/16/repmgr.conf.bkp
```

#### On primary

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
node_name=ol8-pg1
conninfo='host=ol8-pg1 user=repmgr dbname=repmgr connect_timeout=2'
data_directory='/var/lib/pgsql/16/data'
failover=automatic
promote_command='repmgr -f /etc/repmgr/16/repmgr.conf standby promote'
follow_command='repmgr -f /etc/repmgr/16/repmgr.conf standby follow'
```

**Advanced Config**:

```bash
vim /etc/repmgr/16/repmgr.conf
node_id=1
node_name='ol8-pg1'
conninfo='host=ol8-pg1 port = 5432 user=repmgr dbname=repmgr connect_timeout=2'
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

#### On Standby Nodes

**Simple**

```bash
vim /etc/repmgr/16/repmgr.conf
node_id=2
node_name=ol8-pg2
conninfo='host=ol8-pg2 user=repmgr dbname=repmgr connect_timeout=2'
data_directory='/u01/pg_data/data'
failover=automatic
promote_command='/usr/pgsql-16/bin/repmgr -f /etc/repmgr/16/repmgr.conf standby promote'
follow_command='/usr/pgsql-16/bin/repmgr -f /etc/repmgr/16/repmgr.conf standby follow'
```

```bash
vim /etc/repmgr/16/repmgr.conf
node_id=3
node_name=ol8-pg3
conninfo='host=ol8-pg3 user=repmgr dbname=repmgr connect_timeout=2'
data_directory='/u01/pg_data/data'
failover=automatic
promote_command='/usr/pgsql-16/bin/repmgr -f /etc/repmgr/16/repmgr.conf standby promote'
follow_command='/usr/pgsql-16/bin/repmgr -f /etc/repmgr/16/repmgr.conf standby follow'
```

**Advanced Config**:

```bash
vim /etc/repmgr/16/repmgr.conf
node_id=2
node_name='ol8-pg2'
conninfo='host=ol8-pg2 port = 5432 user=repmgr dbname=repmgr connect_timeout=2'
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

```bash
vim /etc/repmgr/16/repmgr.conf
node_id=3
node_name='ol8-pg3'
conninfo='host=ol8-pg3 port = 5432 user=repmgr dbname=repmgr connect_timeout=2'
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



### Register Primary Node (Primary Only)

```bash
# using postgres
su - postgres
repmgr primary register

#using root
sudo -u postgres /usr/pgsql-16/bin/repmgr -f /etc/repmgr/16/repmgr.conf primary register
```

Output

![](attachments/Pasted%20image%2020240429133722.png)

```bash
repmgr cluster show
repmgr cluster event
repmgr cluster crosscheck
```

Output

![](attachments/Pasted%20image%2020240429133637.png)

Output

![](attachments/Pasted%20image%2020240429133806.png)

### Clone & Register Standby Node (Standby Only)

```bash
# try the dry run from standby node 
 sudo -u postgres /usr/pgsql-16/bin/repmgr -h ol8-pg1 -U repmgr -d repmgr standby clone --dry-run

# you should revieved below message 
INFO: all prerequisites for "standby clone" are met

# clone the primary to standby server
sudo -u postgres /usr/pgsql-16/bin/repmgr -h ol8-pg1 -U repmgr -d repmgr standby clone

# the output 
INFO: executing:
  /usr/pgsql-16/bin/pg_basebackup -l "repmgr base backup"  -D /u01/pgdata/data -h ol8-pg1 -p 5432 -U repmgr -X stream
NOTICE: standby clone (using pg_basebackup) complete
NOTICE: you can now start your PostgreSQL server
HINT: for example: sudo /usr/bin/systemctl start postgresql-16.service
HINT: after starting the server, you need to register this standby with "repmgr standby register"
```

Start Postgres service on standby server

```bash
# start the service and enable the service  
systemct enable postgresql-16
systemct start postgresql-16

# register the standby 
su - postgres
repmgr standby register

# output 
NOTICE: standby node "ol8-pg2" (ID: 2) successfully registered
```

### Passwordless SSH connectivity (ALL)

```bash
su - postgres
ssh-keygen -t ed25519
vim /var/lib/pgsql/.ssh

# using root user on all nodes 
passwd postgres

# use copy id  on all nodes 
# node 1
su - postgres
ssh-copy-id postgres@ol8-pg2

# node 2 
su - postgres
ssh-copy-id postgres@ol8-pg1

# using root remove password
passwd -d postgres

```

### Grant PostgreSQL Privilege to control services (ALL) 

```bash
# add below file to sudoers using root  
sudo visudo -f /etc/sudoers.d/postgres

# Allow postgres user to manage postgresql-16.service
postgres ALL=(ALL) NOPASSWD: /usr/bin/systemctl start postgresql-16.service, \
                               /usr/bin/systemctl stop postgresql-16.service, \
                               /usr/bin/systemctl reload postgresql-16.service, \
                               /usr/bin/systemctl restart postgresql-16.service, \
                               /usr/bin/systemctl status postgresql-16.service

# Allow postgres user to manage repmgr-16.service
postgres ALL=(ALL) NOPASSWD: /usr/bin/systemctl start repmgr-16.service, \
                               /usr/bin/systemctl stop repmgr-16.service, \
                               /usr/bin/systemctl reload repmgr-16.service, \
                               /usr/bin/systemctl restart repmgr-16.service, \
                               /usr/bin/systemctl status repmgr-16.service


# Not secure : add postgres to wheel group 
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


### RepMGR Commands 

You can find all the commands under this [link](https://www.repmgr.org/docs/5.3/index.html)

![](attachments/Pasted%20image%2020240502003917.png)

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
repmgr node rejoin -d "host=ol8-pg1 port=5432 user=repmgr dbname=repmgr connect_timeout=2" --force-rewind --verbose --dry-run 
```

## Setup HAProxy  (ALL)

### Install HAProxy (ALL)

```bash
sudo dnf install haproxy
```

Install the `postgresql-16` if you are setup HAProxy service not on PostgreSQL servers:

```bash
sudo dnf install postgresql-16
```

### Configure HAProxy (ALL)

```bash
mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.orig
```

```bash
su - postgres
psql
```

```sql
CREATE USER haproxy WITH PASSWORD 'mypassword';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO haproxy;
GRANT CONNECT ON DATABASE postgres TO haproxy;
```

```bash 
/u01/pgdata/data/pg_hba.conf
host    postgres        haproxy      10.10.200.0/24      trust
```

```bash
# connect to haproxy user 
psql -h ol8-pg1 -U haproxy -d postgres
```

To generate a HAProxy configuration file, you can check this GitHub Repo [link](https://github.com/gplv2/haproxy-postgresql) which allow you using python script to create a PostgreSQL HAProxy configuration automatically, below my HAProxy configuration feel free to edit and use it as well:

```bash
sudo vim /etc/haproxy/haproxy.cfg

# add below config to the haproxy.cfg file 

global
		log /dev/log    local0 info alert
		log /dev/log    local1 notice alert
        stats socket /var/lib/haproxy/admin.sock mode 660 level admin expose-fd listeners
        stats timeout 30s
        user haproxy
        group haproxy
        daemon

        # Default SSL material locations
        ca-base /etc/ssl/certs
        crt-base /etc/ssl/private

        # See: https://ssl-config.mozilla.org/#server=haproxy&server-version=2.0.3&config=intermediate
        ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
        ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

        # Stuff for ol8-pg
        maxconn 100
        external-check
        #insecure-fork-wanted

defaults
        log     global
        mode    tcp
        retries 2
        option  dontlognull
        timeout connect 4s
        timeout client  50000
        timeout server  50000
        timeout check 5s
#        errorfile 400 /etc/haproxy/errors/400.http
#        errorfile 403 /etc/haproxy/errors/403.http
#        errorfile 408 /etc/haproxy/errors/408.http
#        errorfile 500 /etc/haproxy/errors/500.http
#        errorfile 502 /etc/haproxy/errors/502.http
#        errorfile 503 /etc/haproxy/errors/503.http
#        errorfile 504 /etc/haproxy/errors/504.http


listen stats
        mode http
        bind *:7000
        stats enable
        stats refresh 5s
        stats uri /

frontend frontend_readwrite
         mode tcp
        bind *:5000

        acl pg_single_master nbsrv(backend_readwrite) eq 1
        tcp-request connection reject if !pg_single_master
       default_backend backend_readwrite

frontend frontend_readonly
        mode tcp
        bind *:5001

        default_backend backend_readonly

backend backend_readwrite
        option tcp-check
        tcp-check connect

# user: haproxy
# database: postgres
#
        tcp-check send-binary 00000028                 # packet length     ( 4 bytes )
        tcp-check send-binary 00030000                 # protocol version  ( 4 bytes )
        tcp-check send-binary 7573657200               # "user"            ( 5 bytes )
        tcp-check send-binary 686170726f787900         # "haproxy"         ( 8 bytes )
        tcp-check send-binary 646174616261736500       # "database"        ( 9 bytes )
        tcp-check send-binary 706f73746772657300       # "postgres"        ( 9 bytes )
        tcp-check send-binary 00                       # terminator        ( 1 byte )

# expect: Auth
#
        tcp-check expect binary 52                     # Auth request
        tcp-check expect binary 00000008               # packet length     ( 8 bytes )
        tcp-check expect binary 00000000               # auth response ok

# write: run simple query
# "select pg_is_in_recovery();"
#
        tcp-check send-binary 51                       # simple query
        tcp-check send-binary 00000020                 # packet length     ( 4 bytes)
        tcp-check send-binary 73656c65637420           # "select "         ( 7 bytes )
        tcp-check send-binary 70675f69735f696e5f7265636f7665727928293b    # "pg_is_in_recovery();"  ( 20 bytes )
        tcp-check send-binary 00 # terminator                                 ( 1 byte )


    # write: terminate session
        tcp-check send-binary 58                       # Termination packet
        tcp-check send-binary 00000004                 # packet length: 4 (no body)
    # avoids :  <template1-pgc-2019-01-18 11:23:06 CET>LOG:  could not receive data from client: Connection reset by peer

# expect: Row description packet
#
        tcp-check expect binary 54                         # row description packet (1 byte)
        tcp-check expect binary 0000002a               # packet length: 42 (0x2a)
        tcp-check expect binary 0001                   # field count: 1
        tcp-check expect binary 70675f69735f696e5f7265636f7665727900 # field name: pg_is_in_recovery
        tcp-check expect binary 00000000               # table oid: 0
        tcp-check expect binary 0000                   # column index: 0
        tcp-check expect binary 00000010               # type oid: 16
         tcp-check expect binary 0001                   # column length: 1
        tcp-check expect binary ffffffff               # type modifier: -1
        tcp-check expect binary 0000                   # format: text

# expect: query result data
#
# "f" means node in master mode               66h
# "t" means node in standby mode (read-only)  74h
#
        tcp-check expect binary 44                     # data row packet
        tcp-check expect binary 0000000b               # packet lenght: 11 (0x0b)
        tcp-check expect binary 0001                   # field count: 1
        tcp-check expect binary 00000001               # column length in bytes: 1
        tcp-check expect binary 66                     # column data, "f"

# write: terminate session
        tcp-check send-binary 58                       # Termination packet
        tcp-check send-binary 00000004                 # packet length: 4 (no body)

        default-server on-marked-down shutdown-sessions

        server ol8-pg1 ol8-pg1:5432 check inter 5000 fastinter 2000 downinter 5000 rise 2 fall 3
        server ol8-pg2 ol8-pg2:5432 check inter 5000 fastinter 2000 downinter 5000 rise 2 fall 3
        server ol8-pg3 ol8-pg3:5432 check inter 5000 fastinter 2000 downinter 5000 rise 2 fall 3

backend backend_readonly
        option tcp-check
        tcp-check connect

# user: pgc
# database: template1
#
        tcp-check send-binary 00000028                 # packet length     ( 4 bytes )
        tcp-check send-binary 00030000                 # protocol version  ( 4 bytes )
        tcp-check send-binary 7573657200               # "user"            ( 5 bytes )
        tcp-check send-binary 686170726f787900         # "haproxy"         ( 8 bytes )
        tcp-check send-binary 646174616261736500       # "database"        ( 9 bytes )
        tcp-check send-binary 706f73746772657300       # "ol8-pg"        ( 9 bytes )
        tcp-check send-binary 00                       # terminator        ( 1 byte )

# expect: Auth
#
        tcp-check expect binary 52                     # Auth request
        tcp-check expect binary 00000008               # packet length     ( 8 bytes )
        tcp-check expect binary 00000000               # auth response ok

# write: run simple query
# "select pg_is_in_recovery();"
#
        tcp-check send-binary 51                       # simple query
        tcp-check send-binary 00000020                 # packet length     ( 4 bytes)
        tcp-check send-binary 73656c65637420           # "select "         ( 7 bytes )
    # "pg_is_in_recovery();"
        tcp-check send-binary 70675f69735f696e5f7265636f7665727928293b    #   ( 20 bytes )
        tcp-check send-binary 00 # terminator                                 ( 1 byte )

    # write: terminate session
        tcp-check send-binary 58                       # Termination packet
        tcp-check send-binary 00000004                 # packet length: 4 (no body)
    # avoids :  <template1-pgc-2019-01-18 11:23:06 CET>LOG:  could not receive data from client: Connection reset by peer

# expect: Row description packet
#
        tcp-check expect binary 54                         # row description packet (1 byte)
        tcp-check expect binary 0000002a               # packet length: 42 (0x2a)
        tcp-check expect binary 0001                   # field count: 1
        tcp-check expect binary 70675f69735f696e5f7265636f7665727900 # field name: pg_is_in_recovery
        tcp-check expect binary 00000000               # table oid: 0
        tcp-check expect binary 0000                   # column index: 0
        tcp-check expect binary 00000010               # type oid: 16
        tcp-check expect binary 0001                   # column length: 1
        tcp-check expect binary ffffffff               # type modifier: -1
        tcp-check expect binary 0000                   # format: text

# expect: query result data
#
# "f" means node in master mode               66h
# "t" means node in standby mode (read-only)  74h
#
        tcp-check expect binary 44                     # data row packet
        tcp-check expect binary 0000000b               # packet lenght: 11 (0x0b)
        tcp-check expect binary 0001                   # field count: 1
        tcp-check expect binary 00000001               # column length in bytes: 1
        tcp-check expect binary 74                     # column data, "t"

# write: terminate session
        tcp-check send-binary 58                       # Termination packet
        tcp-check send-binary 00000004                 # packet length: 4 (no body)

        default-server on-marked-down shutdown-sessions

        server ol8-pg1 ol8-pg1:5432 check inter 5000 fastinter 2000 downinter 5000 rise 2 fall 3
        server ol8-pg2 ol8-pg2:5432 check inter 5000 fastinter 2000 downinter 5000 rise 2 fall 3
        server ol8-pg3 ol8-pg3:5432 check inter 5000 fastinter 2000 downinter 5000 rise 2 fall 3

```

### Set SELinux to Permissive or Disable (ALL)

```bash
# change the selinux configuration
cat /etc/selinux/config

sudo sed -i s/SELINUX=.*/SELINUX=permissive/g /etc/selinux/config

setenforce 0
getenforce
```

### Allow HAProxy on Firewall (ALL)

```bash
# need sudo or root user 
firewall-cmd --add-port=7000/tcp --permanent --zone=public
firewall-cmd --add-port=5000/tcp --permanent --zone=public
firewall-cmd --add-port=5001/tcp --permanent --zone=public
firewall-cmd --reload
firewall-cmd --list-ports
```
### Enable & Start Service (ALL)

```bash
systemctl enable --now haproxy
systemctl status  haproxy
```
## KeepAliveD

### Install Keepalived (ALL)

```bash
sudo dnf install keepalived
```

### Configure Keepalived (ALL)

```bash
mv /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.orig
```

```bash
# try to get the interface name and the IP
ip -br a 
```

```bash
vim /etc/keepalived/keepalived.conf
```

```bash
# Virtual Router Redundancy Protocol (VRRP)
# === Node 1 
vrrp_script chk_haproxy {  
	script "/usr/bin/killall -0 haproxy" # check if HAProxy is running  
	interval 2 # check every 2 second  
	weight 4 # weight to influence master election  
}  
vrrp_instance vi_pg1 {  
	state MASTER  
	interface enp0s3  
	virtual_router_id 51  
	priority 102  
	advert_int 1  
	unicast_src_ip 10.10.200.10 
	unicast_peer {  
		10.10.200.11
		10.10.200.12 
	}  
	authentication {  
		auth_type PASS  
		auth_pass Password  
	}  
  
	virtual_ipaddress {  
		10.10.200.20/24 
	}
	track_script {  
		chk_haproxy  
	}  
} 
```

```bash
# Virtual Router Redundancy Protocol (VRRP)
#=== Node 2
vrrp_script chk_haproxy {  
	script "/usr/bin/killall -0 haproxy" # check if HAProxy is running  
	interval 2 # check every 2 second  
	weight 4 # weight to influence master election  
}  
vrrp_instance vi_pg1 {  
	state BACKUP  
	interface enp0s3  
	virtual_router_id 51  
	priority 101  
	advert_int 1  
	unicast_src_ip 10.10.200.11  
	unicast_peer {  
		10.10.200.10
		10.10.200.12
	}  
	authentication {  
		auth_type PASS  
		auth_pass Password  
	}  
  
	virtual_ipaddress {  
		10.10.200.20/24 
	}
	track_script {  
		chk_haproxy  
	}	
}
```


```bash

#=== Node 3
vrrp_script chk_haproxy {  
	script "/usr/bin/killall -0 haproxy" # check if HAProxy is running  
	interval 2 # check every 2 second  
	weight 4 # weight to influence master election  
}  
vrrp_instance vi_pg1 {  
	state BACKUP  
	interface enp0s3  
	virtual_router_id 51  
	priority 100 
	advert_int 1  
	unicast_src_ip 10.10.200.12  
	unicast_peer {  
		10.10.200.10
		10.10.200.11  
	}  
  
	authentication {  
		auth_type PASS  
		auth_pass Password  
	}  
	virtual_ipaddress{  
		10.10.200.20/24  
	}
	track_script {  
		chk_haproxy  
	}	 
}  
```

### Test and start Keepalived

```bash
sudo keepalived -t
sudo systemctl enable --now keepalived # enable and start
sudo systemctl start keepalived
sudo systemctl status keepalived
```

```bash
# read write connection 5000 is haproxy readwrite backend
psql "host=10.10.200.118 port=5000 user=repmgr dbname=repmgr"
select inet_server_addr();

# read only connection 5001 is haproxy readonly backend
psql "host=10.10.200.118 port=5001 user=repmgr dbname=repmgr"
select inet_server_addr();

```


## Test the HA & Fail-over Scenarios

```bash

```


# Create User

```bash
psql> create tablespace ai_data location '/u01/pgts/';  
psql> create user aiuser login superuser password 'aiuser123';  
psql> create database aidb owner aiuser tablespace ai_data;  
psql> \c aidb  
psql> create schema authorization aiuser;
```



``
