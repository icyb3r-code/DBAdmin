# Oracle 19c Physical standby DataGuard

## Introduction 

This article, will cover Oracle 19c restart data-guard physical standby configuration, but before we start, you need to have two oracle 19c restart servers one as Primary server and one as  Standby server. the Standby Database will be the target server where we will replicate the database there.

Please check my youtube channel and my github, to see how you can install oracle 19c restart, besides that, to save time of reinstall standby server, you can clone the primary and change the hostname of Cloned server, check my youtube channel and github to see the way of doing that. 

## System Overview 

In this demo I will show you how to configure oracle 19c restart physical standby database, but before we start we need to have an overview for the current system we will work on. below table show the overview of the systems.

| Env Details    | Primary DB   | Standby DB   |
| -------------- | ------------ | ------------ |
| DB Unique Name | prod         | prod_stby    |
| DB Name        | prod         | prod         |
| DB Role        | Primary      | standby      |
| Server IP      | 10.10.20.130 | 10.10.20.131 |
| DB Version     | 19.3c        | 19.3c        |
| OS Version     | OLE 8.3      | OLE 8.3      |



## Steps Overview

* Pre-Config steps
  * Add hostname to hosts file for both (Primary & Standby).
  * Add tnsname to tnsnames.ora for both (Primary & Standby).
  * Create Backup Dir grant permissions for both (Primary & Standby).
  * Install rlwrap
* Primary steps
  * Enable Archive log mode .
  * Enable force logging.
  * Set parameter log_archive_config.
  * Set parameter fal_server & fal_client.
  * Set parameter standby_file_management to auto.
  * Set log_file_name_convert.
  * Set db_file_name_convert.
  * Set pdb_file_name_convert.
  * Create standby redo log files .
  * Create Password file.
  * Create user with table and insert sample data for testing.
  * Collect files and take backup to /backup directory.
  * tar the directory and shipped it to the standby database. 
* Standby steps
  * Un-Tar backup file.
  * Edit pfile using vi/vim.
  * Create Standby instance and Mount database.
  * Restore database.
  * Recover Database.
  * Create DB grid service.
* Configure Broker
  * Create Broker Data file for both (PRIMARY,STANDBY).
  * Start Broker on both (primary & standby).
  * Create configuration using gdmgrl command.
* Switchover 
  * Validate switchover.
  * switchover to prod_stby.
  * switchback to prod.
* Automate Standby archive Logs Deletion
  * Create RMAN script.
  * Test RMAN script.
  * Crontab script.



## Configuration Steps (Short)



### Pre-Config Steps 



* Add hostname to hosts file for both (Primary & Standby)

  ```bash
  # as root
  vim /etc/hosts
  # add below records 
  10.10.20.130    primary.oradomain primary
  10.10.20.131    standby.oradomain standby
  ping primary 
  ping standby 
  ```

  

* Add tnsname to tnsnames.ora for both (Primary & Standby)

  ```bash
  # as Oracle user 
  
  vim $ORACLE_HOME/network/admin/tnsnames.ora
  cat $ORACLE_HOME/network/admin/tnsnames.ora
  
  
    
  # ping the service names 
    
    tnsping prodpdb1_p
    tnsping prod
    tnsping prod_stby
    
  ```
  
  
  
* Create Backup Dir grant permissions for both (Primary & Standby)

  ```bash
  # as root or sudo user 
  
  mkdir -p /backup/prod
  chown -R oracle:oinstall /backup
  chmod -R 775 /backup
  
  # Using grid user 
  
  # on Primary
  asmcmd mkdir +DATA/PROD/DGCONF/
  asmcmd mkdir +FRA/PROD/DGCONF/
  asmcmd mkdir +FRA/PROD/arch
  
  #on Standby
  asmcmd mkdir +DATA/PROD_STBY/
  asmcmd mkdir +DATA/PROD_STBY/prodpdb1
  asmcmd mkdir +DATA/PROD_STBY/pdbseed
  asmcmd mkdir +DATA/PROD_STBY/DGCONF/
  
  asmcmd mkdir +FRA/PROD_STBY/
  asmcmd mkdir +FRA/PROD_STBY/arch
  asmcmd mkdir +FRA/PROD_STBY/DGCONF/
  ```
  
* rlwrap

  ```bash
  rpm -Uvh ftp://ftp.pbone.net/mirror/archive.fedoraproject.org/epel/8.1.2020-04-22/Everything/x86_64/Packages/r/rlwrap-0.43-5.el8.x86_64.rpm
  ```

  





### Primary Steps

* Enable Archive log mode

```bash
show pdbs
alter pluggable database prodpdb1 open;
select log_mode from v$database;
archive log list
shutdown immediate;
startup mount;
alter database archivelog;
archive log list
show parameter log_archive_dest_1
alter system set log_archive_dest_1='LOCATION=+FRA/PROD/arch';
alter database open;
show parameter log_archive_dest_1
archive log list
```

* Enable force logging

```bash
select force_logging from v$database;
alter database force logging;
select force_logging from v$database;
```

* Set parameter log_archive_config

```bash
show parameter log_archive_conf
alter system set log_archive_config='DG_CONFIG=(PROD,PROD_STBY)';
show parameter log_archive_conf
```



* Set parameter fal_server & fal_client

```bash
show parameter fal_
ALTER system SET fal_server=PROD_STBY;
ALTER system SET fal_client=PROD;
show parameter fal_
```



* Set parameter standby_file_management to auto

```bash
show parameter file_manag
alter system set standby_file_management=AUTO;
show parameter file_manag
```



* Set log_file_name_convert

```bash
show parameter convert
alter system set log_file_name_convert = '/PROD_STBY/','/PROD/' scope=spfile;
```



* Set db_file_name_convert

```bash
alter system set db_file_name_convert = '/PROD_STBY/','/PROD/' scope=spfile;
```

* Set pdb_file_name_convert

```bash
alter system set  pdb_file_name_convert = '/PROD_STBY/','/PROD/' scope=spfile;
shutdown immediate;
startup;
show parameter convert
```

* Create standby redo log files 

```SQL
-- check redolog files and groups

col member for a45
set lines 200
select group#, type, member from v$logfile;

 
 -- check the size
 col REDO_SIZE for a10
 select GROUP#,THREAD#,SEQUENCE#,bytes/1024/1024||' MB' as REDO_SIZE ,MEMBERS,STATUS from v$log;

-- create standby redo logs

ALTER DATABASE ADD STANDBY LOGFILE  Group 4 ('+DATA','+FRA') size 200M;
ALTER DATABASE ADD STANDBY LOGFILE  Group 5 ('+DATA','+FRA') size 200M;
ALTER DATABASE ADD STANDBY LOGFILE  Group 6 ('+DATA','+FRA') size 200M;
ALTER DATABASE ADD STANDBY LOGFILE  Group 7 ('+DATA','+FRA') size 200M;

set lines 200
select group#, type, member from v$logfile;

```

* Create Password file 

```bash
# using oracle user 

orapwd file=+DATA/PROD/orapwPROD dbuniquename=prod password=password1 force=y format=12

```

* Create user with table and insert sample data for testing

```bash
rlwrap sqlplus sys@prodpdb1_p as sysdba
show pdbs
alter pluggable database prodpdb1 open;
create user test_user identified by test123;
alter user test_user quota 100M on users;
grant connect,resource to test_user;
connect test_user/test123@prodpdb1_p
create table test (id number(10),name varchar2(35));
insert into test values (1,'names');
/
/
/
/
commit;
select * from test;
alter system switch logfile;
alter system archive log current;
```



