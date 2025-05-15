# Backup & Recovery

## 1. Agenda

- Recovery Models 
- Backup Types
- Backup Options & Code
- Restore Options & Code
- Backup Strategy and Scenarios
- RTO, RPO And your CIO
- Is this a DR or HA Solution?

## 2. Recovery Models 

- Full - Allows for point-in-time Recovery for all transactions and requires T-Log maintenance.
- Simple - Minimally logged operations.
- Bulk-Logged - Bulk Operations are not logged, but others are, point-in-time recovery except for bulk load operations, requires T-Log maintenance.

>Best practice is to run a T-Log backup when switching between Bulk load and Full recovery models

## 3. Backup Types

* Full - [Default] does a backup of all database pages and "marks" them as backed up.
* Differential - does a backup of all database pages that have changed since the last full backup.
* T-Log - does a backup of the transaction log; requires at least one full backup taken before have T-Log backup.
* FileGroup - Does a backup for specific file-groups.
* File - Does a backup for specific database file.

## 4. Backup Options

- Compression - compress backup to save disk space.
- Copy-Only - backup files are chained to each other means that the first backup chained with the next backup with id if you create a backup for test and delete it you will break this chain and you can't restore your database correctly, so **copy-only** will create a backup out of backup chain so your backup chain will remain valid. 
- Differential - take only changes happened for the database after last full backup.
- Mirror-To - take backup to two drives for example drive `E:\` and Drive `F:\`.
- STATS = [Number] (Replace the Number word with a real Number ) - this shows a backup progress percentage to finish.
- NOINIT | INIT (Appends to Backup - Overwrite) 
	- NOINIT - [Default] Will append the new backup to old backup in same backup files (Default Option)
	- INIT - Will Overwrite the New backup with current backup file.
- Encryption (SQL 2014+ & Above) - you can encrypt the Backup without encrypt the DB, before 2014 you need to encrypt DB by enable the TDE to have encrypted backup.
```sql
(
ALGORITHM = AES_256,
SERVER CERTIFICATE = [CERTIFICATE_NAME]
)
```

Basic Backup Code 

```sql
Backup Database [databaseName] To [Disk/Device] = N'PathOrName' with [Options]
```

Real Example Backup code 

```sql
-- Full Backup 

Backup Database DBTest1 To Disk = N'E:\Backup\DBTest1_FULL_10102022.bak' with Compression,copy-only

-- Diff

Backup Database DBTest1 To Disk = N'E:\Backup\DBTest1_DIFF_10102022.bak' with differential

-- T-Log 

Backup Log DBTest1 To Disk = N'E:\Backup\DBTest1_LOG_10102022.bak' with Compression,copy-only

```

## 5. Practice Backup


### 5.1 Scenario 1 

```sql
----Run script piece by piece between the comments
----Backup Full, Diff, T-Log
----Restore Full, Diff, then recovery after
----Restore Full, Diff, T-Log with reovery
USE Master
CREATE DATABASE BackupTest1
go


SELECT *
FROM sys.Databases

-----------------------
USE BackupTest1

Create Table Test1
(column1 int,
column2 varchar(10),
column3 datetime default getdate()
)
GO
----------------------
Insert into Test1 (column1, column2) Values (1,'One')
Insert into Test1 (column1, column2) Values (2,'Two')
GO

---Run FULL Backup
BACKUP Database BackupTest1 to Disk = N'E:\MSSQL\Backups\BackupTest1_FULL.bak'
GO

Insert into Test1 (column1, column2) Values (3,'Three')
Insert into Test1 (column1, column2) Values (4,'Four')
GO

---RUN DIFF Backup
BACKUP Database BackupTest1 to Disk = N'E:\MSSQL\Backups\BackupTest1_DIFF.bak' WITH DIFFERENTIAL
GO

Insert into Test1 (column1, column2)  Values (5,'Five')
Insert into Test1 (column1, column2)  Values (6,'Six')
GO
---RUN TLOG Backup
BACKUP LOG BackupTest1 to Disk = N'E:\MSSQL\Backups\BackupTest1_TLOG.trn'
GO
```


### 5.2 Scenario 2

We are going to create a database and append all (Full, Differential, T-Log) backups in one file, then we will verify, read physical files and header of the file to have valuable information that help use to put a good way to restore this backup file.

```sql

