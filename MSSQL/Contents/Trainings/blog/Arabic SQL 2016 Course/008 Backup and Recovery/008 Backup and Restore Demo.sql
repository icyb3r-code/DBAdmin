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