* Collect files and take backup to /backup directory 

```bash
# get pfile from spfile (Oracle user)

create pfile='/backup/pfilePROD.ora' from spfile;
! ls -l /backup

# get passwd file from ASM (Grid User)
asmcmd pwget --dbuniquename prod 
asmcmd pwcopy +DATA/PROD/orapwprod /backup/orapwprod
ls -l /backup/ora*
# Configure RMAN and take backup 

CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/backup/prod/%F';
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '/backup/prod/%U';
CONFIGURE DEVICE TYPE DISK PARALLELISM 3;

# Run block
run {
	backup database;
	backup archivelog all;
	backup current controlfile for standby format '/backup/prod/stby_ctl_%d_%u_%s';
}

# or run them individually 

backup database;
backup archivelog all;
backup current controlfile for standby format '/backup/prod/stby_ctl_%d_%u_%s';

list backup of controlfile;


# Or you can duplicate Database using 

RMAN> run {
DUPLICATE TARGET DATABASE FOR STANDBY FROM ACTIVE DATABASE DORECOVER SPFILE SET db_unique_name='prod_stby' COMMENT 'Is standby' SET db_file_name_convert='/prod/','/prod_stby/' SET log_file_name_convert='/prod/','/prod_stby/';
 }

```





* Tar the directory and shipped it to the standby database. 

```bash
# oracle user 
cd /backup
tar -czvf backup.tar.gz *
scp backup.tar.gz oracle@standby:~
```



### Standby Steps



* Un-Tar backup file

  ```bash
  # as oracle user 
  tar -xvf backup.tar.gz -C /backup
  ```

  

* Edit pfile using vi/vim

  ```bash
  # Edit pfile 
  
  vim /backup/pfilePROD.ora
  
  # change below parameters to be same as below
  
  *.db_file_name_convert='/PROD/','/PROD_STBY/'
  *.log_file_name_convert='/PROD/','/PROD_STBY/'
  *.pdb_file_name_convert='/PROD/','/PROD_STBY/'
  *.db_unique_name='prod_stby'
  *.control_files='+DATA/PROD_STBY/CONTROLFILE/current.260.1073580523','+FRA/PROD_STBY/CONTROLFILE/current.256.1073580523'
  *.log_archive_dest_1='LOCATION=+FRA/PROD_STBY/arch'
  *.fal_client='PROD_STBY'
  *.fal_server='PROD'
  
  # create below directorys if not created 
  # oracle base
  mkdir -p /u01/19c/oracle_base/admin/prod/adump
  ```
  
  

* Create Standby instance

  ```bash
  rlwrap sqlplus / as sysdba 
  startup nomount pfile='/backup/pfilePROD.ora';
  create spfile='+DATA/PROD_STBY/spfilePROD.ora' from pfile='/backup/pfilePROD.ora';
  
  !vim $ORACLE_HOME/dbs/initprod.ora
  # add this to initprod.ora
  SPFILE='+DATA/PROD_STBY/spfilePROD.ora'
  
  show parameter spfile
  shu immediate 
  startup nomount
  show parameter spfile
  show parameter fal_
  show parameter convert
  show parameter control_files
  show parameter log_archive_dest_1
  show parameter db_uniq
  select value from v$parameter where name='service_names';
  ```

* Restore standby control file and mount database

  ```bash
  ls /backup/prod/stby*
  restore controlfile from '/backup/prod/stby_ctl_PROD_0b0l5q0r_11';
  
  alter database mount standby database;
  
  list backup;
  ```

* Restore database

   ```bash
  restore database;
  
  ```

  

* Recover database

  ```bash
  catalog start with '+DATA/PROD_STBY';
  NO
  switch database to copy;
  recover database;
  ```

* Create Standby database service.

  ```bash
  srvctl add database -d prod_stby -o $ORACLE_HOME  -p '+DATA/PROD_STBY/spfilePROD.ora' -r PHYSICAL_STANDBY -s 'mount' -n standby -a 'DATA,FRA'
  
  srvctl config database -d prod_stby
  
  ## use oracle
  
  srvctl modify database -d prod_stby -i prod
  srvctl config database -d prod_stby
  
  srvctl stop database -d prod_stby -force 
  srvctl start database -d prod_stby
  srvctl status database -d prod_stby
  
  ## use grid 
  
  srvctl config database -d prod_stby
  
  asmcmd pwcopy --dbuniquename prod_stby /backup/orapwprod +data/prod_stby/orapwprod
  
  asmcmd pwget --dbuniquename prod_stby
  
  srvctl config database -d prod_stby
  
  # if needed you can modify service 
  
  srvctl modify database -d prod_stby -pwfile +data/prod_stby/orapwprod
  
  # tnsping from both primary and standby
  
  # using grid check the listener status and serives 
  srvctl stop listener 
  srvctl start listener 
  
  lsnrctl services
  lsnrctl status 
  
  # you can also reload
  lsnrctl reload
  
  
  # using sql register the service name if the serivce not registered
  
  select value from v$parameter where name='service_names';
  alter system register;
  alter session set container=prodpdb1;
  alter system register;
  ```

### Configure Broker 

* Create Broker Data file for both (PRIMARY,STANDBY)

  ```bash
  # using sqlplus on Primary oracle user 
  
  rlwrap sqlplus / as sysdba
  
  show parameter dg_broker_config
  
  ALTER SYSTEM SET DG_BROKER_CONFIG_FILE1='+DATA/PROD/DGCONF/dgb_conf_01.dat';
  ALTER SYSTEM SET DG_BROKER_CONFIG_FILE2='+FRA/PROD/DGCONF/dgb_conf_02.dat';
  show parameter dg_broker_config
  
  # using sqlplus on standby oracle user 
  
  show parameter dg_broker_config
  
  ALTER SYSTEM SET DG_BROKER_CONFIG_FILE1='+DATA/PROD_STBY/DGCONF/dgb_conf_01.dat';
  
  ALTER SYSTEM SET DG_BROKER_CONFIG_FILE2='+FRA/PROD_STBY/DGCONF/dgb_conf_02.dat';
  show parameter dg_broker_config
  ```

* Start Broker on both (primary & standby)

  ```bash
  ALTER SYSTEM SET dg_broker_start=true;
  ```

* Create configuration using gdmgrl command 

  ```bash
  # monitor the database
  
  # primary
  tail -f $ORACLE_BASE/diag/rdbms/prod/prod/trace/alert_prod.log
  
  #standby 
  tail -f $ORACLE_BASE/diag/rdbms/prod_stby/prod/trace/alert_prod.log
  
  select name,open_mode,database_role from v$database;
  
  dgmgrl sys@prod
  
  CREATE CONFIGURATION PROD_DB_DG_CONFIG AS PRIMARY DATABASE IS prod CONNECT IDENTIFIER IS prod;
  
  ADD DATABASE prod_stby AS CONNECT IDENTIFIER IS prod_stby;
  
  show configuration
  enable configuration;
  show configuration
  show database prod_stby
  ```

### Switchover

* Use tail command to monitor 

  ```bash
  # primary
  tail -f $ORACLE_BASE/diag/rdbms/prod/prod/trace/alert_prod.log
  
  tail -f $ORACLE_BASE/diag/rdbms/prod/prod/trace/drcprod.log
  
  
  #standby 
  tail -f $ORACLE_BASE/diag/rdbms/prod_stby/prod/trace/alert_prod.log
  
  tail -f $ORACLE_BASE/diag/rdbms/prod_/prod/trace/drcprod.log
  ```

  

