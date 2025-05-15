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

INSERT INTO LockingTable (UpdateType) Values ('Read Committed')
INSERT INTO LockingTable (UpdateType) Values ('Read UNCommitted')
INSERT INTO LockingTable (UpdateType) Values ('Repeatable Read')
INSERT INTO LockingTable (UpdateType) Values ('Serializable')

Select *
from LockingTable

---Read Committed Example
--Insert
INSERT INTO LockingTable (UpdateType,Notes) Values 
('Read Committed','Inserted During ReadCommitted Isolation Level')
WAITFOR DELAY '00:00:05'
--Update
Update LockingTable
Set Notes = 'Read Committed - Updated'
Where TableKey=1
WAITFOR DELAY '00:00:05'
--Delete
Delete From LockingTable Where TableKey=1
WAITFOR DELAY '00:00:05'
Select *
from LockingTable


INSERT INTO LockingTable (UpdateType,Notes) Values ('Read Committed','Inserted During ReadCommitted Isolation Level')

INSERT INTO LockingTable (UpdateType,Notes) Values ('Read Committed','Inserted During ReadCommitted Isolation Level')

--Window 2

--Default Isolation Level -- READ COMMITTED
SET TRANSACTION ISOLATION LEVEL READ COMMITTED

BEGIN TRANSACTION

Select *
FROM Lockingtable
WAITFOR DELAY '00:00:05'
Select *
FROM Lockingtable
WAITFOR DELAY '00:00:05'
Select *
FROM Lockingtable
WAITFOR DELAY '00:00:05'

COMMIT TRANSACTION

---Copy select to another Window
SELECT *
FROM Lockingtable



---Read Uncommitted
BEGIN TRANSACTION

Declare @tablekey int

Select @tablekey = tablekey
FROM Lockingtable
Where UpdateType ='Read UnCommitted'

Update LockingTable
Set Notes = 'Read UnCommitted - Updated'
Where TableKey=@tablekey

--Don't run this yet
RollBack Transaction
---Copy select to another Window
SELECT *
FROM Lockingtable (NOLOCK)

--or

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT *
FROM Lockingtable

---Repeatable Read

--Default Isolation Level -- READ COMMITTED
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ

BEGIN TRANSACTION

Select *
from LockingTable
Where UpdateType ='Repeatable Read'

Declare @tablekey int

Select @tablekey = tablekey
FROM Lockingtable
Where UpdateType ='Repeatable Read'

Update LockingTable WiTH (RowLock)
Set Notes = 'Repeatable Read - Updated'
Where TableKey=@tablekey

Select *
from LockingTable
Where UpdateType ='Repeatable Read'


---Don't run this yet
ROLLBACK TRANSACTION

---Copy select to another Window
SELECT *
FROM Lockingtable