USE Master
Create Database ManyBackupTest
------
------Full Backup to same file
BACKUP Database ManyBackupTest to Disk = N'E:\MSSQL\Backups\ManyBackupTest.bak'
GO

------Backup Diff to same file
BACKUP Database ManyBackupTest to Disk = N'E:\MSSQL\Backups\ManyBackupTest.bak'
WITH DIFFERENTIAL
GO
------Backup Log to same file
BACKUP LOG ManyBackupTest to Disk = N'E:\MSSQL\Backups\ManyBackupTest.bak'
GO

```


## 6. Restore Options


We have "Golden Rule" for restore?
- Test The backup  `DBCC CHECKDB`

Restore options:
- With Recovery [Default] -  if you used `with recovery` as a restore option it means that the database is ready for open no more backup to restore.
- NoRecovery - you can restore FULL and Differential backup using `NoRecovery` restore option then restore the T-log backup using `with recovery` restore option to open database for the latest state. 
- Verify Only - verify that the backup is OK. 
- HeaderOnly - Displays a list of Backups in your backup file.
- FileListOnly - Displays the list of database and log files on your backup file (Logical & Physical Name, Filegroup, and Other great stuff)

Basic Restore Code:

```sql
RESTRE database [DBName] from [Disk/Device] = N'NameOrPath';

---------------------------------------------
-- with norecovery
RESTRE database DBTest1 from Disk = N'C:\backups\DBTest1_11082022.bak' with norecovery;

--------------------------------------------
-- with recovery
RESTRE database DBTest1 from Disk = N'C:\backups\DBTest1_11082022.trn' 

```


Restoring Sequence:

1. Take a backup of your Active/Tail Log.
2. Restore your Full backup (NoRecovery)
3. Restore your latest Differential (if available - NoRecovery)
4. Restore all your T-Logs (NoRecovery)
5. Restore your last T-log the "Tail" (Recovery)


## 7. Practice Restore

### 7.1 Scenario 1

```sql

---CAN VERIFY VALIDITY OF BACKUP
RESTORE VERIFYONLY 
FROM DISK =  N'E:\MSSQL\Backups\BackupTest1_FULL.bak' 

----RESTORE BackupTest1 to a new database called BackupTest2
USE Master
RESTORE DATABASE BackupTest2 FROM  DISK = N'E:\MSSQL\Backups\BackupTest1_FULL.bak' 
WITH  FILE = 1,  
MOVE N'BackupTest1' TO N'E:\MSSQL\Data\BackupTest2.mdf',  
MOVE N'BackupTest1_log' TO N'E:\MSSQL\Logs\BackupTest2_log.ldf',  
NORECOVERY,  NOUNLOAD,  STATS = 5
GO
----------------------------
RESTORE DATABASE BackupTest2 FROM  DISK = N'E:\MSSQL\Backups\BackupTest1_DIFF.bak' 
WITH  FILE = 1,  NORECOVERY,  NOUNLOAD,  STATS = 5
GO

----RECOVERY BEFORE LAST LOG TO SEE THE DATA
----Show in GUI that DB is still in restoring mode
RESTORE Database BackupTest2 WITH RECOVERY

USE BackupTest2
SELECT * FROM Test1

---START OVER TO GET ALL THE DATA
USE MASTER
DROP Database BackupTest2
------------------------------------------
USE Master
RESTORE DATABASE BackupTest2 FROM  DISK = N'E:\MSSQL\Backups\BackupTest1_FULL.bak' 
WITH  FILE = 1,  
MOVE N'BackupTest1' TO N'E:\MSSQL\Data\BackupTest2.mdf',  
MOVE N'BackupTest1_log' TO N'E:\MSSQL\Logs\BackupTest2_log.ldf',  
NORECOVERY,  NOUNLOAD,  STATS = 5
GO
--------------------------------
RESTORE DATABASE BackupTest2 FROM  DISK = N'E:\MSSQL\Backups\BackupTest1_DIFF.bak' 
WITH  FILE = 1,  NORECOVERY,  NOUNLOAD,  STATS = 5
GO
--------------------------------------
RESTORE LOG BackupTest2 FROM  DISK = N'E:\MSSQL\Backups\BackupTest1_TLOG.trn' 
WITH  FILE = 1,  NOUNLOAD,  STATS = 5, NORECOVERY