* Validate switchover

  ```bash
  # using sql plus
  select  low_sequence#, high_sequence# from v$archive_gap;
  
  # using broker
  show configuration;
  
  validate database prod;
  validate database prod_stby;
  ```

  

* switchover to prod_stby

  ```bash
  switchover to prod_stby;
  show configuration;
  
  # sqlplus on both nodes to check the db role 
  select name,db_unique_name,database_role from v$database;
  
  ```

* Validate switchover

  ```bash
  validate database prod;
  show configuration;
  ```

* switchback to prod

  ```bash
  switchover to prod;
  show configuration;
  
  # sqlplus on both nodes to check the db role 
  select name,db_unique_name,database_role from v$database;
  ```
  
  



### Automate Standby archive Logs Deletion

* Create RMAN script.

  ```bash
  cd ~
  mkdir -p scripts/logs
  cd scripts
  vim delete_arch.sh
  
  ## add below by copy paste to script file 
  
  #!/bin/bash
  
  export ORACLE_SID=prod
  rman target / <<EOF
  run{
  delete noprompt archivelog until time 'sysdate-0.5';
  }
  exit
  EOF
  ```

  

* Test RMAN script.

  ```bash
  chmod u+x delete_arch.sh
  ./delete_arch.sh
  ```

  

* Crontab script.

  ```bash
  05 23 * * * . /home/oracle/.bash_profile;  /home/oracle/scripts/delete_arch.sh 2>&1 > /home/oracle/scripts/delete_arch.$(date +\%Y\%m\%d-\%H\%M\%S).cron.log 
  ```

  



## Configuration Steps (Detailed)



### System Overview 



| Env Details    | Primary DB   | Standby DB   |
| -------------- | ------------ | ------------ |
| DB Unique Name | prod         | prod_stby    |
| DB Name        | prod         | prod         |
| DB Role        | Primary      | standby      |
| Server IP      | 10.10.20.130 | 10.10.20.131 |
| DB Version     | 19.3c        | 19.3c        |
| OS Version     | OLE 8.3      | OEL 8.3      |

### Pre-Config steps

* Add hostname to hosts file for both (Primary & Standby)

```bash
# as root

vim /etc/hosts
# add below records 
10.10.20.130    primary.oradomain primary
10.10.20.131    standby.oradomain standby

# try to ping from both servers should be reachable.

ping primary 
ping standby 
```



* Add tnsname to tnsnames.ora for both (Primary & Standby)

```bash

vim $ORACLE_HOME/network/admin/tnsnames.ora
cat $ORACLE_HOME/network/admin/tnsnames.ora

scp $ORACLE_HOME/network/admin/tnsnames.ora oracle@standby:$ORACLE_HOME/network/admin/


# add this to primary tnsnames.ora
PRODPDB1_p =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = primary)(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVICE_NAME = prodpdb1)
    )
  )

PRODPDB1_s =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = standby)(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVICE_NAME = prodpdb1)
    )
  )
  
  
# add this to both primary & standby tnsnames.ora

PROD =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = primary)(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVICE_NAME = prod)
    )
  )

PROD_STBY =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = standby)(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVICE_NAME = prod_stby)
    )
  )

# ping the service names 
  
  tnsping prodpdb1_p
  tnsping prod
  tnsping prod_stby
  
```



* Create Backup Dir grant permissions for both (Primary & Standby)

```bash
# as root or sudo user 

mkdir -p /backup/prod
chown -R oracle:oinstall /backup
chmod -R 775 /backup

# Using grid user 

# on Primary
asmcmd mkdir +DATA/PROD/DGCONF/
asmcmd mkdir +FRA/PROD/DGCONF/
asmcmd mkdir +FRA/PROD/arch

#on Standby

asmcmd mkdir +DATA/PROD_STBY/
asmcmd mkdir +DATA/PROD_STBY/prodpdb1
asmcmd mkdir +DATA/PROD_STBY/pdbseed
asmcmd mkdir +FRA/PROD_STBY/
asmcmd mkdir +FRA/PROD_STBY/arch
asmcmd mkdir +DATA/PROD_STBY/DGCONF/
asmcmd mkdir +FRA/PROD_STBY/DGCONF/
```

* rlwrap

  ```bash
  rpm -Uvh ftp://ftp.pbone.net/mirror/archive.fedoraproject.org/epel/8.1.2020-04-22/Everything/x86_64/Packages/r/rlwrap-0.43-5.el8.x86_64.rpm
  
  Retrieving ftp://ftp.pbone.net/mirror/archive.fedoraproject.org/epel/8.1.2020-04-22/Everything/x86_64/Packages/r/rlwrap-0.43-5.el8.x86_64.rpm
  warning: /var/tmp/rpm-tmp.7i35A8: Header V3 RSA/SHA256 Signature, key ID 2f86d6a1: NOKEY
  Verifying...                          ################################# [100%]
  Preparing...                          ################################# [100%]
  Updating / installing...
     1:rlwrap-0.43-5.el8                ################################# [100%]
  ```

  



### Primary Steps 



* Enable Archive log mode

```bash
SQL> select log_mode from v$database;

LOG_MODE
------------
NOARCHIVELOG

SQL> shutdown immdediate;

SP2-0717: illegal SHUTDOWN option
SQL> shut immediate
Database closed.
Database dismounted.
ORACLE instance shut down.

SQL> startup mount
ORACLE instance started.

Total System Global Area 2415918608 bytes
Fixed Size                  9137680 bytes
Variable Size             520093696 bytes
Database Buffers         1879048192 bytes
Redo Buffers                7639040 bytes
Database mounted.

SQL> alter database archivelog;

Database altered.

SQL> archive log list

Database log mode              Archive Mode
Automatic archival             Enabled
Archive destination            USE_DB_RECOVERY_FILE_DEST
Oldest online log sequence     12
Next log sequence to archive   14
Current log sequence           14

SQL> show parameter log_achive_dest_1

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
db_create_online_log_dest_1          string
log_archive_dest_1                   string
log_archive_dest_10                  string
log_archive_dest_11                  string
log_archive_dest_12                  string
log_archive_dest_13                  string
log_archive_dest_14                  string
log_archive_dest_15                  string
log_archive_dest_16                  string
log_archive_dest_17                  string
log_archive_dest_18                  string

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
log_archive_dest_19                  string

SQL> alter system set log_archive_dest_1='LOCATION=+FRA/PROD/arch';

SQL> alter database open;

Database altered.

SQL> show parameter dest_1

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
db_create_online_log_dest_1          string
log_archive_dest_1                   string      LOCATION=+FRA/PROD/arch
log_archive_dest_10                  string
log_archive_dest_11                  string
log_archive_dest_12                  string
log_archive_dest_13                  string
log_archive_dest_14                  string
log_archive_dest_15                  string
log_archive_dest_16                  string
log_archive_dest_17                  string
log_archive_dest_18                  string

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------
log_archive_dest_19                  string
SQL> archive log list
Database log mode              Archive Mode
Automatic archival             Enabled
Archive destination            +FRA/prod/arch
Oldest online log sequence     12
Next log sequence to archive   14
Current log sequence           14
SQL>
```

 

* Enable force logging

```bash
SQL> select force_logging from v$database;

FORCE_LOGGING
---------------------------------------
NO

SQL> alter database force logging;

Database altered.

SQL> select force_logging from v$database;

FORCE_LOGGING
---------------------------------------
YES

SQL>

```



