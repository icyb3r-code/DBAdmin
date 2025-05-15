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
BACKUP Database BackupTest1 to Disk = N'D:\MSSQLServer\Backup\BackupTest1_FULL.bak'
GO

Insert into Test1 (column1, column2) Values (3,'Three')
Insert into Test1 (column1, column2) Values (4,'Four')
GO

---RUN DIFF Backup
BACKUP Database BackupTest1 to Disk = N'D:\MSSQLServer\Backup\BackupTest1_DIFF.bak' WITH DIFFERENTIAL
GO

Insert into Test1 (column1, column2)  Values (5,'Five')
Insert into Test1 (column1, column2)  Values (6,'Six')
GO
---RUN TLOG Backup
BACKUP LOG BackupTest1 to Disk = N'D:\MSSQLServer\Backup\BackupTest1_TLOG.trn'
GO

---CAN VERIFY VALIDITY OF BACKUP
RESTORE VERIFYONLY 
FROM DISK =  N'D:\MSSQLServer\Backup\BackupTest1_FULL.bak' 

----RESTORE BackupTest1 to a new database called BackupTest2
USE Master
RESTORE DATABASE BackupTest2 FROM  DISK = N'D:\MSSQLServer\Backup\BackupTest1_FULL.bak' 
WITH  FILE = 1,  
MOVE N'BackupTest1' TO N'D:\MSSQLServer\Data\BackupTest2.mdf',  
MOVE N'BackupTest1_log' TO N'D:\MSSQLServer\Logs\BackupTest2_log.ldf',  
NORECOVERY,  NOUNLOAD,  STATS = 5
GO
----------------------------
RESTORE DATABASE BackupTest2 FROM  DISK = N'D:\MSSQLServer\Backup\BackupTest1_DIFF.bak' 
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
RESTORE DATABASE BackupTest2 FROM  DISK = N'D:\MSSQLServer\Backup\BackupTest1_FULL.bak' 
WITH  FILE = 1,  
MOVE N'BackupTest1' TO N'D:\MSSQLServer\Data\BackupTest2.mdf',  
MOVE N'BackupTest1_log' TO N'D:\MSSQLServer\Logs\BackupTest2_log.ldf',  
NORECOVERY,  NOUNLOAD,  STATS = 5
GO
--------------------------------
RESTORE DATABASE BackupTest2 FROM  DISK = N'D:\MSSQLServer\Backup\BackupTest1_DIFF.bak' 
WITH  FILE = 1,  NORECOVERY,  NOUNLOAD,  STATS = 5
GO
--------------------------------------
RESTORE LOG BackupTest2 FROM  DISK = N'D:\MSSQLServer\Backup\BackupTest1_TLOG.trn' 
WITH  FILE = 1,  NOUNLOAD,  STATS = 5

GO
-----------------------------------
USE BackupTest2
SELECT * FROM Test1

--Clean up
USE MASTER DROP DATABASE BackupTest1
USE MASTER DROP DATABASE BackupTest2