USE Master
GO
DROP DATABASE IF EXISTS ArabicSQL
GO

Create Database ArabicSQL
Go

Use ArabicSQL
Go

---Tables
Create Table Customers
(
CustomerID Int Identity (1,1) NOT NULL PRIMARY KEY, --(Seed,Increment)
FirstName varchar(100) NOT NULL,
LastName varchar(100) NOT NULL,
DateOfBirth date,
StreetAddress varchar(100),
City varchar(100),
State varchar(100),
Country varchar(50),
)


Insert Into Customers (FirstName,LastName,DateOfBirth,StreetAddress,City,State,Country) 
Values ('Ahmed','El-Ghazali','1/1/1975','123 Main Street','Philadelphia','PA','USA')   --CustomerID 1
Insert Into Customers (FirstName,LastName,DateOfBirth,StreetAddress,City,State,Country) 
Values ('Ayman','El-Ghazali','1/1/1980','123 Main Street','Washington','DC','USA') --CustomerID 2
Insert Into Customers (FirstName,LastName,DateOfBirth,StreetAddress,City,State,Country) 
Values ('Islam','El-Ghazali','1/1/1990','123 Main Street','Southhampton',NULL,'UK')   --CustomerID 3

Create Table Products
(
ProductID  Int Identity (1000,1) NOT NULL PRIMARY KEY,
ProductName varchar(200),
ProductDescription varchar(200),
Manufacturer varchar(100),
ProductPrice Money,
ProductColor varchar(20)
)

Insert into Products Values ('Runner 1.0','Running Shoes for physical Activity','Shozes',99.99,'Red') --ProductID 1000
Insert into Products Values ('Runner 1.0','Running Shoes for physical Activity','Shozes',89.99,'Black') --ProductID 1001
Insert into Products Values ('Runner 1.0','Running Shoes for physical Activity','Shozes',89.99,'Navy Blue') --ProductID 1002
Insert into Products Values ('Runner 1.0','Running Shoes for physical Activity','Shozes',75,'White') --ProductID 1003
Insert into Products Values ('Runner 2.0','Running Shoes for physical Activity','Shozes',125,'Silver') --ProductID 1004

Create Table Orders
(
OrderID Int Identity (1000,1) NOT NULL PRIMARY KEY,
ProductID Int,
Quantity Int,
OrderDate datetime2 DEFAULT getdate()
)

Insert Into Orders (ProductID,Quantity) Values (1000,1)  --OrderID 1000
Insert Into Orders (ProductID,Quantity) Values (1000,2)  --OrderID 1001
Insert Into Orders (ProductID,Quantity) Values (1001,2)  --OrderID 1002
Insert Into Orders (ProductID,Quantity) Values (1001,2)  --OrderID 1003
Insert Into Orders (ProductID,Quantity) Values (1002,1)  --OrderID 1004
Insert Into Orders (ProductID,Quantity) Values (1004,3)  --OrderID 1005
Insert Into Orders (ProductID,Quantity) Values (1003,7)  --OrderID 1006
Insert Into Orders (ProductID,Quantity) Values (1004,2)  --OrderID 1007
Insert Into Orders (ProductID,Quantity) Values (1004,1)  --OrderID 1008


Create Table CustomerOrders
(
CusotmerOrderID int IDENTITY (1000,1) NOT NULL PRIMARY KEY,
CustomerID int,
OrderID int,

)

Insert into CustomerOrders Values (1,1000) --CustomerOrderID 1000
Insert into CustomerOrders Values (1,1001) --CustomerOrderID 1001
Insert into CustomerOrders Values (2,1002) --CustomerOrderID 1002
Insert into CustomerOrders Values (2,1003) --CustomerOrderID 1003
Insert into CustomerOrders Values (3,1004) --CustomerOrderID 1004
Insert into CustomerOrders Values (3,1005) --CustomerOrderID 1005
Insert into CustomerOrders Values (3,1006) --CustomerOrderID 1006
Insert into CustomerOrders Values (1,1007) --CustomerOrderID 1007
Insert into CustomerOrders Values (2,1008) --CustomerOrderID 1008