* Set parameter log_archive_config

```bash

SQL> alter system set log_archive_config='DG_CONFIG=(PROD,PROD_STBY)';

System altered.

SQL>

SQL> show parameter log_archive_conf

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
log_archive_config                   string      DG_CONFIG=(PROD,PROD_STBY)
SQL>

```



* Set parameter fal_server & fal_client

```bash
SQL> ALTER system SET fal_server=PROD_STBY;

System altered.

SQL> ALTER system SET fal_client=PROD;

System altered.

SQL> show parameter fal_

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
fal_client                           string      PROD
fal_server                           string      PROD_STBY
SQL>
```



* Set parameter standby_file_management to auto

```bash
SQL> show parameter file_manag

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
standby_file_management              string      MANUAL

SQL> alter system set standby_file_management=AUTO;

System altered.

SQL> show parameter file_manag

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
standby_file_management              string      AUTO

```



* Set log_file_name_convert

```bash
SQL> show parameter convert

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
db_file_name_convert                 string
log_file_name_convert                string
pdb_file_name_convert                string

SQL>  alter system set log_file_name_convert = '/PROD_STBY/','/PROD/' scope=spfile;

System altered.

```



* Set db_file_name_convert

```bash

SQL> alter system set db_file_name_convert = '/PROD_STBY/','/PROD/' scope=spfile;

System altered.

```

* Set pdb_file_name_convert

```bash
SQL> alter system set  pdb_file_name_convert = '/PROD_STBY/','/PROD/' scope=spfile;

System altered.

SQL> shutdown immediate;

SQL> startup;

```



* Create standby redo log files 

```SQL


-- check redolog files and groups

SQL> set lines 200
SQL> --set pages 200
SQL> select group#, type, member from v$logfile;

    GROUP# TYPE    MEMBER
---------- ------- ---------------------------------------------
         3 ONLINE  +DATA/PROD/ONLINELOG/group_3.263.1073580527
         3 ONLINE  +FRA/PROD/ONLINELOG/group_3.259.1073580527
         2 ONLINE  +DATA/PROD/ONLINELOG/group_2.262.1073580527
         2 ONLINE  +FRA/PROD/ONLINELOG/group_2.258.1073580527
         1 ONLINE  +DATA/PROD/ONLINELOG/group_1.261.1073580527
         1 ONLINE  +FRA/PROD/ONLINELOG/group_1.257.1073580527

6 rows selected.


SQL> ALTER DATABASE ADD STANDBY LOGFILE  Group 4 ('+DATA','+FRA') size 200M;

Database altered.

SQL> select group#, type, member from v$logfile;

    GROUP# TYPE    MEMBER
---------- ------- ---------------------------------------------
         3 ONLINE  +DATA/PROD/ONLINELOG/group_3.263.1073580527
         3 ONLINE  +FRA/PROD/ONLINELOG/group_3.259.1073580527
         2 ONLINE  +DATA/PROD/ONLINELOG/group_2.262.1073580527
         2 ONLINE  +FRA/PROD/ONLINELOG/group_2.258.1073580527
         1 ONLINE  +DATA/PROD/ONLINELOG/group_1.261.1073580527
         1 ONLINE  +FRA/PROD/ONLINELOG/group_1.257.1073580527
         4 STANDBY +DATA/PROD/ONLINELOG/group_4.275.1095431659
         4 STANDBY +FRA/PROD/ONLINELOG/group_4.262.1095431659

8 rows selected.

SQL> ALTER DATABASE ADD STANDBY LOGFILE  Group 5 ('+DATA','+FRA') size 200M;

Database altered.

SQL> ALTER DATABASE ADD STANDBY LOGFILE  Group 6 ('+DATA','+FRA') size 200M;

Database altered.

SQL>  select GROUP#,THREAD#,SEQUENCE#,bytes/1024/1024||' MB' as REDO_SIZE ,MEMBERS,STATUS from v$log;

    GROUP#    THREAD#  SEQUENCE# REDO_SIZE                                      MEMBERS STATUS
---------- ---------- ---------- ------------------------------------------- ---------- ----------------
         1          1         16 200 MB                                               2 CURRENT
         2          1         14 200 MB                                               2 INACTIVE
         3          1         15 200 MB                                               2 INACTIVE

SQL> col REDO_SIZE for a10
SQL> /

    GROUP#    THREAD#  SEQUENCE# REDO_SIZE     MEMBERS STATUS
---------- ---------- ---------- ---------- ---------- ----------------
         1          1         16 200 MB              2 CURRENT
         2          1         14 200 MB              2 INACTIVE
         3          1         15 200 MB              2 INACTIVE

SQL> select group#, type, member from v$logfile;

    GROUP# TYPE    MEMBER
---------- ------- ---------------------------------------------
         3 ONLINE  +DATA/PROD/ONLINELOG/group_3.263.1073580527
         3 ONLINE  +FRA/PROD/ONLINELOG/group_3.259.1073580527
         2 ONLINE  +DATA/PROD/ONLINELOG/group_2.262.1073580527
         2 ONLINE  +FRA/PROD/ONLINELOG/group_2.258.1073580527
         1 ONLINE  +DATA/PROD/ONLINELOG/group_1.261.1073580527
         1 ONLINE  +FRA/PROD/ONLINELOG/group_1.257.1073580527
         4 STANDBY +DATA/PROD/ONLINELOG/group_4.275.1095431659
         4 STANDBY +FRA/PROD/ONLINELOG/group_4.262.1095431659
         5 STANDBY +DATA/PROD/ONLINELOG/group_5.276.1095431677
         5 STANDBY +FRA/PROD/ONLINELOG/group_5.263.1095431677
         6 STANDBY +DATA/PROD/ONLINELOG/group_6.277.1095431683

    GROUP# TYPE    MEMBER
---------- ------- ---------------------------------------------
         6 STANDBY +FRA/PROD/ONLINELOG/group_6.264.1095431683

12 rows selected.

SQL>

```

* Create Password file 

```bash
# using oracle user 

orapwd file=+DATA/PROD/orapwPROD dbuniquename=prod password=password1 force=y format=12

```

* Create user with table and insert sample data for testing

```bash
[oracle@primary ~]$ rlwrap sqlplus sys@prodpdb1_p as sysdba

SQL*Plus: Release 19.0.0.0.0 - Production on Tue Feb 1 11:57:10 2022
Version 19.3.0.0.0

Copyright (c) 1982, 2019, Oracle.  All rights reserved.

Enter password:

Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

SQL> show pdbs

    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         3 PRODPDB1                       READ WRITE
         
SQL> create user test_user identified by testuser123;

User created.

SQL> alter user test_user quota 100M on system;

User altered.

SQL> alter user test_user quota 100M on users;

User altered.

SQL> grant connect,resource to test_user;

Grant succeeded.

SQL> connect test_user@prodpdb1_p
Enter password:
Connected.
SQL> create table test (id number(10),name varchar2(35));

Table created.

SQL> insert into test values (1,'test_name');

1 row created.

SQL> commit;

Commit complete.

SQL> select * from test;

        ID NAME
---------- -----------------------------------
         1 test_name

SQL>
```



* Collect files and take backup to /backup directory 

