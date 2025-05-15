Create Database DB1
Create Database DB2

USE [master]
GO
CREATE LOGIN [Orange] WITH PASSWORD=N'orange', 
DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
GO
USE [DB1]
GO
CREATE USER [Orange] FOR LOGIN [Orange]
GO
USE [DB1]
GO
ALTER ROLE [db_owner] ADD MEMBER [Orange]
GO

USE [master]
GO
CREATE LOGIN [Green] WITH PASSWORD=N'green', 
DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
GO
USE [DB2]
GO
CREATE USER [Green] FOR LOGIN [Green]
GO
USE [DB2]
GO
ALTER ROLE [db_datareader] ADD MEMBER [Green]
GO


USE DB2
Create table GreenData
(
Column1 varchar(100)
)
GO

Insert Into GreenData VALUES ('This is Green''s Data')
Go 10

Select *
from GreenData

ALTER AUTHORIZATION ON OBJECT::dbo.GreenData to Green

---Turn On Cross Database Ownership chaining on the instance level
EXECUTE sp_configure 'Show Advanced Options',1
RECONFIGURE
EXECUTE sp_Configure 'CROSS DB OWNERSHIP CHAINING',1
RECONFIGURE

ALTER DATABASE DB1 SET DB_CHAINING ON
ALTER DATABASE DB2 SET DB_CHAINING ON

---If this is not executed, the server will block the query
ALTER Database DB1 set TRUSTWORTHY ON

---Take to another window
USE DB1
--Access Denied
EXECUTE AS USER = 'Orange'
SELECT *
FROM DB2.dbo.GreenData
REVERT;

Create view v_GreenData
as
SELECT *
FROM DB2.dbo.GreenData

EXECUTE AS USER = 'Orange'
Select *
from dbo.v_GreenData
Revert;

USE [DB1]
GO
CREATE USER [Green] FOR LOGIN [Green]
GO
ALTER ROLE [db_datareader] ADD MEMBER [Green]
GO


ALTER AUTHORIZATION ON OBJECT::dbo.v_GreenData to Green

EXECUTE AS USER = 'Orange'
Select *
from dbo.v_GreenData
Revert;

---Clean Up
USE Master

Drop Database DB1
Drop Database DB2

DROP LOGIN [Orange]
DROp LOGIN [Green]

EXECUTE sp_Configure 'CROSS DB OWNERSHIP CHAINING',0
RECONFIGURE

EXECUTE sp_configure 'Show Advanced Options',0
RECONFIGURE
