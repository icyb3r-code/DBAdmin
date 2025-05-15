---Demos adopted from Gavin Draper's Blog
---http://www.gavindraper.co.uk/2012/02/18/sql-server-isolation-levels-by-example/

---Window 1

Create Database LockingDemo
Go

USE LockingDemo
--Truncate Table LockingTable
Create Table LockingTable
(
TableKey Int Identity (1,1),
UpdateType varchar(50),
Notes varchar(100)
)

INSERT INTO LockingTable (UpdateType,Notes) Values ('Read Committed','No Notes')
INSERT INTO LockingTable (UpdateType,Notes) Values ('Read UNCommitted','No Notes')
INSERT INTO LockingTable (UpdateType,Notes) Values ('Repeatable Read','No Notes')
INSERT INTO LockingTable (UpdateType,Notes) Values ('Serializable','No Notes')

--Look at Data
Select *
from LockingTable

----************************
---Read Committed Example
BEGIN TRANSACTION

Update LockingTable
Set Notes = 'Read Committed Isolation Level'
Where UpdateType = 'Read Committed'

WAITFOR DELAY '00:00:10'

ROLLBACK

--Run in a new Query Window
Select *
From LockingTable


----************************
---Read Uncommitted Example

BEGIN TRANSACTION

Update LockingTable
Set Notes = 'Read UNCommitted Isolation Level'
Where UpdateType = 'Read UNCommitted'

WAITFOR DELAY '00:00:10'

ROLLBACK

--Run in a new Query Window
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
Select *
From LockingTable

--This is the same as setting the Isolation Level to Read Uncomitted
Select *
from LockingTable(NOLOCK)

----************************
---Repeatable Read

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ

BEGIN TRANSACTION

Select *
from LockingTable
Where UpdateType ='Repeatable Read'

WAITFOR DELAY '00:00:10'

Select *
from LockingTable
Where UpdateType ='Repeatable Read'

ROLLBACK
--Run in a new Query Window
--This must be run before the second select statement goes through

Update LockingTable
Set Notes = 'Repeatable Read - Updated during transaction'
WHERE UpdateType ='Repeatable Read'

--Run this after the update in the new query window
Select *
from LockingTable
Where UpdateType ='Repeatable Read'

----************************
---Serializable

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE

BEGIN TRANSACTION

Select *
from LockingTable

WAITFOR DELAY '00:00:10'

Select *
from LockingTable

ROLLBACK

--Run in a new Query Window

Update LockingTable
Set Notes = 'Serializable - Updated during transaction'
WHERE UpdateType ='Serializable'

---Try an insert

INSERT INTO LockingTable (UpdateType,Notes) Values ('Serializable','Inserted during Serializable Transaction')