Select *
from Customers

Select *
From Products

Select *
From Orders

Select *
From CustomerOrders


----Get useful information
Select *
From Customers C
Inner Join CustomerOrders CO on CO.CustomerID=C.CustomerID
Inner Join Orders O on O.OrderID=CO.OrderID
Inner Join Products P on P.ProductID = O.ProductID

--Make it look Nicer

Select C.FirstName,C.LastName,o.OrderID,P.ProductName,P.ProductPrice,O.Quantity,P.ProductPrice*O.Quantity as 'Total Order Cost'
From Customers C
Inner Join CustomerOrders CO on CO.CustomerID=C.CustomerID
Inner Join Orders O on O.OrderID=CO.OrderID
Inner Join Products P on P.ProductID = O.ProductID

--Aggregate by Customer
Select C.FirstName,C.LastName,P.ProductName,SUM(P.ProductPrice*O.Quantity) as 'Total Cost for All Orders'
From Customers C
Inner Join CustomerOrders CO on CO.CustomerID=C.CustomerID
Inner Join Orders O on O.OrderID=CO.OrderID
Inner Join Products P on P.ProductID = O.ProductID
Group by C.FirstName,C.LastName,P.ProductName
Order by LastName, FirstName, ProductName

--More Aggregation

Select C.FirstName,C.LastName,SUM(P.ProductPrice*O.Quantity) as 'Total Cost for All Orders',
Avg(P.ProductPrice) as 'Average Product Price',SUM(O.Quantity) as 'Total Quantity of Items'
From Customers C
Inner Join CustomerOrders CO on CO.CustomerID=C.CustomerID
Inner Join Orders O on O.OrderID=CO.OrderID
Inner Join Products P on P.ProductID = O.ProductID
Group by C.FirstName,C.LastName
Order by LastName, FirstName

--Views

Create View v_CustomerOrderTotals
as 

Select C.FirstName,C.LastName,SUM(P.ProductPrice*O.Quantity) as 'Total Cost for All Orders',
Avg(P.ProductPrice) as 'Average Product Price',SUM(O.Quantity) as 'Total Quantity of Items'
From Customers C
Inner Join CustomerOrders CO on CO.CustomerID=C.CustomerID
Inner Join Orders O on O.OrderID=CO.OrderID
Inner Join Products P on P.ProductID = O.ProductID
Group by C.FirstName,C.LastName


Select * from v_CustomerOrderTotals

--DDL and DML
--Adding a Column
Alter Table Customers
Add Gender char(1)

--Update data
Update Customers
Set Gender = 'M'
Where FirstName = 'Ayman'

Select *
from Customers

--Insert and Delete
Insert Into Customers (FirstName,LastName,DateOfBirth,StreetAddress,City,State,Country) 
Values ('Delete','Delete','1/1/1975','Delete','Delete','DE','DEL')   

Delete From Customers
Where CustomerID = 4

--CTE - Common Table Expression
WITH TestCTE
as
(
Select C.FirstName,C.LastName,SUM(P.ProductPrice*O.Quantity) as 'Total Cost for All Orders',
Avg(P.ProductPrice) as 'Average Product Price',SUM(O.Quantity) as 'Total Quantity of Items'
From Customers C
Inner Join CustomerOrders CO on CO.CustomerID=C.CustomerID
Inner Join Orders O on O.OrderID=CO.OrderID
Inner Join Products P on P.ProductID = O.ProductID
Group by C.FirstName,C.LastName
)

Select *
FROM TestCTE
Order by LastName, FirstName

--Clean Up
Drop View v_CustomerOrderTotals
Drop Table Customers
Drop Table CustomerOrders
Drop Table Orders
Drop Table Products