```bash
# get pfile from spfile (Oracle user)

SQL> create pfile='/backup/pfilePROD.ora' from spfile;

File created.

SQL> ! ls -l /backup
total 4
-rw-r--r--. 1 oracle asmadmin 1448 Feb  1 12:23 pfilePROD.ora

SQL> 

# get passwd file from ASM (Grid User)

[grid@primary ~]$ asmcmd pwget --dbuniquename prod
+DATA/PROD/orapwprod
[grid@primary ~]$ asmcmd pwcopy +DATA/PROD/orapwprod /backup/orapwprod
copying +DATA/PROD/orapwprod -> /backup/orapwprod
[grid@primary ~]$ 

# Configure RMAN and take backup 

CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/backup/prod/%F';
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '/backup/prod/%U';
CONFIGURE DEVICE TYPE DISK PARALLELISM 3;

# run them as run block

run {
	backup database;
	backup archivelog all;
	backup current controlfile for standby format '/backup/prod/stby_ctl_%d_%u_%s';
}

# or run them individually 

RMAN> backup database;

Starting backup at 01-FEB-2022 12:37:13
allocated channel: ORA_DISK_1
channel ORA_DISK_1: SID=148 device type=DISK
allocated channel: ORA_DISK_2
channel ORA_DISK_2: SID=145 device type=DISK
allocated channel: ORA_DISK_3
channel ORA_DISK_3: SID=408 device type=DISK
channel ORA_DISK_1: starting full datafile backup set

---snipped--- 

channel ORA_DISK_1: starting piece 1 at 01-FEB-2022 12:37:50
channel ORA_DISK_2: finished piece 1 at 01-FEB-2022 12:37:50
piece handle=/backup/prod/060kob0l_1_1 tag=TAG20220201T123714 comment=NONE
channel ORA_DISK_2: backup set complete, elapsed time: 00:00:09
channel ORA_DISK_3: finished piece 1 at 01-FEB-2022 12:37:51
piece handle=/backup/prod/070kob0m_1_1 tag=TAG20220201T123714 comment=NONE
channel ORA_DISK_3: backup set complete, elapsed time: 00:00:09
channel ORA_DISK_1: finished piece 1 at 01-FEB-2022 12:37:52
piece handle=/backup/prod/080kob0u_1_1 tag=TAG20220201T123714 comment=NONE
channel ORA_DISK_1: backup set complete, elapsed time: 00:00:02
Finished backup at 01-FEB-2022 12:37:52

Starting Control File and SPFILE Autobackup at 01-FEB-2022 12:37:53
piece handle=/backup/prod/c-485418859-20220201-00 comment=NONE
Finished Control File and SPFILE Autobackup at 01-FEB-2022 12:37:58

RMAN> backup archivelog all;

Starting backup at 01-FEB-2022 12:38:22
current log archived
using channel ORA_DISK_1
using channel ORA_DISK_2
using channel ORA_DISK_3

----snipped---- 

piece handle=/backup/prod/0b0kob1v_1_1 tag=TAG20220201T123823 comment=NONE
channel ORA_DISK_2: backup set complete, elapsed time: 00:00:03
Finished backup at 01-FEB-2022 12:38:26

Starting Control File and SPFILE Autobackup at 01-FEB-2022 12:38:26
piece handle=/backup/prod/c-485418859-20220201-01 comment=NONE
Finished Control File and SPFILE Autobackup at 01-FEB-2022 12:38:27

RMAN> backup current controlfile for standby format '/backup/prod/stby_ctl_%d_%u_%s';

Starting backup at 01-FEB-2022 12:38:50
using channel ORA_DISK_1
using channel ORA_DISK_2
using channel ORA_DISK_3
channel ORA_DISK_1: starting full datafile backup set
channel ORA_DISK_1: specifying datafile(s) in backup set
including standby control file in backup set
channel ORA_DISK_1: starting piece 1 at 01-FEB-2022 12:38:51
channel ORA_DISK_1: finished piece 1 at 01-FEB-2022 12:38:52
piece handle=/backup/prod/stby_ctl_PROD_0d0kob2q_13 tag=TAG20220201T123850 comment=NONE
channel ORA_DISK_1: backup set complete, elapsed time: 00:00:01
Finished backup at 01-FEB-2022 12:38:52

Starting Control File and SPFILE Autobackup at 01-FEB-2022 12:38:52
piece handle=/backup/prod/c-485418859-20220201-02 comment=NONE
Finished Control File and SPFILE Autobackup at 01-FEB-2022 12:38:53

RMAN>


# Or you can duplicate Database using 

RMAN> run {
DUPLICATE TARGET DATABASE FOR STANDBY FROM ACTIVE DATABASE DORECOVER SPFILE SET db_unique_name='prod_stby' COMMENT 'Is standby' SET db_file_name_convert='/prod/','/prod_stby/' SET log_file_name_convert='/prod/','/prod_stby/';
 }

```





* Tar the directory and shipped it to the standby database. 

```bash
[oracle@primary backup]$ tar -czvf backup.tar.gz *
orapwprod
pfilePROD.ora
prod/
prod/020l4d7o_1_1
prod/040l4d7p_1_1
prod/030l4d7p_1_1
prod/050l4d80_1_1
prod/060l4d84_1_1
prod/070l4d86_1_1
prod/080l4d8d_1_1
prod/stby_ctl_PROD_090l4d8i_9
prod/c-485418859-20220206-01
[oracle@primary ~]$
[oracle@primary backup]$ scp backup.tar.gz oracle@standby:~
oracle@standby's password:
backup.tar.gz                       100%  450MB  97.3MB/s   00:04
[oracle@primary backup]$
```





### Standby Steps



* Un-Tar backup file

  ```bash
  # as oracle user 
  tar -xvf backup.tar.gz -C /backup
  ```

  

* Edit pfile using vi/vim

  ```bash
  # Edit pfile 
  
  vim /backup/pfilePROD.ora
  
  # change below parameters to be same as below
  
  *.db_file_name_convert='/PROD/','/PROD_STBY/'
  *.log_file_name_convert='/PROD/','/PROD_STBY/'
  *.pdb_file_name_convert='/PROD/','/PROD_STBY/'
  *.db_unique_name='prod_stby'
  *.control_files='+DATA/PROD_STBY/CONTROLFILE/current.260.1073580523','+FRA/PROD_STBY/CONTROLFILE/current.256.1073580523'
  *.log_archive_dest_1='LOCATION=+FRA/PROD_STBY/arch'
  *.fal_client='PROD_STBY'
  *.fal_server='PROD'
  
  
  # create below directorys if not created 
  # oracle base
  mkdir -p $ORACLE_BASE/admin/prod/adump
  
  ```

  

