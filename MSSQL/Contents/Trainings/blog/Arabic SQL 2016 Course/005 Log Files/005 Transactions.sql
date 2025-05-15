DROP DATABASE IF EXISTS TestDB
Go

Create Database TestDB
go

USE TestDB
Go
Create Table TestTable
(
TableKey int Identity (1,1),
Name varchar(100)
)
Go

--Implicit Transaction
Insert Into TestTable (Name) Values ('Implicit Transaction')

--Explicit Transaction
Begin Transaction
Insert Into TestTable (Name) Values ('Explicit Transaction')

Rollback Transaction
--Commit Transaction

---Take to another Window

--Should work in this window
Select *
from TestTable

Select *
from TestTable(ReadPast)

Select *
from TestTable (NOLOCK)

--Nested Transaction
SET IMPLICIT_TRANSACTIONS ON;

Begin Transaction --Outer Transaction
	Insert Into TestTable (Name) Values ('Outer Transaction')

	Begin Transaction --Inner Transaction		
		Insert Into TestTable (Name) Values ('Inner Transaction')
	COMMIT Transaction

ROLLBACK Transaction

Select *
from TestTable

--Table variable unaffected by transactions

Declare @TestTable as Table
(
TableKey int Identity (1,1),
Name varchar(100)
)

Begin Transaction
Insert Into @TestTable (Name) Values ('Table Variable - unaffected by Transaction rollback')

Rollback Transaction


Select *
from @TestTable

