---Index Maintenance
Create Database IndexMaintenanceDemo
Go
USE IndexMaintenanceDemo
Go

Create Table IndexMaintTest
(
EmpID int,
LastName Varchar(50),
FirstName Varchar(50),
Age int
)

Create Clustered Index IX_IndexMaintTest_EmpID on IndexMaintTest(EmpID)

---Verify Table Structure and indexes
Exec sp_help IndexMaintTest
EXEC sp_helpindex IndexMaintTest

---Check Fragmentation of Index
--Should be 0 since there is no data
SELECT db_id(database_id) as DBName,object_id(object_id) as TableName, index_id, 
index_type_desc, avg_fragmentation_in_percent,fragment_count,avg_fragment_size_in_pages,page_count
FROM sys.dm_db_index_physical_stats(DB_ID('IndexMaintenanceDemo'),Object_ID('IndexMaintTest'),NULL,NULL,NULL)

---Let's put some data!
Declare @counter int = 0 

While @counter <10000
Begin
Insert Into IndexMaintTest (EmpID,LastName,FirstName,Age) Values (cast(rand()*1000000 as int),'LastName','FirstName',0)
---Code will create Random number for EmployeeID which should give us some fun results
set @counter+=1
--print @counter
End


--Verify that there is data
select count(EmpID)
from IndexMaintTest

---Can use this query to get some statistics on indexes
DBCC SHOW_STATISTICS (IndexMaintTest,IX_IndexMaintTest_EmpID)

---Check Fragmentation of Index
SELECT db_name(database_id) as DBName,object_name(object_id) as TableName, index_id, 
index_type_desc, avg_fragmentation_in_percent,fragment_count,avg_fragment_size_in_pages,page_count
FROM sys.dm_db_index_physical_stats(DB_ID('IndexMaintenanceDemo'),Object_ID('IndexMaintTest'),NULL,NULL,NULL)

--Create Non-Clustered Index on LastName
Create NonClustered Index IX_IndexMaintTest_LastName on IndexMaintTest(LastName)

---Verify the index exists
Exec sp_helpindex IndexMaintTest

---Check Fragmentation of Index
SELECT db_name(database_id) as DBName,object_name(object_id) as TableName, index_id, 
index_type_desc, avg_fragmentation_in_percent,fragment_count,avg_fragment_size_in_pages,page_count
FROM sys.dm_db_index_physical_stats(DB_ID('IndexMaintenanceDemo'),Object_ID('IndexMaintTest'),NULL,NULL,NULL)
---Go back and do inserts then check again

---There are several techniques to index maintenance
---This does not lock the index
--_DBNAME,TABLENAME,INDEXNAME
DBCC INDEXDEFRAG (IndexMaintenanceDemo,IndexMaintTest,IX_IndexMaintTest_LastName)

---ReOrganize Non-Clustered Index
ALTER INDEX IX_IndexMaintTest_LastName on dbo.IndexMaintTest REORGANIZE
---Check, fragmentation there will still be some
---Run again and Check

---ReBuild Clustered Index
ALTER INDEX IX_IndexMaintTest_EmpID on dbo.IndexMaintTest REBUILD
WITH (ONLINE=ON)  
---ONLINE=ON is an ENTERPISE ONLY OPTION
---Check Fragmentation, should be 0!

---Can issue a create index command with DROP_EXISTING
Create NonClustered Index IX_IndexMaintTest_LastName on IndexMaintTest(LastName)
WITH DROP_EXISTING

---There are a few other techniques that can be explored in BOL
---Note: These Maintenance tasks should not be done during Peak production hours

---Cleanup
DROP TABLE IndexMaintTest

Use MASTER
Drop Database IndexMaintenanceDemo