GO
-----------------------------------
USE BackupTest2
SELECT * FROM Test1

----SYNTAX for T-Log Tail Backup
Create Database TaillogTest
GO

USE TailLogTest

Create Table Test1
(column1 int,
column2 varchar(10),
column3 datetime default getdate()
)
GO
----------------------
Insert into Test1 (column1, column2) Values (1,'One')
Insert into Test1 (column1, column2) Values (2,'Two')
GO

---Run FULL Backup
BACKUP Database TailLogTest to Disk = N'E:\MSSQL\Backups\TailLogTest_FULL.bak'
GO

Insert into Test1 (column1, column2) Values (3,'Three')
Insert into Test1 (column1, column2) Values (4,'Four')
GO

---RUN TLOG Backup
BACKUP LOG TailLogTest to Disk = N'E:\MSSQL\Backups\TailLogTest_TLOG.trn'
GO

Insert into Test1 (column1, column2)  Values (5,'Five')
Insert into Test1 (column1, column2)  Values (6,'Six')
GO

--Set Database Offline
USE MASTER
ALTER Database TailLogTest SET OFFLINE
---Delete the Datafile from the drive :)
---Set the DB Back Online
USE MASTER
ALTER Database TailLogTest SET ONLINE

---!!Problem!! Let's get a TailLog Backup before we lose those last two rows we inserted
USE MASTER
Backup LOG TailLogTest 
TO DISK = N'E:\MSSQL\Backups\TailLogTest_TAILBACKUP.trn' 
WITH  NO_TRUNCATE

---Let's restore it to another DB and check to see if our data is there

USE Master
RESTORE DATABASE TailLogTest2 FROM  DISK = N'E:\MSSQL\Backups\TailLogTest_FULL.bak' 
WITH  FILE = 1,  
MOVE N'TailLogTest' TO N'E:\MSSQL\Data\TailLogTest2.mdf',  
MOVE N'TailLogTest_Log' TO N'E:\MSSQL\Logs\TailLogTest2_Log.ldf',  
NORECOVERY,  NOUNLOAD,  STATS = 5
GO
--------------------------------
RESTORE Log TailLogTest2 FROM  DISK = N'E:\MSSQL\Backups\TailLogTest_TLOG.trn' 
WITH  NORECOVERY,  STATS = 5
GO
--------TAIL LOG RECOVERY------------------------------
RESTORE LOG TailLogTest2 FROM  DISK = N'E:\MSSQL\Backups\TailLogTest_TAILBACKUP.trn' 
WITH  STATS = 5

GO

USE TailLogTest2
Select * from Test1

--Clean up
USE MASTER DROP DATABASE BackupTest1
USE MASTER DROP DATABASE BackupTest2
USE MASTER DROP DATABASE TaillogTest
USE MASTER DROP DATABASE TaillogTest2
```

### 7.2 Scenario 2

```sql

-----Check the validity of the backup
RESTORE VERIFYONLY 
FROM Disk = N'E:\MSSQL\Backups\ManyBackupTest.bak'

---Quick way to see file name information (logical/Physical) on a backup file
RESTORE FILELISTONLY
FROM Disk = N'E:\MSSQL\Backups\ManyBackupTest.bak'

/*
The type of file, one of:
L = Microsoft SQL Server log file
D = SQL Server data file
F = Full Text Catalog
FOR DETAILS VISIT: http://msdn.microsoft.com/en-us/library/ms173778.aspx
*/

RESTORE HEADERONLY
FROM Disk = N'E:\MSSQL\Backups\ManyBackupTest.bak'

/*
Backuptype:
1 = Database	2 = Transaction log		4 = File	5 = Differential database
6 = Differential file	7 = Partial	8 = Differential partial
Also a column called BackupTypeDescription :)
FOR DETAILS VISIT: http://msdn.microsoft.com/en-us/library/ms178536.aspx
*/


/*Create Backup Device*/

USE [master]
GO

/****** Object:  BackupDevice [BackupDevice1]    Script Date: 1/24/2013 7:42:58 PM ******/
EXEC master.dbo.sp_addumpdevice  @devtype = N'disk', 
@logicalname = N'BackupDevice1', 
@physicalname = N'E:\MSSQL\Backups\BackupDevice1.bak'
GO

BACKUP Database ManyBackupTest to BackupDevice1
GO

