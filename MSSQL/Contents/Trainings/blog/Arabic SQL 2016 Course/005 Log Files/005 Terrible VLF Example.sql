Set Statistics Time ON

CREATE DATABASE [KeepMyJobVLF]
 ON  PRIMARY 
( NAME = N'KeepMyJobVLF', FILENAME = N'E:\MSSQL\Data\KeepMyJobVLF.mdf' , SIZE = 4096KB , FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'KeepMyJobVLF_log', FILENAME = N'E:\MSSQL\Logs\KeepMyJob_log.ldf' , SIZE =400MB , MAXSIZE = 400MB,FILEGROWTH = 1KB)
GO
--SQL Server Execution Times:
--   CPU time = 0 ms,  elapsed time = 2113 ms
--2 seconds


ALTER database [KeepMyJobVLF] SET RECOVERY FULL



USE [KeepMyJobVLF]
GO

BACKUP DATABASE [KeepMyJobVLF] to DISK = 'NUL'

Create Table WorstTable
(Data char(8000))
GO

SET NOCOUNT ON

Insert into WorstTable Values ('Terrible DBA')
Go 1000

declare @counter int = 1
Declare @counter2 int = 0

While @counter < 100000
BEGIN
Delete from WorstTable

	WHILE @counter2<1000
	BEGIN
		Insert into WorstTable Values ('Terrible DBA')
		set @counter2 +=1
	END

set @counter2=0
set @counter +=1
END
---takes 17 seconds
--
DBCC LOGINFO
---8 VLFs


CREATE DATABASE [FireMeVLF]
 ON  PRIMARY 
( NAME = N'FireMeVLF', FILENAME = N'E:\MSSQL\Data\FireMeVLF.mdf' , SIZE = 3072KB , FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'FireMeVLF_log', FILENAME = N'E:\MSSQL\Logs\FireMeVLF_log.ldf' , SIZE = 1MB , MAXSIZE = 400MB,FILEGROWTH = 1KB)
GO
---CPU time = 0 ms,  elapsed time = 183 ms.
--sub 1 second

ALTER database FiremeVLF SET RECOVERY FULL

USE FireMEVLF
GO

BACKUP DATABASE FireMeVLF to DISK = 'NUL'

Create Table WorstTable
(Data char(8000))
GO


SET NOCOUNT ON

Insert into WorstTable Values ('Terrible DBA')
Go 1000

declare @counter int = 1
Declare @counter2 int = 0

While @counter < 100000
BEGIN
Delete from WorstTable

	WHILE @counter2<1000
	BEGIN
		Insert into WorstTable Values ('Terrible DBA')
		set @counter2 +=1
	END
set @counter2=0
set @counter +=1
END
---Takes 31 seconds

DBCC LOGINFO
---1600 VLFs

USE master
BACKUP LOG KeepMyJobVLF
TO DISK = 'E:\MSSQL\Backups\KeepMyJobVLF.bak'
WITH COMPRESSION
---Takes 1 seconds

USE master
BACKUP LOG FIREMEVLF
TO DISK = 'E:\MSSQL\Backups\FIREMEVLF.bak'
WITH COMPRESSION
---Takes 3 seconds


---Create an open transaction to demonstrate longer recovery time
USE KeepMyJobVLF

SET NOCOUNT ON
Begin Transaction

declare @counter int = 1
Declare @counter2 int = 0

While @counter < 100000
BEGIN
Delete from WorstTable

	WHILE @counter2<1000
	BEGIN
		Insert into WorstTable Values ('Terrible DBA')
		set @counter2 +=1
	END

set @counter2=0
set @counter +=1
END
---Takes ~10 Seconds
---No end
--ROLLBACK Transaction

---Take this to a new window
DBCC LOGINFO
DBCC SQLPERF (LOGSPACE)


USE FireMeVLF

SET NOCOUNT ON
Begin Transaction

declare @counter int = 1
Declare @counter2 int = 0

While @counter < 100000
BEGIN
Delete from WorstTable

	WHILE @counter2<1000
	BEGIN
		Insert into WorstTable Values ('Terrible DBA')
		set @counter2 +=1
	END

set @counter2=0
set @counter +=1
END

--Takes ~11 seconds

--ROLLBACK TRANSACTION


EXEC sp_cycle_errorlog ;
GO
exec sp_readerrorlog

alter database KeepMyJobVLF SET OFFLINE 
alter database FireMeVLF SET OFFLINE

alter database KeepMyJobVLF SET ONLINE
--0 seconds
alter database FireMeVLF SET ONLINE
--~1 seconds

----CLEAN UP
USE master
DROP database KeepMyJobVLF
DROP database FireMeVLF