DROP Database IF EXISTS CSIM
GO
Create Database CSIM
GO
USE CSIM
GO

---Create first table
Select * Into FactInternetSales
FROM AdventureWorksDW2014.dbo.FactInternetSales

--Create Regular Clustered Index
ALTER TABLE [dbo].[FactInternetSales] 
ADD  CONSTRAINT [PK_FactInternetSales_SalesOrderNumber_SalesOrderLineNumber] 
PRIMARY KEY CLUSTERED 
(
	[SalesOrderNumber] ASC,
	[SalesOrderLineNumber] ASC
)
GO

CREATE NONCLUSTERED INDEX [FactInternetSales_NCI_Date] 
ON [dbo].[FactInternetSales] 
(OrderDate)

--Create Second Table for Clustered Column Store
Select * Into FactInternetSales_CColumnStore
FROM AdventureWorksDW2014.dbo.FactInternetSales

CREATE CLUSTERED COLUMNSTORE INDEX [FactInternetSales_CCI] 
ON [dbo].[FactInternetSales_CColumnStore] 

CREATE NONCLUSTERED INDEX [FactInternetSales_NCI_Date] 
ON [dbo].[FactInternetSales_CColumnStore] 
(OrderDate)

--Create Third Table for Non-Clustered Column Store
Select * Into FactInternetSales_NCColumnStore
FROM AdventureWorksDW2014.dbo.FactInternetSales

CREATE NONCLUSTERED COLUMNSTORE INDEX [FactInternetSales_NCCI] ON [dbo].[FactInternetSales_NCColumnStore]
(
	[OrderQuantity],
	[TotalProductCost],
	[SalesAmount]
)

CREATE NONCLUSTERED INDEX [FactInternetSales_NCI_Date] 
ON [dbo].[FactInternetSales_NCColumnStore] 
(OrderDate)

GO
SET Statistics IO ON
SET Statistics TIME ON
SET NOCOUNT ON

DBCC DROPCLEANBUFFERS
DBCC FREEPROCCACHE

--Date Range
Select SalesOrderNumber
FROM FactInternetSales
Where OrderDate Between '4/1/2016' and '4/15/2016'

Select SalesOrderNumber
FROM FactInternetSales_CColumnStore
Where OrderDate Between '4/1/2016' and '4/15/2016'

Select SalesOrderNumber
FROM FactInternetSales_NCColumnStore
Where OrderDate Between '4/1/2016' and '4/15/2016'

---Aggregates
Select Sum([OrderQuantity]) as SumQuantity,AVG([TotalProductCost]) AverageCost ,Sum(SalesAmount) SumSales
FROM FactInternetSales

Select Sum([OrderQuantity]) as SumQuantity,AVG([TotalProductCost]) AverageCost ,Sum(SalesAmount) SumSales
FROM FactInternetSales_CColumnStore

Select Sum([OrderQuantity]) as SumQuantity,AVG([TotalProductCost]) AverageCost ,Sum(SalesAmount) SumSales
FROM FactInternetSales_NCColumnStore