* Create Standby instance

  ```bash
  rlwrap sqlplus / as sysdba 
  SQL> startup nomount pfile='/backup/pfilePROD.ora';
  SQL> create spfile='+DATA/PROD_STBY/spfilePROD.ora' from pfile='/backup/pfilePROD.ora';
  
  vim $ORACLE_HOME/dbs/initprod.ora
  # add this to initprod.ora
  SPFILE='+DATA/PROD_STBY/spfilePROD.ora'
  
  SQL> startup nomount
  ORACLE instance started.
  
  Total System Global Area 2415918608 bytes
  Fixed Size                  9137680 bytes
  Variable Size             520093696 bytes
  Database Buffers         1879048192 bytes
  Redo Buffers                7639040 bytes
  
  SQL> show parameter fal
  
  NAME                                 TYPE        VALUE
  ------------------------------------ ----------- ------------------------------
  fal_client                           string      PROD_STBY
  fal_server                           string      PROD
  SQL> show parameter convert
  
  NAME                                 TYPE        VALUE
  ------------------------------------ ----------- ------------------------------
  db_file_name_convert                 string      /PROD/, /PROD_STBY/
  log_file_name_convert                string      /PROD/, /PROD_STBY/
  pdb_file_name_convert                string      /PROD/, /PROD_STBY/
  
  SQL> show parameter control_files
  
  NAME                                 TYPE        VALUE
  ------------------------------------ ----------- ---------------------------
  control_files                        string +DATA/PROD_STBY/CONTROLFILE/current.260.1073580523, +FRA/PRO   D_STBY/CONTROLFILE/current.256.1073580523
  
  
  SQL> show parameter log_archive_dest_1
  
  NAME                                 TYPE        VALUE
  ------------------------------------ ----------- ------------------------------
  log_archive_dest_1                   string      LOCATION=+FRA/PROD_STBY/arch
  
  SQL> show parameter db_uniq
  
  NAME                                 TYPE        VALUE
  ------------------------------------ ----------- ------------------------------
  db_unique_name                       string      prod_stby
  SQL>
  
  ```

* Restore standby control file and mount database

  ```bash
  RMAN> restore controlfile from '/backup/prod/stby_ctl_PROD_0d0kob2q_13';
  
  Starting restore at 05-FEB-2022 06:18:43
  using target database control file instead of recovery catalog
  allocated channel: ORA_DISK_1
  channel ORA_DISK_1: SID=136 device type=DISK
  
  channel ORA_DISK_1: restoring control file
  channel ORA_DISK_1: restore complete, elapsed time: 00:00:01
  output file name=+DATA/PROD_STBY/CONTROLFILE/current.260.1095833925
  output file name=+FRA/PROD_STBY/CONTROLFILE/current.256.1095833925
  Finished restore at 05-FEB-2022 06:18:45
  
  RMAN>
  RMAN> alter database mount standby database;
  
  Statement processed
  
  RMAN> list backup;
  
  ```

* Restore database

   ```bash
   RMAN> restore database;
   
   Starting restore at 05-FEB-2022 06:54:12
   using channel ORA_DISK_1
   using channel ORA_DISK_2
   using channel ORA_DISK_3
   
   channel ORA_DISK_1: restoring datafile 00001
   input datafile copy RECID=17 STAMP=1095835920 file name=+DATA/PROD_STBY/DATAFILE/system.259.1095835915
   destination for restore of datafile 00001: +DATA/MUST_RENAME_THIS_DATAFILE_1.4294967295.4294967295
   channel ORA_DISK_1: starting datafile backup set restore
   channel ORA_DISK_1: specifying datafile(s) to restore from backup set
   channel ORA_DISK_1: restoring datafile 00003 to +DATA/MUST_RENAME_THIS_DATAFILE_3.4294967295.4294967295
   channel ORA_DISK_1: restoring datafile 00004 to +DATA/MUST_RENAME_THIS_DATAFILE_4.4294967295.4294967295
   channel ORA_DISK_1: reading from backup piece /backup/prod/030koavr_1_1
   channel ORA_DISK_2: starting datafile backup set restore
   channel ORA_DISK_2: specifying datafile(s) to restore from backup set
   channel ORA_DISK_2: restoring datafile 00009 to +DATA/MUST_RENAME_THIS_DATAFILE_9.4294967295.4294967295
   channel ORA_DISK_2: restoring datafile 00011 to +DATA/MUST_RENAME_THIS_DATAFILE_11.4294967295.4294967295
   channel ORA_DISK_2: reading from backup piece /backup/prod/040koavs_1_1
   channel ORA_DISK_3: starting datafile backup set restore
   channel ORA_DISK_3: specifying datafile(s) to restore from backup set
   channel ORA_DISK_3: restoring datafile 00001 to +DATA/MUST_RENAME_THIS_DATAFILE_1.4294967295.4294967295
   channel ORA_DISK_3: restoring datafile 00007 to +DATA/MUST_RENAME_THIS_DATAFILE_7.4294967295.4294967295
   channel ORA_DISK_3: reading from backup piece /backup/prod/020koavr_1_1
   channel ORA_DISK_1: piece handle=/backup/prod/030koavr_1_1 tag=TAG20220201T123714
   channel ORA_DISK_1: restored backup piece 1
   channel ORA_DISK_1: restore complete, elapsed time: 00:00:03
   channel ORA_DISK_1: starting datafile backup set restore
   channel ORA_DISK_1: specifying datafile(s) to restore from backup set
   channel ORA_DISK_1: restoring datafile 00005 to +DATA/MUST_RENAME_THIS_DATAFILE_5.4294967295.4294967295
   channel ORA_DISK_1: reading from backup piece /backup/prod/050kob0l_1_1
   channel ORA_DISK_2: piece handle=/backup/prod/040koavs_1_1 tag=TAG20220201T123714
   channel ORA_DISK_2: restored backup piece 1
   channel ORA_DISK_2: restore complete, elapsed time: 00:00:03
   channel ORA_DISK_2: starting datafile backup set restore
   channel ORA_DISK_2: specifying datafile(s) to restore from backup set
   channel ORA_DISK_2: restoring datafile 00006 to +DATA/MUST_RENAME_THIS_DATAFILE_6.4294967295.4294967295
   channel ORA_DISK_2: reading from backup piece /backup/prod/070kob0m_1_1
   channel ORA_DISK_3: piece handle=/backup/prod/020koavr_1_1 tag=TAG20220201T123714
   channel ORA_DISK_3: restored backup piece 1
   channel ORA_DISK_3: restore complete, elapsed time: 00:00:03
   channel ORA_DISK_3: starting datafile backup set restore
   channel ORA_DISK_3: specifying datafile(s) to restore from backup set
   channel ORA_DISK_3: restoring datafile 00010 to +DATA/MUST_RENAME_THIS_DATAFILE_10.4294967295.4294967295
   channel ORA_DISK_3: restoring datafile 00012 to +DATA/MUST_RENAME_THIS_DATAFILE_12.4294967295.4294967295
   channel ORA_DISK_3: reading from backup piece /backup/prod/060kob0l_1_1
   channel ORA_DISK_1: piece handle=/backup/prod/050kob0l_1_1 tag=TAG20220201T123714
   channel ORA_DISK_1: restored backup piece 1
   channel ORA_DISK_1: restore complete, elapsed time: 00:00:01
   channel ORA_DISK_1: starting datafile backup set restore
   channel ORA_DISK_1: specifying datafile(s) to restore from backup set
   channel ORA_DISK_1: restoring datafile 00008 to +DATA/MUST_RENAME_THIS_DATAFILE_8.4294967295.4294967295
   channel ORA_DISK_1: reading from backup piece /backup/prod/080kob0u_1_1
   channel ORA_DISK_2: piece handle=/backup/prod/070kob0m_1_1 tag=TAG20220201T123714
   channel ORA_DISK_2: restored backup piece 1
   channel ORA_DISK_2: restore complete, elapsed time: 00:00:01
   channel ORA_DISK_3: piece handle=/backup/prod/060kob0l_1_1 tag=TAG20220201T123714
   channel ORA_DISK_3: restored backup piece 1
   channel ORA_DISK_3: restore complete, elapsed time: 00:00:01
   channel ORA_DISK_1: piece handle=/backup/prod/080kob0u_1_1 tag=TAG20220201T123714
   channel ORA_DISK_1: restored backup piece 1
   channel ORA_DISK_1: restore complete, elapsed time: 00:00:01
   Finished restore at 05-FEB-2022 06:54:20
   ```

  