Restore FILELISTONLY
FROM BackupDevice1

RESTORE HEADERONLY
FROM DISK = 'E:\MSSQL\Backups\BackupDevice1.bak'


---Remove Backup Device ---WILL NOT DELETE LOCAL FILE!!
/****** Object:  BackupDevice [BackupDevice1]    Script Date: 1/24/2013 7:43:28 PM ******/
EXEC master.dbo.sp_dropdevice @logicalname = N'BackupDevice1'
GO
---Trying a DB Restore after the Device is removed will fail
---It will by default look for the last backup 
---because we did not select copy-only it will look for the one on the backup Device
---If we did not delete the backup device file, we can recreate the device and resume the restore

--Encrypt a Backup file ***Does Not Require TDE** SQL 2014+
--Need to Create a MasterKey in the Master Database
Use Master
Create Master Key
Encryption By Password =  'Pa$$w0rd'
    
--Create Certificate in Master Database
Create Certificate BackupEncryptionCertificate
with Subject = 'Certificate to be used to Encrypt and Decrypt Backups'
    
--Use Certificate to Encrypt Backup
BACKUP Database ManyBackupTest to Disk = N'E:\MSSQL\Backups\ManyBackupTest_Encrypted.bak'
WITH Encryption
(
ALGORITHM = AES_256,
SERVER CERTIFICATE = BackupEncryptionCertificate
)
GO

--Backup to Network Path
BACKUP Database ManyBackupTest
TO DISK = '\\SQL2016\SQLShare\BackupToUrl.bak'
WITH COMPRESSION

--Will need a master key, but we already created it
--Backup To Azure
CREATE CREDENTIAL AzureStorageCredential 
WITH IDENTITY = 'aymanazstore', 
SECRET = '<storage key>'; --storage account key

BACKUP DATABASE ManyBackupTest 
TO URL = 'https://aymanazstore.blob.core.windows.net/sqlbackup/ManyBackupTest.bak' 
      WITH CREDENTIAL = 'AzureStorageCredential'
     ,COMPRESSION
     ,STATS = 5;
GO 
---URL Format 'https:// <mystorageaccountname>.blob.core.windows.net/<mystorageaccountcontainername>'

-- Managed Backups in Azure
-- Need A SAS Credentials 
-- https://msdn.microsoft.com/en-us/library/dn449491.aspx--

Use msdb;
GO
EXEC msdb.managed_backup.sp_backup_config_basic 
 @enable_backup = 1, 
 @database_name = 'ManyBackuptest',
 @container_url = 'https://aymanazstore.blob.core.windows.net/sqlbackup/', 
 @retention_days = 30
GO

---CLEAN UP
USE master
DROP Database ManyBackupTest
Drop Credential AzureStorageCredential
DROP Certificate BackupEncryptionCertificate
DROP Master Key
```

## 8. Strategies & Scenarios

we have below strategy of backup we are taking a backup as full backup and transaction log then differentials , if we have outage between Wednesday and Thursday, so we need immediately take a **Tail Log Backup** for the T-Log then we need to start our restoration process,
> Tail Log backup should be taken before this process start
1. Full Backup Restore (NoRecovery).
2. Last Differential Backup restore(NoRecovery).
3. All the T-Logs backup restoration (NoRecovery).
4. Tail Log Backup Restoration (With Recovery).

![](attachments/Pasted%20image%2020220806180907.png)

## 9. RTO, RPO and Your CIO

1. RTO - Recovery Time Objective - How long will it take you to recover after disaster?
2. PRO - Recovery Point Objective - How much data are you willing to lose? Or How much can you recover? Or How often does your data change?
3. CIO - Chief Information Officer - This will be responsible of making decisions.

The RTO and PRO in the contract can affect the backup strategy below Scenarios can show the Idea:

### Scenario 1
Contract agreement:
* RTO: 1 Hour
* RPO: 30 Minutes 

Then Your backup strategy will be like this:

* Full Recovery Model 
* Daily - Full Backup 
* 4 Hours - Differential - this to help us to recover with 1 Hour
* 15 Minutes - T-Log - we will take all the T-log after last Diff Backup

### Scenario 2

Contract agreement:

* RTO: 1 Day 
* RPO: 1 Day 

backup strategy:

- Simple Recovery Model 
- Daily Full backup
- 12 PM Differential Backup 



## End