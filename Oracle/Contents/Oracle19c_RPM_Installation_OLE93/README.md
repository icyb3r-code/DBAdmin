# Oracle 19C RPM Based Installation

Running RPM package to install oracle database can be done by perform the following steps:

## Prepare OS Hostname, Network & Selinux 

Before we proceed with the installation process we need to make sure that we have a hostname and network ip assigned to our system:

```bash
# set hostname for something you like below my lab hostname
sudo hostnamectl set-hostname ole9-19c

# Check if the network has a static IP 
ip a 

# add hostname and ip to hosts file, IP in this lab  change it to yours 
sudo vim /etc/hosts
10.10.110.129	ole9-19c

# change selinux
cat /etc/selinux/config
sudo sed -i s/SELINUX=enforcing/SELINUX=permissive/g /etc/selinux/config
sudo setenforce Permissive
getenforce
```

## Install Pre-Installation package 

* **Oracle Linux**

```bash
sudo yum -y install oracle-database-preinstall-19c
# or 
sudo dnf -y install oracle-database-preinstall-19c
```

* **Redhat Linux**

```bash
# download the package redhat 7
curl -o oracle-database-preinstall-19c-1.0-1.el7.x86_64.rpm https://yum.oracle.com/repo/OracleLinux/OL7/latest/x86_64/getPackage/oracle-database-preinstall-19c-1.0-1.el7.x86_64.rpm

# Download the package for redhat 8 
https://yum.oracle.com/repo/OracleLinux/OL8/appstream/x86_64/getPackage/oracle-database-preinstall-19c-1.0-1.el8.x86_64.rpm

# Download the package for redhat 9
https://yum.oracle.com/repo/OracleLinux/OL9/appstream/x86_64/getPackage/oracle-database-preinstall-19c-1.0-1.el9.x86_64.rpm

# install the backage command works on OLE7,OLE8,OLE9 
sudo yum -y localinstall oracle-database-preinstall-19c-1.0-1.el9.x86_64.rpm
# Works only on OLE8 and OLE9
sudo dnf -y localinstall oracle-database-preinstall-19c-1.0-1.el9.x86_64.rpm
```

Red hat only: after the installation is complete, clean up the package.

```bash
# remove the package after the installation done
 rm oracle-database-preinstall-19c-1.0-1.el7.x86_64.rpm
```

## Download & Install Oracle 19C RPM