* Recover database

  ```bash
  RMAN> catalog start with '+DATA/PROD_STBY';
  
  searching for all files that match the pattern +DATA/PROD_STBY
  
  List of Files Unknown to the Database
  =====================================
  File Name: +DATA/PROD_STBY/spfileprod.ora
  
  Do you really want to catalog the above files (enter YES or NO)? YES
  cataloging files...
  no files cataloged
  
  List of Files Which Were Not Cataloged
  =======================================
  File Name: +DATA/PROD_STBY/spfileprod.ora
    RMAN-07518: Reason: Foreign database file DBID: 0  Database Name:
  
  RMAN> switch database to copy;
  
  datafile 1 switched to datafile copy "+DATA/PROD_STBY/DATAFILE/system.262.1095836055"
  datafile 3 switched to datafile copy "+DATA/PROD_STBY/DATAFILE/sysaux.256.1095836055"
  datafile 4 switched to datafile copy "+DATA/PROD_STBY/DATAFILE/undotbs1.265.1095836055"
  datafile 5 switched to datafile copy "+DATA/PROD_STBY/C342D1D0D2E07ACDE05382140A0AE26E/DATAFILE/system.268.1095836059"
  datafile 6 switched to datafile copy "+DATA/PROD_STBY/C342D1D0D2E07ACDE05382140A0AE26E/DATAFILE/sysaux.273.1095836059"
  datafile 7 switched to datafile copy "+DATA/PROD_STBY/DATAFILE/users.264.1095836055"
  datafile 8 switched to datafile copy "+DATA/PROD_STBY/C342D1D0D2E07ACDE05382140A0AE26E/DATAFILE/undotbs1.277.1095836059"
  datafile 9 switched to datafile copy "+DATA/PROD_STBY/C342F3B7488D84D9E05382140A0A2185/DATAFILE/system.266.1095836055"
  datafile 10 switched to datafile copy "+DATA/PROD_STBY/C342F3B7488D84D9E05382140A0A2185/DATAFILE/sysaux.279.1095836059"
  datafile 11 switched to datafile copy "+DATA/PROD_STBY/C342F3B7488D84D9E05382140A0A2185/DATAFILE/undotbs1.259.1095836055"
  datafile 12 switched to datafile copy "+DATA/PROD_STBY/C342F3B7488D84D9E05382140A0A2185/DATAFILE/users.278.1095836059"
  
  RMAN> recover database;
  
  Starting recover at 05-FEB-2022 06:59:14
  using channel ORA_DISK_1
  using channel ORA_DISK_2
  using channel ORA_DISK_3
  
  starting media recovery
  
  channel ORA_DISK_1: starting archived log restore to default destination
  channel ORA_DISK_1: restoring archived log
  archived log thread=1 sequence=17
  channel ORA_DISK_1: reading from backup piece /backup/prod/0b0kob1v_1_1
  channel ORA_DISK_1: piece handle=/backup/prod/0b0kob1v_1_1 tag=TAG20220201T123823
  channel ORA_DISK_1: restored backup piece 1
  channel ORA_DISK_1: restore complete, elapsed time: 00:00:01
  archived log file name=+FRA/prod_stby/arch/1_17_1073580526.dbf thread=1 sequence=17
  media recovery complete, elapsed time: 00:00:01
  Finished recover at 05-FEB-2022 06:59:17
  
  RMAN>
  ```

* Create Standby database service.

  ```bash
  
  srvctl add database -d prod_stby -o $ORACLE_HOME  -p '+DATA/PROD_STBY/spfilePROD.ora' -r PHYSICAL_STANDBY -s 'mount' -n standby -a 'DATA,FRA' -pwfile '+DATA/PROD_STBY/orapwprod'
  
  [oracle@standby ~]$ srvctl config database -d prod_stby
  Database unique name: prod_stby
  Database name: standby
  Oracle home: /u01/19c/oracle_base/oracle/db_home
  Oracle user: oracle
  Spfile: +DATA/PROD_STBY/spfilePROD.ora
  Password file: +DATA/PROD_STBY/orapwprod
  Domain:
  Start options: mount
  Stop options: immediate
  Database role: PHYSICAL_STANDBY
  Management policy: AUTOMATIC
  Disk Groups: DATA,FRA
  Services:
  OSDBA group:
  OSOPER group:
  Database instance: prodstby
  
  ## use grid 
  
  asmcmd pwcopy --dbuniquename prod_stby /backup/orapwprod +data/prod_stby/orapwprod -f
  
  ## use oracle
  
  [oracle@standby ~]$ srvctl modify database -d prod_stby -i prod
  [oracle@standby ~]$ srvctl config database -d prod_stby
  Database unique name: prod_stby
  Database name: standby
  Oracle home: /u01/19c/oracle_base/oracle/db_home
  Oracle user: oracle
  Spfile: +DATA/PROD_STBY/spfilePROD.ora
  Password file: +DATA/PROD_STBY/orapwprod
  Domain:
  Start options: mount
  Stop options: immediate
  Database role: PHYSICAL_STANDBY
  Management policy: AUTOMATIC
  Disk Groups: DATA,FRA
  Services:
  OSDBA group:
  OSOPER group:
  Database instance: prod
  [oracle@standby ~]$
  [oracle@standby ~]$ srvctl stop database -d prod_stby -force 
  [oracle@standby ~]$ srvctl start database -d prod_stby
  [oracle@standby ~]$ srvctl status database -d prod_stby
  Database is running.
  [oracle@standby ~]$ 
  
  # using grid check the listener status and serives 
  
  lsnrctl services
  lsnrctl status 
  
  lsnrctl reload
  srvctl stop listener 
  srvctl start listner 
  
  # using sql register the service name 
  
  SQL> select value from v$parameter where name='service_names';
  
  VALUE
  ---------------------------------------------------------------------
  prod_stby
  
  SQL> alter system register;
  
  System altered.
  
  SQL> alter session set container=prodpdb1;
  
  Session altered.
  
  SQL> alter system register;
  
  System altered.
  
  SQL> exit
  
  ```

### Configure Broker 

* Create Broker Data file for both (PRIMARY,STANDBY)

  ```bash
  # using sqlplus on Primary  
  
  SQL> ALTER SYSTEM SET DG_BROKER_CONFIG_FILE1='+DATA/PROD/DGCONF/dgb_conf_01.dat';
  
  System altered.
  
  SQL> ALTER SYSTEM SET DG_BROKER_CONFIG_FILE2='+FRA/PROD/DGCONF/dgb_conf_02.dat';
  
  System altered.
  
  SQL> 
  
  SQL> show parameter dg_broker_config
  
  NAME                                 TYPE        VALUE
  ------------------------------------ ----------- -------------------------
  dg_broker_config_file1               string      +DATA/PROD/DGCONF/dgb_conf_01.dat
  dg_broker_config_file2               string      +FRA/PROD/DGCONF/dgb_conf_02.dat
  SQL>
  
  # Using sqlplus on Standby 
  
  SQL> ALTER SYSTEM SET DG_BROKER_CONFIG_FILE1='+DATA/PROD_STBY/DGCONF/dgb_conf_01.dat';
  
  System altered.
  
  SQL> ALTER SYSTEM SET DG_BROKER_CONFIG_FILE2='+FRA/PROD_STBY/DGCONF/dgb_conf_02.dat';
  
  System altered.
  
  SQL> 
  SQL> show parameter dg_broker_config
  
  NAME                                 TYPE        VALUE
  ------------------------------------ ----------- ------------------------------
  dg_broker_config_file1               string      +DATA/PROD_STBY/DGCONF/dgb_conf_01.dat
  dg_broker_config_file2               string      +FRA/PROD_STBY/DGCONF/dgb_conf_02.dat
  SQL>
  
  
  ```

