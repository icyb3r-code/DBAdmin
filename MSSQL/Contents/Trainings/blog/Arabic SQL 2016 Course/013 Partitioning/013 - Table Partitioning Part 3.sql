----

USE MASTER
DROP DATABASE IF EXISTS [DataPartitionDR]
Go
CREATE DATABASE [DataPartitionDR]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'DataPartition', FILENAME = N'E:\MSSQL\DATA\DataPartitionDR.mdf' , SIZE = 8192KB , FILEGROWTH = 65536KB ),
 FILEGROUP [Data2015] 
( NAME = N'Data2015', FILENAME = N'E:\MSSQL\DATA\Data2015DR.ndf' , SIZE = 8192KB , FILEGROWTH = 65536KB ),  
 FILEGROUP [Data2016] 
( NAME = N'Data2016', FILENAME = N'E:\MSSQL\DATA\Data2016DR.ndf' , SIZE = 8192KB , FILEGROWTH = 65536KB ), 
 FILEGROUP [ArchiveData] 
( NAME = N'ArchiveData', FILENAME = N'Z:\Archive\ArchiveDataDR.ndf' , SIZE = 8192KB , FILEGROWTH = 65536KB ) ---Needs to be on a separate drive
 LOG ON 
( NAME = N'DataPartition_log', FILENAME = N'E:\MSSQL\LOGS\DataPartitionDR_log.ldf' , SIZE = 8192KB , FILEGROWTH = 65536KB )
GO


Use DataPartitionDR
GO

CREATE PARTITION FUNCTION DataYearPartitionFn (datetime2)
as RANGE RIGHT
FOR VALUES ('01-01-2015','01-01-2016')

CREATE PARTITION SCHEME DateYearPartition
AS PARTITION DataYearPartitionFn
TO (ArchiveData,Data2015,Data2016)

---Create Table on the PartitionScheme
--Name the PartitionScheme with Column to be Partitioned in ()
Create Table Orders
(
OrderID Int Identity (10000,1),
OrderDesc Varchar(50),
OrderDate datetime2,
OrderAmount money
)
ON DateYearPartition (OrderDate)
GO

---Insert 2014 Orders
INSERT INTO Orders Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2014-01-01',RAND()*100)
INSERT INTO Orders Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2014-02-01',RAND()*100)
INSERT INTO Orders Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2014-03-01',RAND()*100)
 
---Insert 2015 Orders
INSERT INTO Orders Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2015-01-01',RAND()*100)
INSERT INTO Orders Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2015-02-01',RAND()*100)
INSERT INTO Orders Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2015-03-01',RAND()*100)
 
---Insert 2016 Orders
INSERT INTO Orders Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2016-01-01',RAND()*100)
INSERT INTO Orders Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2016-02-01',RAND()*100)
INSERT INTO Orders Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2016-03-01',RAND()*100)
 
---Insert 2017 Orders
INSERT INTO Orders Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2017-01-01',RAND()*100)
INSERT INTO Orders Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2017-02-01',RAND()*100)
INSERT INTO Orders Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2017-03-01',RAND()*100)


----Find number of rows per partition
select t.name, p.*
from sys.partitions p
inner join sys.tables t on p.object_id=t.object_id
and t.name = 'Orders'

---For DR Portion
---Run the CHECKPOINT Command before dropping the drive
CHECKPOINT
DBCC DROPCLEANBUFFERS
---Put the disk offline for the Archive FileGroup

USE DataPartitionDR
--Test Queries
SELECT *
FROM Orders
Where OrderDate > = '2016-01-01'
Go

SELECT *
from Orders
Where OrderDate between '2015-01-01' and '2016-01-01'
 
SELECT *
FROM Orders
Where OrderDate < '2015-01-01'
Go

--Try inserts again
--2015 through 2017 should work
--Failure on 2014
 
---Use this to recovery DB
USE MASTER 
ALTER DATABASE DataPartitionDR SET OFFLINE
ALTER DATABASE DataPartitionDR SET ONLINE
