--Variables
Declare @TotalSales money
Set @TotalSales = 100

Print @TotalSales

--Declare and Set
Declare @TotalSales money = 1000

Print @TotalSales

Declare @MonthlySales Table
(
MonthName varchar(20),
SalesAmount money
)

Insert into @MonthlySales VALUES ('March',@TotalSales)

Select *
from @MonthlySales

---Temporary Tables
Create Table #MonthlySales
(
MonthName varchar(20),
SalesAmount money
) 

Insert into #MonthlySales VALUES ('March',1000), ('April',2000)

--Try this in a New Window it will not work
Select *
from #MonthlySales

Drop Table #MonthlySales

--Recreate at Global Temp Table

Create Table ##MonthlySales
(
MonthName varchar(20),
SalesAmount money
) 

Insert into ##MonthlySales VALUES ('March',1000), ('April',2000)

--Try this in a New Window
Select *
from ##MonthlySales

Drop Table ##MonthlySales

--Create Temp Table from existing Table

Select * into #TempTable
from dbo.Customers

Select *
from #TempTable


--Temporary Stored Procedure

Create Procedure #pr_CustomerOrder
(
@CustomerFirstName varchar(100),
@CustomerLastName varchar(100),
@ProductName varchar(200),
@ProductColor varchar(20),
@Quantity int
)
as

Begin

Declare @CustomerID int
Declare @ProductID int

Select @CustomerID =  CustomerID
From dbo.Customers
Where FirstName=@CustomerFirstName and LastName=@CustomerLastName

Select @ProductID=ProductID
From Products
Where ProductName = @ProductName and ProductColor=@ProductColor

Insert Into Orders (ProductID,Quantity) Values (@ProductID,@Quantity) 

If @ProductID IS NOT NULL
Begin
	Insert into CustomerOrders (CustomerID,OrderID)  Values (@CustomerID,scope_identity())  --scope_identity() takes ID from Orders)

	Print 'Customer Order Completed'
END
ELSE
BEGIN
	Print 'Customer Order Failed: ProductID cannot be NULL'
END

End

--Close this window and try to run this from another window
EXEC dbo.#pr_CustomerOrder 'TEST','TEST','TEST','TEST',1