


---In Memory OLTP
USE CSIM
GO

ALTER DATABASE CURRENT  
    SET MEMORY_OPTIMIZED_ELEVATE_TO_SNAPSHOT = ON;  
GO

ALTER DATABASE CSIM ADD FILEGROUP InMemory CONTAINS MEMORY_OPTIMIZED_DATA  
GO

ALTER DATABASE CSIM ADD FILE (name='InMemory', filename='E:\MSSQL\Data\InMemory') TO FILEGROUP InMemory  
Go

--DROP TABLE [FactInternetSales_InMemory]
CREATE TABLE [dbo].[FactInternetSales_InMemory](
	FIS_Key int identity (1,1) PRIMARY KEY NONCLUSTERED HASH WITH (BUCKET_COUNT = 1000),
	[ProductKey] [int] NOT NULL,
	[OrderDateKey] [int] NOT NULL,-- INDEX [Date_IX] HASH WITH (BUCKET_COUNT = 100000),
	[DueDateKey] [int] NOT NULL,
	[ShipDateKey] [int] NOT NULL,
	[CustomerKey] [int] NOT NULL,
	[PromotionKey] [int] NOT NULL,
	[CurrencyKey] [int] NOT NULL,
	[SalesTerritoryKey] [int] NOT NULL,
	[SalesOrderNumber] [nvarchar](20) NOT NULL ,-- PRIMARY KEY NONCLUSTERED HASH WITH (BUCKET_COUNT = 1000),
	[SalesOrderLineNumber] [tinyint] NOT NULL  ,
	[RevisionNumber] [tinyint] NOT NULL,
	[OrderQuantity] [smallint] NOT NULL,
	[UnitPrice] [money] NOT NULL,
	[ExtendedAmount] [money] NOT NULL,
	[UnitPriceDiscountPct] [float] NOT NULL,
	[DiscountAmount] [float] NOT NULL,
	[ProductStandardCost] [money] NOT NULL,
	[TotalProductCost] [money] NOT NULL,
	[SalesAmount] [money] NOT NULL,
	[TaxAmt] [money] NOT NULL,
	[Freight] [money] NOT NULL,
	[CarrierTrackingNumber] [nvarchar](25) NULL,
	[CustomerPONumber] [nvarchar](25) NULL,
	[OrderDate] [datetime] NULL,
	[DueDate] [datetime] NULL,
	[ShipDate] [datetime] NULL
	--CONSTRAINT FISM_PK PRIMARY KEY NONCLUSTERED ([SalesOrderNumber],[SalesOrderLineNumber]) HASH (Bucket_count=100000)
	)
    WITH  (MEMORY_OPTIMIZED = ON,         DURABILITY = SCHEMA_AND_DATA);  
	

INSERT INTO [FactInternetSales_InMemory]
SELECT *
FROM dbo.FactInternetSales
go 7

ALTER TABLE [dbo].[FactInternetSales_InMemory]
	ADD INDEX IX_OrderDate HASH (OrderDate) WITH (BUCKET_COUNT = 1000)
GO

ALTER TABLE [dbo].[FactInternetSales_InMemory]
ADD INDEX [FactInternetSalesInMemory_NCCI] CLUSTERED COLUMNSTORE 

Select *
from sys.tables
Where is_memory_optimized =1

DBCC DROPCLEANBUFFERS

select *
from FactInternetSales
Where OrderDate Between '5/1/2016' and '5/15/2016'

--Select *
--from FactInternetSales_CColumnStore
--Where OrderDate Between '5/1/2016' and '5/15/2016'

--Select *
--From FactInternetSales_NCColumnStore
--Where OrderDate Between '5/1/2016' and '5/15/2016'

SELECT *
FROM [dbo].[FactInternetSales_InMemory]
Where OrderDate Between '5/1/2016' and '5/15/2016'


DBCC DROPCLEANBUFFERS
DBCC FREEPROCCACHE
--Aggregates
Select Sum([OrderQuantity]) as SumQuantity,AVG([TotalProductCost]) AverageCost ,Sum(SalesAmount) SumSales
FROM FactInternetSales
--go 10

--Select Sum([OrderQuantity]) as SumQuantity,AVG([TotalProductCost]) AverageCost ,Sum(SalesAmount) SumSales
--FROM FactInternetSales_CColumnStore

--Select Sum([OrderQuantity]) as SumQuantity,AVG([TotalProductCost]) AverageCost ,Sum(SalesAmount) SumSales
--FROM FactInternetSales_NCColumnStore

Select Sum([OrderQuantity]) as SumQuantity,AVG([TotalProductCost]) AverageCost ,Sum(SalesAmount) SumSales
FROM FactInternetSales_InMemory
--go 10


select *
from FactInternetSales

select *
from FactInternetSales_InMemory

select max(orderdate)
from FactInternetSales_InMemory

select count(1)
from FactInternetSales_InMemory

---use this to demo a workload

SET NOCOUNT ON
Declare @StartDate date = '05-1-2016'
Declare @EndDate date = '06-30-2016'
Declare @OrdersPerDay int = 100 ---Change this number if you want less orders per day.

while @StartDate <= @EndDate
BEGIN --FirstWhile

	Declare @Counter int = 1
	While @Counter <= @OrdersPerDay
	BEGIN --SECONDWHILE
		--Print 'Inserting Data for:'
		--Print @StartDate
		SET @Counter = @Counter +1
		EXEC pr_Simulate_FactInternetSales_InMemory @OrderDate = @StartDate
	END--SECONDWHILE

SET @StartDate = Format(DateAdd(day,1,@StartDate),'yyyy-MM-dd', 'en-US')
--Print @StartDate
END --FIRSTWHILE