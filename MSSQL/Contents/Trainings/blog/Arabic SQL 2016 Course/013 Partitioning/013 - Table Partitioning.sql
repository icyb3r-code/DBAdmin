USE MASTER
DROP DATABASE IF EXISTS [DataPartition]
Go
CREATE DATABASE [DataPartition]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'DataPartition', FILENAME = N'E:\MSSQL\DATA\DataPartition.mdf' , SIZE = 8192KB , FILEGROWTH = 65536KB ), 
 FILEGROUP [Data2015] 
( NAME = N'Data2015', FILENAME = N'E:\MSSQL\DATA\Data2015.ndf' , SIZE = 8192KB , FILEGROWTH = 65536KB ), 
 FILEGROUP [Data2016] 
( NAME = N'Data2016', FILENAME = N'E:\MSSQL\DATA\Data2016.ndf' , SIZE = 8192KB , FILEGROWTH = 65536KB ), 
 FILEGROUP [Data2017] 
( NAME = N'Data2017', FILENAME = N'E:\MSSQL\DATA\Data2017.ndf' , SIZE = 8192KB , FILEGROWTH = 65536KB ), 
 FILEGROUP [ArchiveData] 
( NAME = N'ArchiveData', FILENAME = N'E:\MSSQL\DATA\ArchiveData.ndf' , SIZE = 8192KB , FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'DataPartition_log', FILENAME = N'E:\MSSQL\LOGS\DataPartition_log.ldf' , SIZE = 8192KB , FILEGROWTH = 65536KB )
GO

Use DataPartition
GO

CREATE PARTITION FUNCTION DataYearPartitionFn (datetime2)
as RANGE RIGHT
FOR VALUES ('01-01-2015','01-01-2016')
---Values for 2014 and Before will go into Archive Filegroup and File
---Values starting 1/1/2015 until 12/31/2015 will go to Data2015 FileGroup
---Values starting 1/1/2016 until 12/31/2016 will go to Data2016 FileGroup
---Any data after 12/31/2016 will go into the FileGroup Data2016
---This is because we did not add a range for 2017 in our function

--Check Partition Range Values
---find ranges for partitions
select *
from sys.partition_functions f
inner join sys.partition_range_values rv on f.function_id=rv.function_id
where f.name = 'DataYearPartitionFn'


CREATE PARTITION SCHEME DateYearPartition
AS PARTITION DataYearPartitionFn
TO (ArchiveData,Data2015,Data2016)

 --Check on Partition Scheme
select *
from sys.partition_schemes


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

--See information on partitioned data
SELECT object_name(object_id) , *
From sys.dm_db_partition_stats
WHERE Object_name(Object_id) = 'Orders'

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

--Check data in partitions
SELECT *, $PARTITION.DataYearPartitionFn(OrderDate) as PartitionNumber
FROM Orders


----Find number of rows per partition
select t.name, p.*
from sys.partitions p
inner join sys.tables t on p.object_id=t.object_id
and t.name = 'Orders'
 
--See information on partitioned data
SELECT object_name(object_id) as TableName, *
From sys.dm_db_partition_stats
WHERE Object_name(Object_id) = 'Orders'

