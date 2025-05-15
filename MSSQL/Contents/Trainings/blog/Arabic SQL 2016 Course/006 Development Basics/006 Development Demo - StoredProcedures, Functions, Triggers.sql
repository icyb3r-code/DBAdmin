USE ArabicSQL
GO

Create Procedure pr_CustomerOrder
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

--Test Procedure
EXEC dbo.pr_CustomerOrder 'Ahmed','El-Ghazali','Runner 1.0','Red',1
EXEC dbo.pr_CustomerOrder 'Ayman','El-Ghazali','Runner 1.0','Silver',1  --ERROR will not show
EXEC dbo.pr_CustomerOrder 'Islam','El-Ghazali','Runner 2.0','Silver',1

--Scalar Function

Create Function dbo.fn_CalculateTax 
(
@inputPrice money
)

RETURNS Money
AS
BEGIN


DECLARE @taxedamount Money

SET @taxedamount=@inputPrice * 1.07 ---adding 7% sales tax

Return @taxedamount

END


Select *,dbo.fn_CalculateTax(ProductPrice) as TaxedAmount
From products

--Table Values Function

CREATE FUNCTION dbo.fn_ReturnSalesByCountry
(	
	@countrycode varchar(4)
)
RETURNS TABLE 
AS
RETURN 
(

Select 
CASE 
When C.Country = 'USA' then 'United States of America'
When C.Country= 'UK' then 'United Kingdom'
Else C.Country
End as CountryName,
SUM(P.ProductPrice*O.Quantity) as 'Total Cost for All Orders',
Avg(P.ProductPrice) as 'Average Product Price',SUM(O.Quantity) as 'Total Quantity of Items'
From Customers C
Inner Join CustomerOrders CO on CO.CustomerID=C.CustomerID
Inner Join Orders O on O.OrderID=CO.OrderID
Inner Join Products P on P.ProductID = O.ProductID
Where C.Country= @countrycode
Group by C.Country
)
GO

Select *
from dbo.fn_ReturnSalesByCountry('USA')

Select *
from dbo.fn_ReturnSalesByCountry('UK')

--Can be used in a Join

Create Table Currency
(
CountryName varchar(100),
CurrencyType varchar(100)
)

Insert into Currency Values ('United States of America','Dollars'),('United Kingdom','Pounds')

Select *
from dbo.fn_ReturnSalesByCountry('USA') S
Inner Join Currency C on C.CountryName=S.CountryName

--Can insert results into a new Table

Select S.*,C.CurrencyType into #SalesResults
from dbo.fn_ReturnSalesByCountry('USA') S
Inner Join Currency C on C.CountryName=S.CountryName

Select *
from #SalesResults

--Triggers
Create Table AuditTable
(
LoginName varchar(100),
OldValue varchar(100),
NewValue varchar(100),
DateAndTime datetime2 DEFAULT getdate()
)


CREATE Trigger dbo.tr_ModifyCustomerName
ON dbo.Customers
AFTER UPDATE
as
BEGIN

	Insert into AuditTable (LoginName, Oldvalue, NewValue)
	select system_user, d.FirstName +' '+ d.LastName as OldValue, i.FirstName +' '+ i.LastName as NewValue
	From inserted i inner join 
	deleted d on i.CustomerID=d.CustomerID

END

Update Customers
Set FirstName = 'Trigger'
Where FirstName = 'Trigger'

Select *
from AuditTable

CREATE Trigger dbo.tr_BlockDeleteCustomerName
ON dbo.Customers
INSTEAD OF DELETE
as 
BEGIN
Print 'Cannot Delete From This Table'

ROLLBACK TRANSACTION

END

Delete from Customers

Select *
from Customers



---Clean up

Drop Procedure dbo.pr_CustomerOrder
Drop Function dbo.fn_CalculateTax
Drop Function dbo.fn_ReturnSalesByCountry
DROP Trigger dbo.tr_ModifyCustomerName
DROP Trigger dbo.tr_BlockDeleteCustomerName