

# Configure DG for Heterogeneous Env

| Details        | Primary           | Standby          |
| -------------- | ----------------- | ---------------- |
| ServerName     | WIN-DB            | OLE-DB           |
| OS             | Windows Server 12 | Oracle Linux 8.7 |
| DB Version     | 12.2.0.1          | 12.2.0.1         |
| DB Name        | NiraDB            | NiraDB           |
| DB Unique Name | NiraDB            | NiraDB_stby      |
| Endian Format  | little            | little           |

Check the ENDIAN format compatibility

```bash
SQL> **SELECT * FROM V$TRANSPORTABLE_PLATFORM ORDER BY 3,1;**
```

## Primary DB steps :

**1. Force logging needs to be enabled**

```sql
SQL> select force_logging from v$database;

FORCE_LOGGING
---------------------------------------
NO

SQL> ALTER DATABASE FORCE LOGGING;

Database altered.

SQL> select force_logging from v$database;

FORCE_LOGGING
---------------------------------------
YES

-- Make sure at least one logfile is present.
ALTER SYSTEM SWITCH LOGFILE;
```

**2. Archive log needs to be enabled**

```sql
SELECT log_mode FROM v$database;

show parameter archive_dest_1
alter system set log_archive_dest_1=’LOCATION=E:\archivelog\NiraDB’ scope=both;

SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;

archive log list
SELECT log_mode FROM v$database;

# to create first archive log file 
alter system switch logfile;

-- Make sure at least one logfile is present.
ALTER SYSTEM SWITCH LOGFILE;
```

**3. Check DB Unique name**

```sql

select db_unique_name,db_name from v$database;

# or 

show parameter db_name
show parameter db_unique_name

```

**4. Add service name of standby in tnsnames.ora**

Notice the use of the SID, rather than the SERVICE_NAME in the entries. This is important as the broker will need to connect to the databases when they are down, so the services will not be present.

```
NIRADB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = 10.10.21.10)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = NIRADB)
    )
  )



NIRADB_STBY =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = 10.10.21.20)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = NIRADB)
    )
  )
```

Register a database service name as `DGMGRL` for data guard broker.  

```
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = NiraDB_DGMGRL)
      (ORACLE_HOME = C:\app\oracle\product\12.2.0\dbhome_1)
      (SID_NAME = NiraDB)
    )
    (SID_DESC =
      (GLOBAL_DBNAME = NiraDB)
      (ORACLE_HOME = C:\app\oracle\product\12.2.0\dbhome_1)
      (SID_NAME = NiraDB)
    )
  )

LISTENER =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = 10.10.21.10)(PORT = 1521))
  )

ADR_BASE_LISTENER = C:\app\oracle\product\12.2.0\dbhome_1\log
```

**5. Add standby logfiles to the primary server**

```sql
-- check the logfiles 
SQL> col member for a45
SQL> set lines 200
SQL> select group#, type, member from v$logfile;


--check the size 
 -- check the size
 col REDO_SIZE for a10
 select GROUP#,THREAD#,SEQUENCE#,bytes/1024/1024||' MB' as REDO_SIZE ,MEMBERS,STATUS from v$log;


-- If Oracle Managed Files (OMF) is used.
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 10 SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 11 SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 12 SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 13 SIZE 200M;

-- If Oracle Managed Files (OMF) is not used.
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 10 ('/PATH/standby_redo01.log') SIZE 50M;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 11 ('/PATH/standby_redo02.log') SIZE 50M;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 12 ('/PATH/standby_redo03.log') SIZE 50M;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 13 ('/PATH/standby_redo04.log') SIZE 50M;

set lines 200
select group#, type, member from v$logfile where type='STANDBY';

```

**6. Change standby file management to auto**

```sql
SQL> show parameter standby
SQL> alter system set standby_file_management=AUTO scope=BOTH;
```

**7. Set parameter log_archive_config**

```shell
show parameter log_archive_conf
alter system set log_archive_config='DG_CONFIG=(PROD,PROD_STBY)';
show parameter log_archive_conf
```

**8. Set parameter fal_server & fal_client**

```sql
show parameter fal_
ALTER system SET fal_server=PROD_STBY;
ALTER system SET fal_client=PROD;
show parameter fal_
```

**9. Create Passwd file**


check this directory if the password file is not created create a new one.
```
orapwd file=C:\app\oracle\product\12.2.0\dbhome_1\database\orapwNiraDB  password=0Racl3! force=y format=12
```


move this password file to the standby server 

```
cp /mnt/hgfs/DB/PWDNiraDB.ora /u01/app/oracle/product/12.2/dbhome_1/dbs/orapwNIRADB
```

```host
rman target sys@niradb auxiliary sys@NiraDB_STBY
```

