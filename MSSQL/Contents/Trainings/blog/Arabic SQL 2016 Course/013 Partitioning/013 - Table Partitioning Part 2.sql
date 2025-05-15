Use DataPartition
GO

Create Table Orders2
(
OrderID Int Identity (10000,1),
OrderDesc Varchar(50),
OrderDate datetime2,
OrderAmount money
)
GO

---Insert 2014 Orders
INSERT INTO Orders2 Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2014-01-01',RAND()*100)
INSERT INTO Orders2 Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2014-02-01',RAND()*100)
INSERT INTO Orders2 Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2014-03-01',RAND()*100)
 
---Insert 2015 Orders
INSERT INTO Orders2 Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2015-01-01',RAND()*100)
INSERT INTO Orders2 Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2015-02-01',RAND()*100)
INSERT INTO Orders2 Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2015-03-01',RAND()*100)
 
---Insert 2016 Orders
INSERT INTO Orders2 Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2016-01-01',RAND()*100)
INSERT INTO Orders2 Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2016-02-01',RAND()*100)
INSERT INTO Orders2 Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2016-03-01',RAND()*100)
 
---Insert 2017 Orders
INSERT INTO Orders2 Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2017-01-01',RAND()*100)
INSERT INTO Orders2 Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2017-02-01',RAND()*100)
INSERT INTO Orders2 Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2017-03-01',RAND()*100)

--Code For Query Window 2
Use DataPartition
 
Begin Tran
 
Update Orders
set OrderDesc = 'Locking for Update'
Where OrderDate = '2015-01-01'
 
Update Orders2
set OrderDesc = 'Locking for Update'
Where OrderDate  = '2015-01-01'

--COMMIT TRANSACTION

--Code For Query Window 3
Use DataPartition
 
SELECT *
FROM Orders
Where OrderDate > = '2016-01-01'
Go
 
SELECT *
FROM Orders
Where OrderDate < '2016-01-01'
Go
 
SELECT *
From Orders2
Where OrderDate > = '2016-01-01'
Go
 
 
--Altering Partitions
--Let us put the 2017 data into a new partition
--Use DataPartition
--Must Alter the Scheme to give is the NEXT FileGroup to use
ALTER PARTITION SCHEME DateYearPartition
NEXT USED Data2017
 
ALTER PARTITION FUNCTION DataYearPartitionFn()
SPLIT RANGE ('2017-01-01');
 
--Check data in partitions
SELECT *, $PARTITION.DataYearPartitionFn(OrderDate) as PartitionNumber
FROM Orders

----Find number of rows per partition
select t.name, p.*
from sys.partitions p
inner join sys.tables t on p.object_id=t.object_id
and t.name = 'Orders'
--
--Remove 2015 Partition using a Merge
--2015 data will go into Archive FG
ALTER PARTITION FUNCTION DataYearPartitionFn ()
MERGE RANGE ('2015-01-01');

--Check data in partitions
SELECT *, $PARTITION.DataYearPartitionFn(OrderDate) as PartitionNumber
FROM Orders

----Find number of rows per partition
select t.name, p.*
from sys.partitions p
inner join sys.tables t on p.object_id=t.object_id
and t.name = 'Orders'

--
--Query to determine table filegroup by index and partition
--Script provided by Jason Strate
--http://www.jasonstrate.com/2013/01/determining-file-group-for-a-table/
--
SELECT OBJECT_SCHEMA_NAME(t.object_id) AS schema_name
,t.name AS table_name
,i.index_id
,i.name AS index_name
,p.partition_number
,fg.name AS filegroup_name
,FORMAT(p.rows, '#,###') AS rows
FROM sys.tables t
INNER JOIN sys.indexes i ON t.object_id = i.object_id
INNER JOIN sys.partitions p ON i.object_id=p.object_id AND i.index_id=p.index_id
LEFT OUTER JOIN sys.partition_schemes ps ON i.data_space_id=ps.data_space_id
LEFT OUTER JOIN sys.destination_data_spaces dds ON ps.data_space_id=dds.partition_scheme_id AND p.partition_number=dds.destination_id
INNER JOIN sys.filegroups fg ON COALESCE(dds.data_space_id, i.data_space_id)=fg.data_space_id
 
---Remove the file and filegroup you no longer need
USE master
GO
ALTER DATABASE DataPartition
REMOVE FILE DATA2015
GO
 
USE master
GO
ALTER DATABASE DataPartition
REMOVE FILEGROUP DATA2015
GO

USE DataPartition
--Switch Data into another table then truncate
Create Table OrdersArchive
(
OrderID Int NOT NULL,
OrderDesc Varchar(50),
OrderDate datetime2,
OrderAmount money
)
ON ArchiveData
GO
 
ALTER TABLE Orders SWITCH Partition 1 to OrdersArchive
 
SELECT *
FROM OrdersArchive
 
SELECT *
FROM Orders

---Switch in data from staging table to Orders table****
Create Table Staging_Orders
(
OrderID Int Identity (10000,1),
OrderDesc Varchar(50),
OrderDate datetime2,
OrderAmount money
)
On DateYearPartition(OrderDate)

---Insert 2017 Orders
INSERT INTO Staging_Orders Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2017-01-01',RAND()*100)
INSERT INTO Staging_Orders Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2017-02-01',RAND()*100)
INSERT INTO Staging_Orders Values ('Order ' + Cast(SCOPE_IDENTITY() as varchar(10)),'2017-03-01',RAND()*100)


ALTER TABLE Staging_Orders SWITCH Partition 4 to Orders

Use Master
GO
ALTER DATABASE DataPartition 
MODIFY FILEGROUP ArchiveData READONLY
GO

