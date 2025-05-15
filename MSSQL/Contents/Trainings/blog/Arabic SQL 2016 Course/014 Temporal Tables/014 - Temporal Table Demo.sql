USE AdventureWorksDW2014
GO


SELECT * INTO DimCustomer_Temporal
FROM DimCustomer

--Temporal tables require that source table has a primary key
ALTER TABLE dbo.DimCustomer_Temporal ADD CONSTRAINT
	PK_DimCustomer_Temporal PRIMARY KEY CLUSTERED 
	(
	CustomerKey
	)

--Create History Table
--DROP Table [DimCustomer_TemporalHistory]

CREATE TABLE [dbo].[DimCustomer_TemporalHistory](
	[CustomerKey] [int] NOT NULL,
	[GeographyKey] [int] NULL,
	[CustomerAlternateKey] [nvarchar](15) NOT NULL,
	[Title] [nvarchar](8) NULL,
	[FirstName] [nvarchar](50) NULL,
	[MiddleName] [nvarchar](50) NULL,
	[LastName] [nvarchar](50) NULL,
	[NameStyle] [bit] NULL,
	[BirthDate] [date] NULL,
	[MaritalStatus] [nchar](1) NULL,
	[Suffix] [nvarchar](10) NULL,
	[Gender] [nvarchar](1) NULL,
	[EmailAddress] [nvarchar](50) NULL,
	[YearlyIncome] [money] NULL,
	[TotalChildren] [tinyint] NULL,
	[NumberChildrenAtHome] [tinyint] NULL,
	[EnglishEducation] [nvarchar](40) NULL,
	[SpanishEducation] [nvarchar](40) NULL,
	[FrenchEducation] [nvarchar](40) NULL,
	[EnglishOccupation] [nvarchar](100) NULL,
	[SpanishOccupation] [nvarchar](100) NULL,
	[FrenchOccupation] [nvarchar](100) NULL,
	[HouseOwnerFlag] [nchar](1) NULL,
	[NumberCarsOwned] [tinyint] NULL,
	[AddressLine1] [nvarchar](120) NULL,
	[AddressLine2] [nvarchar](120) NULL,
	[Phone] [nvarchar](20) NULL,
	[DateFirstPurchase] [date] NULL,
	[CommuteDistance] [nvarchar](15) NULL,
	ValidFrom datetime2 NOT NULL,
	ValidTo datetime2 NOT NULL
)

--Add History Columns

ALTER TABLE dbo.DimCustomer_Temporal
ADD PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo), 
ValidFrom datetime2 GENERATED ALWAYS AS ROW START DEFAULT GETDATE(),
ValidTo datetime2 GENERATED ALWAYS AS ROW END DEFAULT CONVERT(DATETIME2, '9999-12-31 23:59:59.99999999')

--Enable system versioning
ALTER TABLE dbo.DimCustomer_Temporal
SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.DimCustomer_TemporalHistory));


SELECT *
FROM DimCustomer_Temporal

SELECT *
FROM DimCustomer_TemporalHistory

--Customer Bought a Car
Update DimCustomer_Temporal
SET NumberCarsOwned = 1
where CustomerKey = 11000

--Customer's child moved out of the house
Update DimCustomer_Temporal
SET NumberChildrenAtHome = 2
where CustomerKey = 11001

SELECT *
FROM DimCustomer_Temporal
where CustomerKey in (11000,11001)

SELECT *
FROM DimCustomer_TemporalHistory

SELECT * FROM DimCustomer_Temporal 
    FOR SYSTEM_TIME  
        BETWEEN '2016-01-01 00:00:00.0000000' AND '2017-01-01 00:00:00.0000000' 
            WHERE CustomerKey = 11000 ORDER BY ValidFrom;

--Child returns from college
Update DimCustomer_Temporal
SET NumberChildrenAtHome = 1
where CustomerKey = 11000

--Customer buys another car
Update DimCustomer_Temporal
SET NumberCarsOwned = 2
where CustomerKey = 11000

Alter Table DimCustomer_Temporal
ADD AGE int

Update DimCustomer_Temporal
SET Age = Datediff(year,BirthDate,getdate())

SELECT * FROM DimCustomer_Temporal 
    FOR SYSTEM_TIME  
        BETWEEN '2016-01-01 00:00:00.0000000' AND '2017-01-01 00:00:00.0000000' 
            WHERE CustomerKey = 11000 ORDER BY ValidFrom;


ALTER TABLE DimCustomer_Temporal
DROP COLUMN AGE

--Column and it's history is gone, but rows still exist in the history table

--Cannot Truncate Table
Truncate Table DimCustomer_TemporalHistory

---
ALTER TABLE dbo.DimCustomer_Temporal
SET (SYSTEM_VERSIONING = OFF)

--Now I can truncate
Truncate Table DimCustomer_TemporalHistory

---Add back Age Column and update all rows
---this will prevent over logging.

Alter Table DimCustomer_Temporal
ADD AGE int

Update DimCustomer_Temporal
SET Age = Datediff(year,BirthDate,getdate())


--Setup versioning again
ALTER TABLE dbo.DimCustomer_Temporal
SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.DimCustomer_TemporalHistory));

---Fails because column is not part of the history table
--when versioning was turned on, the column was automatically added to history table
Alter Table DimCustomer_TemporalHistory
ADD AGE int
--Try again after adding the column


SELECT * FROM DimCustomer_Temporal 
    FOR SYSTEM_TIME  
        BETWEEN '2016-01-01 00:00:00.0000000' AND '2017-01-01 00:00:00.0000000' 
           ORDER BY ValidFrom;

--Empty
SELECT * FROM DimCustomer_TemporalHistory

---Lets see if history is tracked when versioning is set to off
ALTER TABLE dbo.DimCustomer_TemporalSET (SYSTEM_VERSIONING = OFF)

Update DimCustomer_Temporal
SET NumberChildrenAtHome = 20
where CustomerKey = 11000

ALTER TABLE dbo.DimCustomer_Temporal
SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.DimCustomer_TemporalHistory));


SELECT * FROM DimCustomer_Temporal 
    FOR SYSTEM_TIME  
        BETWEEN '2016-01-01 00:00:00.0000000' AND '2017-01-01 00:00:00.0000000' 
          WHERE CustomerKey = 11000 ORDER BY ValidFrom;

---Customerkey 11000 only has ONE record in the table where did the other updates go?


---Clean Up
ALTER TABLE dbo.DimCustomer_TemporalSET (SYSTEM_VERSIONING = OFF)
GO
DROP Table DimCustomer_Temporal
GO
DROP Table DimCustomer_TemporalHistory
GO