Download oracle 19c RPM package from oracle by visiting this [link](https://www.oracle.com/database/technologies/oracle19c-linux-downloads.html)
it will ask you for login, if you have user account on oracle you can proceed with download otherwise you need to create an oracle account to be able to download the package.

Once you have the package on you system, you can install it by 

```bash
cd /tmp
ls -l | grep oracle
sudo yum -y localinstall oracle-database-ee-19c-1.0-1.x86_64.rpm
# or
sudo dnf -y localinstall oracle-database-ee-19c-1.0-1.x86_64.rpm
```

You can clean up the rpm file after the installation by deleting the rpm package :

```bash
rm oracle-database-ee-19c-1.0-1.x86_64.rpm
```

## Configure Oracle database 19c 

### Default Config

```bash

### Default configuration 
# content of /etc/init.d/oracledb_DEMOCDB-19c

less /etc/init.d/oracledb_DEMOCDB-19c

export ORACLE_HOME=/opt/oracle/product/19c/dbhome_1 

export ORACLE_VERSION=19c 
export ORACLE_SID=ORCLCDB
export TEMPLATE_NAME=General_Purpose.dbc
export CHARSET=AL32UTF8
export PDB_NAME=ORCLPDB1
export LISTENER_NAME=LISTENER
export NUMBER_OF_PDBS=1
export CREATE_AS_CDB=true

# below is the content of /etc/sysconfig/oracledb_ORCLCDB-19c
#Oracle data location.
less /etc/sysconfig/oracledb_ORCLCDB-19c

# LISTENER_PORT: Database listener
LISTENER_PORT=1521

# ORACLE_DATA_LOCATION: Database oradata location
ORACLE_DATA_LOCATION=/opt/oracle/oradata

# EM_EXPRESS_PORT: Oracle EM Express listener
EM_EXPRESS_PORT=5500

# You can proceed with the default configuration by running this command 
sudo /etc/init.d/oracledb_ORCLCDB-19c configure

```

##  Set Environment Variables - Default Conf

```bash
# set a password for oracle user 
sudo passwd oracle

# login to oracle user and add below to bash profile
su - oracle
vim ~/.bash_profile
# add to the end
umask 022
export ORACLE_SID=ORCLCDB
export ORACLE_BASE=/opt/oracle
export ORACLE_HOME=/opt/oracle/product/19c/dbhome_1
export PATH=$PATH:$ORACLE_HOME/bin
```
### Custom Config

```bash
# Keep in your mind below details, while you follow up below next steps 
OS_VERSION=OLE9.3
ORACLE_VERSION=19c
ORACLE_SID=DEMOCDB
PDB_NAME=DEMOPDB1
LISTENER_PORT=1521
ORACLE_DATA_LOCATION=/u02/oracle/oradata


# But in this video tutorial we will create our own ORACLE_SID, PDB_NAME and change the default location of data files  

sudo -i # to change user to root

export ORACLE_SID=DEMOCDB

sudo cp /etc/init.d/oracledb_ORCLCDB-19c /etc/init.d/oracledb_$ORACLE_SID-19c

####################################  change the sid and pdb names from the new script we already created

cd /etc/init.d/
# grep environment variables exports
head -47 oracledb_DEMOCDB-19c
grep export oracledb_DEMOCDB-19c
# search for old sid 
grep ORCLCDB oracledb_DEMOCDB-19c
# search for old pdb name 
grep ORCLPDB1 oracledb_DEMOCDB-19c

# replace sid with new one 
sed -i  's/ORCLCDB/'"$ORACLE_SID"'/g' oracledb_DEMOCDB-19c
#replace pdb name with new one 
sed -i  's/ORCLPDB1/DEMOPDB1/g' oracledb_DEMOCDB-19c

# check if we have the new sid and pdb name wrote to the file 
grep $ORACLE_SID oracledb_DEMOCDB-19c
grep DEMOPDB1 oracledb_DEMOCDB-19c
head -47 oracledb_DEMOCDB-19c


###################################### change Datafiles Default location
# create new conf file from old one 
echo $ORACLE_SID
sudo cp /etc/sysconfig/oracledb_ORCLCDB-19c.conf /etc/sysconfig/oracledb_$ORACLE_SID-19c.conf

cd /etc/sysconfig/
# Search for the /opt directory 
cat oracledb_DEMOCDB-19c.conf
grep opt oracledb_DEMOCDB-19c.conf

# change the opt dir to u02 dir (make sure /u02 is available on file system and has oracle:oinstall ownership)
ls -la /u02
chown -R oracle:oinstall /u02
sed -i 's/opt/u02/' oracledb_DEMOCDB-19c.conf
sed -i 's/1521/1522/' oracledb_DEMOCDB-19c.conf
# check the changes are applied
cd /etc/sysconfig
grep u02 oracledb_DEMOCDB-19c.conf
grep 1522 oracledb_DEMOCDB-19c.conf
# or by cat the file 
cat oracledb_DEMOCDB-19c.conf

################ create DEMOCDB database
# run below command from root user 
/etc/init.d/oracledb_DEMOCDB-19c configure

```

##  Set Environment Variables - Custom Conf

```bash
# set a password for oracle user 
sudo passwd oracle

# login to oracle user and add below to bash profile
su - oracle
vim ~/.bash_profile
# add to the end
umask 022
export ORACLE_SID=DEMOCDB
export ORACLE_BASE=/opt/oracle
export ORACLE_HOME=/opt/oracle/product/19c/dbhome_1
export PATH=$PATH:$ORACLE_HOME/bin
```

## Create Systemd Service 

```bash
# login to root
sudo -i

# edit oratab file 
vim /etc/oratab
# last line : change N to Y
DEMOCDB:/opt/oracle/product/19c/dbhome_1:Y

vim /etc/sysconfig/DEMOCDB.oracledbenv
# create new : define environment variables

ORACLE_BASE=/opt/oracle/
ORACLE_HOME=/opt/oracle/product/19c/dbhome_1
ORACLE_SID=DEMOCDB

# configure database service

vim /usr/lib/systemd/system/DEMOCDB@oracledb.service
# this is an example, modify for free

[Unit]
Description=Oracle Database 19c service
After=network.target

[Service]
Type=forking
EnvironmentFile=/etc/sysconfig/DEMOCDB.oracledbenv
ExecStart=/opt/oracle/product/19c/dbhome_1/bin/dbstart $ORACLE_HOME
ExecStop=/opt/oracle/product/19c/dbhome_1/bin/dbshut $ORACLE_HOME
User=oracle

[Install]
WantedBy=multi-user.target


# enable and start the service 
systemctl daemon-reload

systemctl enable DEMOCDB@oracledb 
systemctl start DEMOCDB@oracledb
systemctl status DEMOCDB@oracledb
systemctl start DEMOCDB@oracledb



alter pluggable database DEMOPDB1 open;

col instance_name for a15
col host_name for a25
select instance_name, host_name, version, startup_time from v$instance; 
```

## De-Install Oracle RPM Based  

```bash
# login using oracle 

# remove databases that is created on the system
dbca

# remove created listeners 
netca

# export this before run deinstall script 
export CV_ASSUME_DISTID=OEL7.9

# deinstall as oracle user 
/opt/oracle/product/19c/dbhome_1/deinstall/deinstall

# remove oracle database 19c rpm package 
sudo dnf remove -y oracle-database-ee-19c.x86_64

# if you want to remove completely the oracle from the system
sudo dnf remove -y oracle-database-preinstall-19c.x86_64

# Disable the service which created by us earlier 
systemctl disable DEMOCDB@oracledb

# remove files create by us earlier 
rm /usr/lib/systemd/system/DEMOCDB@oracledb.service
rm /etc/sysconfig/oracledb_DEMOCDB-19c.conf
rm /etc/sysconfig/DEMOCDB.oracledbenv
rm /etc/init.d/oracledb_DEMOCDB-19c
```


## Error


**Dnf Remove** 

to overcome the below error you need to remove the home by using deinstall script 

![](attachments/Pasted%20image%2020240324203316.png)

```bash
[root@ole9-19c admin]# dnf remove oracle-database-ee-19c-1.0-1.x86_64 
Dependencies resolved.
=============================================================================================================================================================
 Package                                         Architecture                    Version                        Repository                              Size
=============================================================================================================================================================
Removing:
 oracle-database-ee-19c                          x86_64                          1.0-1                          @@commandline                          6.9 G

Transaction Summary
=============================================================================================================================================================
Remove  1 Package

Freed space: 6.9 G
Is this ok [y/N]: y
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Preparing        :                                                                                                                                     1/1 
  Running scriptlet: oracle-database-ee-19c-1.0-1.x86_64                                                                                                 1/1 
[SEVERE] An error occured while discovering the configuration of the Oracle home. Verify the deinstall logs for more details.
error: %preun(oracle-database-ee-19c-1.0-1.x86_64) scriptlet failed, exit status 1

Error in PREUN scriptlet in rpm package oracle-database-ee-19c
  Verifying        : oracle-database-ee-19c-1.0-1.x86_64                                                                                                 1/1 

Failed:
  oracle-database-ee-19c-1.0-1.x86_64                                                                                                                        

Error: Transaction failed

```


**Deinstall** 

To overcome below error you need to export this environment variable `export CV_ASSUME_DISTID=OEL7.9` to terminal before run the deinstall script 

![](./attachments/Pasted%20image%2020240324203102.png)

```bash
[oracle@ole9-19c ~]$ /opt/oracle/product/19c/dbhome_1/deinstall/deinstall
Checking for required files and bootstrapping ...
Please wait ...
Location of logs /tmp/deinstall2024-03-24_12-29-00PM/logs/

############ ORACLE DECONFIG TOOL START ############


######################### DECONFIG CHECK OPERATION START #########################
## [START] Install check configuration ##


Checking for existence of the Oracle home location /opt/oracle/product/19c/dbhome_1
Oracle Home type selected for deinstall is: Oracle Single Instance Database
Oracle Base selected for deinstall is: /opt/oracle
Checking for existence of central inventory location /opt/oracle/oraInventory
ERROR: null

```