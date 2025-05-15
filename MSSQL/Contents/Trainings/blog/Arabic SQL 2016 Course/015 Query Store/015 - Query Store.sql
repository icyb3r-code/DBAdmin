Use Master
Go
DROP Database IF EXISTS QueryStoreDemo
Go
Create Database QueryStoreDemo
Go

ALTER DATABASE QueryStoreDemo SET AUTO_UPDATE_STATISTICS OFF 
GO
ALTER DATABASE QueryStoreDemo SET AUTO_CREATE_STATISTICS OFF 
GO
ALTER DATABASE QueryStoreDemo SET RECOVERY SIMPLE 
GO

USE QueryStoreDemo
Go

--Drop table FactInternetSales
Select * into FactInternetSales
From AdventureWorksDW2014.dbo.FactInternetSales

ALTER DATABASE QueryStoreDemo SET QUERY_STORE = ON
Go

ALTER DATABASE [QueryStoreDemo] SET QUERY_STORE 
(OPERATION_MODE = READ_WRITE, DATA_FLUSH_INTERVAL_SECONDS = 60, 
INTERVAL_LENGTH_MINUTES = 1)
GO

set statistics io on
Select *  
From FactInternetSales

select Distinct currencykey, count(1)
from FactInternetSales
group by CurrencyKey

Select *  
From FactInternetSales
where CurrencyKey = 6

Select *  
From FactInternetSales
where CurrencyKey = 29

--Create nonclustered index
---Drop Index IX_FIS_CurrencyKey on FactInternetSales
Create Nonclustered Index IX_FIS_CurrencyKey on FactInternetSales
(
CurrencyKey Desc
)

----run query again
--Should do a non-clustered index seek this time

Select *  
From FactInternetSales
where CurrencyKey = 6

Select *  
From FactInternetSales
where CurrencyKey = 29

---Add more data
Insert into FactInternetSales
Select * 
From AdventureWorksDW2014.dbo.FactInternetSales

Select *  
From FactInternetSales
where CurrencyKey = 29

Create clustered Index CIX_FIS_CurrencyKey on FactInternetSales
(
CurrencyKey Desc
)

Select *  
From FactInternetSales
where CurrencyKey = 29

---Try above query again

--Clean up query store

ALTER DATABASE QueryStoreDemo SET QUERY_STORE CLEAR;  