* Start Broker on both (primary & standby)

  ```bash
  SQL> ALTER SYSTEM SET dg_broker_start=true;
  
  System altered.
  
  SQL>
  
  ```

* Create configuration using gdmgrl command 

  ```bash
  select name,open_mode,database_role from v$database;
  
  
  dgmgrl sys@prod
  
  DGMGRL for Linux: Release 19.0.0.0.0 - Production on Sat Feb 5 08:44:42 2022
  Version 19.3.0.0.0
  
  Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.
  
  Welcome to DGMGRL, type "help" for information.
  Password:
  Connected to "prod"
  Connected as SYSDBA.
  DGMGRL> 
  DGMGRL> CREATE CONFIGURATION PROD_DB_DG_CONFIG AS PRIMARY DATABASE IS prod CONNECT IDENTIFIER IS prod;
  Configuration "prod_db_dg_config" created with primary database "prod"
  DGMGRL>
  DGMGRL> ADD DATABASE prod_stby AS CONNECT IDENTIFIER IS prod_stby;
  Database "prod_stby" added
  DGMGRL> 
  DGMGRL>
  DGMGRL> show configuration
  
  Configuration - prod_db_dg_config
  
    Protection Mode: MaxPerformance
    Members:
    prod      - Primary database
      prod_stby - Physical standby database
  
  Fast-Start Failover:  Disabled
  
  Configuration Status:
  DISABLED
  
  DGMGRL> 
  DGMGRL> enable configuration;
  Enabled.
  DGMGRL>
  DGMGRL> show configuration
  
  Configuration - prod_db_dg_config
  
    Protection Mode: MaxPerformance
    Members:
    prod      - Primary database
      prod_stby - Physical standby database
  
  Fast-Start Failover:  Disabled
  
  Configuration Status:
  SUCCESS   (status updated 59 seconds ago)
  
  DGMGRL>
  
  DGMGRL> show database prod_stby
  
  Database - prod_stby
  
    Role:               PHYSICAL STANDBY
    Intended State:     APPLY-ON
    Transport Lag:      0 seconds (computed 0 seconds ago)
    Apply Lag:          0 seconds (computed 0 seconds ago)
    Average Apply Rate: 152.00 KByte/s
    Real Time Query:    OFF
    Instance(s):
      prod
  
  Database Status:
  SUCCESS
  
  DGMGRL>
  
  ```

### Switchover

To monitor both node you need to run below command:

```bash
# primary
tail -f $ORACLE_BASE/diag/rdbms/prod/prod/trace/alert_prod.log

#standby 
tail -f $ORACLE_BASE/diag/rdbms/prod_stby/prod/trace/alert_prod.log

```



* Validate switchover

  ```bash
  DGMGRL> validate database prod;
  
    Database Role:    Primary database
  
    Ready for Switchover:  Yes
  
    Flashback Database Status:
      prod:  Off
  
    Managed by Clusterware:
      prod:  YES
  
  DGMGRL> validate database prod_stby;
  
    Database Role:     Physical standby database
    Primary Database:  prod
  
    Ready for Switchover:  Yes
    Ready for Failover:    Yes (Primary Running)
  
    Flashback Database Status:
      prod     :  Off
      prod_stby:  Off
  
    Managed by Clusterware:
      prod     :  YES
      prod_stby:  YES
  
    Current Log File Groups Configuration:
      Thread #  Online Redo Log Groups  Standby Redo Log Groups Status
                (prod)                  (prod_stby)
      1         3                       2                       Insufficient SRLs
  
    Future Log File Groups Configuration:
      Thread #  Online Redo Log Groups  Standby Redo Log Groups Status
                (prod_stby)             (prod)
      1         3                       0                       Insufficient SRLs
      Warning: standby redo logs not configured for thread 1 on prod
  
  DGMGRL>
  DGMGRL> show configuration
  
  Configuration - prod_db_dg_config
  
    Protection Mode: MaxPerformance
    Members:
    prod      - Primary database
      prod_stby - Physical standby database
  
  Fast-Start Failover:  Disabled
  
  Configuration Status:
  SUCCESS   (status updated 56 seconds ago)
  
  DGMGRL>
  
  
  ```

  

* switchover to prod_stby

  ```bash
  DGMGRL> switchover to prod_stby;
  Performing switchover NOW, please wait...
  Operation requires a connection to database "prod_stby"
  Connecting ...
  Connected to "prod_stby"
  Connected as SYSDBA.
  New primary database "prod_stby" is opening...
  Oracle Clusterware is restarting database "prod" ...
  Connected to "prod"
  Connected to "prod"
  Switchover succeeded, new primary is "prod_stby"
  DGMGRL> show configuration;
  
  Configuration - prod_db_dg_config
  
    Protection Mode: MaxPerformance
    Members:
    prod_stby - Primary database
      prod      - Physical standby database
  
  Fast-Start Failover:  Disabled
  
  Configuration Status:
  SUCCESS   (status updated 78 seconds ago)
  
  DGMGRL>
  ```

  

* switchback to prod

  ```bash
  DGMGRL> show configuration
  
  Configuration - prod_db_dg_config
  
    Protection Mode: MaxPerformance
    Members:
    prod_stby - Primary database
      prod      - Physical standby database
  
  Fast-Start Failover:  Disabled
  
  Configuration Status:
  SUCCESS   (status updated 22 seconds ago)
  
  DGMGRL>
  DGMGRL> switchover to prod;
  Performing switchover NOW, please wait...
  Operation requires a connection to database "prod"
  Connecting ...
  Connected to "prod"
  Connected as SYSDBA.
  New primary database "prod" is opening...
  Oracle Clusterware is restarting database "prod_stby" ...
  Connected to "prod_stby"
  Connected to "prod_stby"
  Switchover succeeded, new primary is "prod"
  DGMGRL>
  DGMGRL> show configuration
  
  Configuration - prod_db_dg_config
  
    Protection Mode: MaxPerformance
    Members:
    prod      - Primary database
      prod_stby - Physical standby database
        Warning: ORA-16854: apply lag could not be determined
  
  Fast-Start Failover:  Disabled
  
  Configuration Status:
  WARNING   (status updated 55 seconds ago)
  
  DGMGRL>
  
  ```

### Automate Standby archive Logs Deletion

* Create RMAN script.

  ```bash
  cd ~
  mkdir -p scripts/logs
  cd scripts
  vim delete_arch.sh
  
  ## add below by copy paste to script file 
  
  #!/bin/bash
  
  export ORACLE_SID=prod
  rman target / <<EOF
  run{
  delete noprompt archivelog until time 'sysdate-0.5';
  }
  exit
  EOF
  ```

  

* Test RMAN script.

  ```bash
  chmod +x delete_arch.sh
  ./delete_arch.sh
  ```

  

* Crontab script.

  ```bash
  05 23 * * * . /home/oracle/.bash_profile;  /home/oracle/scripts/delete_arch.sh 2>&1 > /home/oracle/scripts/delete_arch.$(date +\%Y\%m\%d-\%H\%M\%S).cron.log 
  ```

