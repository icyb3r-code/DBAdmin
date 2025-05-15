DBCC Traceon (3004,3605,-1)
GO

EXEC sp_cycle_errorlog ;
GO
EXEC sp_readerrorlog
--Turn on Trace Flag to view IFI info

Set Statistics TIME ON
CREATE DATABASE GoodVLF
 ON  PRIMARY 
( NAME = N'GoodVLF', FILENAME = N'Z:\SQLDATA\GoodVLF.mdf' , SIZE = 3072KB , FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'GoodVLF_log', FILENAME = N'Y:\SQLLOGS\GoodVLF_log.ldf' , SIZE = 800MB , FILEGROWTH = 100MB)
GO
---  CPU time = 16 ms,  elapsed time = 2632 ms.
USE GoodVLF
DBCC LOGINFO
---Number of Rows = # VLFs
--Size ~100MB for each VLF
--8 VLFs Size 64MB each
 

CREATE DATABASE BadVLF
 ON  PRIMARY 
( NAME = N'BadVLF', FILENAME = N'Z:\SQLDATA\BadVLF.mdf' , SIZE = 3072KB , FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'BadVLF_log', FILENAME = N'Y:\SQLLOGS\BadVLF_log.ldf' , SIZE = 1MB , FILEGROWTH = 10%)
GO
--CPU time = 0 ms,  elapsed time = 164 ms.

--Took less time to create, but will grow more and may affect other DB Log growth occuring at the same time
--IFI does not affect Log Files

--Initial backup so DBs are set to grow log otherwise it behaves like SIMPLE Recovery
ALTER DATABASE GoodVLF SET RECOVERY FULL
ALTER DATABASE BADVLF SET RECOVERY FULL
BACKUP DATABASE GoodVLF to DISK = 'NUL'
BACKUP DATABASE BadVLF to DISK = 'NUL'

USE BadVLF
DBCC LOGINFO
--4 VLFs Size of 256KB each

---Get free space in Logs
DBCC SQLPERF (LOGSPACE)

--Used space for GoodVLF less than 1%
--Used space for BadVLF ~55%

USE GoodVLF
Create Table Dummy
(ID int,
Text varchar(100))

Create Clustered Index IDX_ID on dbo.Dummy(ID)
GO


SET STATISTICS TIME OFF
SET NOCOUNT ON
Declare @counter int = 0
Declare @counter2 int = 0

PRINT Format(Getdate(),'M/dd/y hh:mm:ss')

While @counter <50000
Begin	



WHILE @counter2<100000
BEGIN
		
		Insert Into Dummy(ID,Text) values (RAND()*10000,'Test')
		set @counter2+=1
		---same as set @counter2 = @counter2 + 1
END

	ALTER INDEX IDX_ID ON dbo.Dummy REORGANIZE
	
	Delete From Dummy

	Set @counter+=1

END


PRINT Format(Getdate(),'M/dd/y hh:mm:ss')
--1 minute 4 Seconds

DBCC LOGINFO
--8 VLFs



USE BADVLF
Create Table Dummy
(ID int,
Text varchar(100))

Create Clustered Index IDX_ID on dbo.Dummy(ID)
GO

SET STATISTICS TIME OFF
SET NOCOUNT ON
Declare @counter int = 0
Declare @counter2 int = 0

PRINT Format(Getdate(),'M/dd/y hh:mm:ss')

While @counter <50000
Begin	



WHILE @counter2<100000
BEGIN
		
		Insert Into Dummy(ID,Text) values (RAND()*10000,'Test')
		set @counter2+=1
		---same as set @counter2 = @counter2 + 1
END

	ALTER INDEX IDX_ID ON dbo.Dummy REORGANIZE
	
	Delete From Dummy

	Set @counter+=1

END

PRINT Format(Getdate(),'M/dd/y hh:mm:ss')
--1 Minute 16 Seconds

DBCC LOGINFO
--68 VLFs, uneven in size

---Do The Same for BADVLF

---Fix the problem
---Truncate and Shrink LogFile first

---Clears Log
ALTER DATABASE BadVLF SET RECOVERY SIMPLE

USE BadVLF
DBCC ShrinkFile ('BadVLF_log',0)

ALTER DATABASE BadVLF MODIFY FILE ( NAME = N'BadVLF_log', SIZE = 200MB )
GO

ALTER DATABASE BadVLF MODIFY FILE ( NAME = N'BadVLF_log', SIZE = 400MB )
GO

ALTER DATABASE BadVLF MODIFY FILE ( NAME = N'BadVLF_log', SIZE = 600MB )
GO

ALTER DATABASE BadVLF MODIFY FILE ( NAME = N'BadVLF_log', SIZE = 800MB )
GO

ALTER DATABASE BadVLF MODIFY FILE ( NAME = N'BadVLF_log', MAXSIZE = UNLIMITED, FILEGROWTH = 100MB)
GO


--DO THIS AFTER FINAL DEMO
/*Clean Up*/
Use MASTER
GO
DROP Database GoodVLF
DROP Database BadVLF

DBCC Traceoff (3004,3605,-1)
GO

