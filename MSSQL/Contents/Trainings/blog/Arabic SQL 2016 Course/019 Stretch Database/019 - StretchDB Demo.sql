--Enabled Stretch database at the Instance level

  EXEC sp_configure 'remote data archive';
  GO
  EXEC sp_configure 'remote data archive' ,  '1';
  GO
  RECONFIGURE;
  GO

---Check and see that Stretch database is enabled

SELECT * FROM sys.configurations where name = 'remote data archive'


CREATE DATABASE StretchDBTest
  GO
  USE StretchDBTest
  GO
  

--Create master key for database
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'P@$$W0rd'

CREATE DATABASE SCOPED CREDENTIAL SQLAzureDBStorageCredential 
WITH IDENTITY = '<username>', 
SECRET = '<password>';


ALTER DATABASE [StretchDBTest] 
SET
  REMOTE_DATA_ARCHIVE = ON 
(
       SERVER = N'aymansqlazdb.database.windows.net', --SQL Azure database connection string
       CREDENTIAL = SQLAzureDBStorageCredential  ---credential used to connect
)
GO


---create test tables
SELECT * INTO dbo.FactInternetSales 
FROM AdventureWorksDW2014.dbo.FactInternetSales
  GO

SELECT * INTO dbo.FactInternetSalesFiltered 
FROM AdventureWorksDW2014.dbo.FactInternetSales
  GO

--Enable remote data archival for a table
ALTER TABLE dbo.FactInternetSales
       SET(REMOTE_DATA_ARCHIVE = ON (MIGRATION_STATE = OUTBOUND))
GO

--Look at Query Plan
SELECT *
FROM dbo.FactInternetSales 


--Pause migration
ALTER TABLE dbo.FactInternetSales
       SET(REMOTE_DATA_ARCHIVE = ON (MIGRATION_STATE = PAUSED))
GO

--Review migration status
SELECT object_name(table_id), * FROM sys.dm_db_rda_migration_status

EXEC sp_spaceused 'FactInternetSales', @mode = 'LOCAL_ONLY'
EXEC sp_spaceused 'FactInternetSales', @mode = 'REMOTE_ONLY'
EXEC sp_spaceused 'FactInternetSales', @mode = 'ALL'

--Filter what data gets stretched
--With Filter Predicate
CREATE FUNCTION dbo.fn_StretchDBFilter (@orderdate datetime)
RETURNS TABLE
WITH SCHEMABINDING 
AS 
RETURN	SELECT 1 AS is_eligible
		WHERE @orderdate < CONVERT(datetime, '1/1/2015', 101)

ALTER TABLE dbo.FactInternetSalesFiltered
       SET
	   (
	   REMOTE_DATA_ARCHIVE = ON 
	   (FILTER_PREDICATE = dbo.fn_StretchDBFilter(OrderDate),
	   MIGRATION_STATE = OUTBOUND)
	   )
GO


EXEC sp_spaceused 'FactInternetSalesFiltered', @mode = 'LOCAL_ONLY'

---
ALTER TABLE dbo.FactInternetSalesFiltered
       SET(REMOTE_DATA_ARCHIVE = ON (MIGRATION_STATE = PAUSED))
GO

---Look at execution plan
SELECT *
FROM dbo.FactInternetSalesFiltered
where orderdate > '1/1/2016 '

SELECT *
FROM dbo.FactInternetSalesFiltered
where orderdate < '1/1/2014 '

SELECT *
FROM dbo.FactInternetSalesFiltered