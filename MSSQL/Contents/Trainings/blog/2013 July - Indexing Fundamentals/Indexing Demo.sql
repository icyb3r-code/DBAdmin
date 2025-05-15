Create Database IndexDemo
Go 
USE IndexDemo
Go
----Create Table with Primary key
---This script will automatically name the PK Constraint and create a Clustered Index
Create Table ClusteredTableTest
(
EmpID int identity (1,1) Primary Key,
LastName Varchar(50),
FirstName Varchar(50),
Age int
)

----Get information about the table and indexes on it
EXEC sp_help ClusteredTableTest

----Create Table with Primary key
---You can define the name of the PK Constraint and Clustered Index will automatically be created
Create Table ClusteredTable1
(
EmpID int identity (1,1),
LastName Varchar(50),
FirstName Varchar(50),
Age int,
CONSTRAINT PK_ClusteredTable1_EmpID PRIMARY KEY (EmpID))

---Cannot Drop the Index since it is a PK
DROP INDEX PK_ClusteredTable1_EmpID on ClusteredTable1

----Must use Alter Command to drop the constraint first
----This will drop the PK and the Clustered Index
Alter Table ClusteredTable1 DROP Constraint PK_ClusteredTable1_EmpID

---Create another table with no PK
Create Table ClusteredTable2
(
EmpID int identity (1,1),
LastName Varchar(50),
FirstName Varchar(50),
Age int
)

---Create Clustered Index on Last Name Column without making it a Primary Key
Create Clustered Index IX_ClusteredTable2_LastName on ClusteredTable2(LastName)

---Can Create a separate PK for the table that is not part of the clustered Index
Alter Table ClusteredTable2
Add Constraint PK_ClusteredTable2_EmpID Primary Key (EmpID)
---A Non-Clustered Index on the PK will automatically be created

---Get information about Indexes on a table
EXEC sp_helpindex ClusteredTable2

---Can Drop the Clustered Index since it is not a PK
DROP INDEX IX_ClusteredTable2_LastName on ClusteredTable2

---Still cannot drop the PK 
DROP INDEX PK_ClusteredTable2_EmpID on ClusteredTable2

---Create Non-Clustered Index on Table2 on First Name
---This Clustered Index will have a fill factor of 50%
Create NonClustered Index IX_ClusteredTable2_FirstName on ClusteredTable2(FirstName)
WITH FillFactor = 50

---Get information on specific indexes
select object_name(object_id) as TableName, name as IndexName,type_desc, is_primary_key,
fill_factor, is_padded
from sys.indexes
where object_name(object_id) = 'ClusteredTable2'

----Can Drop this Non-Clustered Index
DROP INDEX IX_ClusteredTable2_FirstName on ClusteredTable2

---Clean UP
Drop Table ClusteredTableTest
Drop Table ClusteredTable1
Drop Table ClusteredTable2

---Remove entire Database
Use Master
Drop Database IndexDemo