# Security Architecture 

## Agenda 

- SQL Server Security Top-Down Overview. 
- Ports (SQL Server, Browser, DAC, SSAS).
- Server Logins 
- Server Roles (Custom Roles New for 2012)
- Logon Triggers 
- Database Schemas 
- Database Users 
- Database Roles 
- DCL.
- Database Cross Ownership Chaining
- Contained Databases (SQL 2012+)


## 1. SQL Server Security Overview 

SQL Server Instance running over the Windows Server see below diagram to understand the idea.

![](attachments/Pasted%20image%2020220807125717.png)

Based on Diagram Numbering:

1. The Operating System area is in Blue.
2. The SQL Instance area is in gray.
3. The OS contains number 4 and 5.
4. Once you connect to Server remotely you will pass the Firewall. 
5. After that you have Active Directory User and Group assigned to your user.
6. Then You can access the Instance using **Server login** and this is like the key of the door to SQL Server Using this login you will access the Instance not the DATABASE.
7. Server Roles is a group of permissions, so by assigning any role to **Login User** it will have those permission.
8. Logon Triggers 
9. Database User, is the User have access to access to one or more database.
10. Database Role, is A group of permission can be granted to the DB user to manage that Database.
11. Schemas 



To understand the workflow in deep below diagram shows that. 

![](attachments/Pasted%20image%2020220807131152.png)

1. Server Login (Windows or SQL) may have **permission** or group of permission called **Server Roles** granted to it, those permissions allow it to control Jobs, DB mail and other controls (Restart,start, Stop Server .. etc) .
2. if this **Server Login** mapped to **Database User** Means that it can control Database.
3. This Database User Should have permission or Mapped to A Database Roles granted to it, so it can Control Schemas, Tables, Views, Stored Proc, Functions ... etc.


The Principals - Object that is authenticated and given access, for example:

* **OS** - Windows Logins - we can call it Principal
* **Instance** - Server Logins, Server Roles - we can call it Principal
* **Database** - DB Users, DB Roles - we can call it Principal


The Securables Concept is - Object that are given access to, In other words something that you can grant access to for example:

- **OS** - None.
- **Instance** - DBs.
- **Database** - Tables, views, schemas, procedures , etc.

> Principals are given access to securables for example The Principal Test_User  grant access to Securable TESTDB.

Below Diagram shows clear Idea about the Principals and Securables 

![](attachments/Pasted%20image%2020220807140951.png)


## 2. Ports 

- Managed with Configuration Manager.
- SQL DB Engine - 1433 TCP.
- Dedicated ADMIN (DAC): 1434 TCP.
- SQL Server Browser: 1434 UDP.
- SQL Server Analysis Services (SSAS): 2383 TCP.
- MSDTC & SSIS Via SSMS: 135 TCP.
- Mirroring/ Availability Groups: 5022 TCP
- Fail-over Clustering Needs: 135 TCP
- SQL Server Named Instances By Default uses Dynamic Ports and it can be changed.

## 3. Server Logins

* Security At the DB Engine or Instance Level.
* Can be of two kinds:
	* SQL Server Login ( Only works within SQL Server)
	* Windows Login (Works on SQL Server and Windows OS) for example the Active Directory Domain account (Domain\\Username).

## 4. Server Roles 

- Custom Server Roles: SQL 2012+
- Server Logins are mapped to Server Roles for permissions,  i.e sysadmin role which  
 

## 5. Login Trigger 

- Server Trigger that fires during logon.
- Use for Auditing the Logged In users 
- Use also for Logon Time Restrictions, we can allow group of users to login to the SQL server on time and disallow other group ant specific time as well.

## 6. Schemas 

## 7. Database Users 


## . Practice 

### .1 Create Logins & Roles



```sql

----CREATE LOGINS
---FIRST LOGIN FOR SYSADMIN called securitysuper

USE [master]
GO
CREATE LOGIN [securitysuper] WITH PASSWORD=N'securepassword', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
GO

-- Grant 
EXEC master..sp_addsrvrolemember @loginame = N'securitysuper', @rolename = N'sysadmin'
GO

--Revoke 
exec master..sp_dropsrvrolemember @loginame = N'securitysuper', @rolename =N'sysadmin'
Go 


---SECOND LOGIN for securityuser, has ability to shutdown server and change permissions.
USE [master]
GO
CREATE DATABASE SecurityTest
GO
CREATE LOGIN [securityuser] WITH PASSWORD=N'password', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
GO
USE [SecurityTest]
GO
CREATE USER [securityuser] FOR LOGIN [securityuser]
GO

---THIRD USER is a weaker account will be used for testing.
USE [master]
GO
CREATE LOGIN [weaksecurityuser] WITH PASSWORD=N'password', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
GO

USE [SecurityTest]
GO
CREATE USER [weaksecurityuser] FOR LOGIN [weaksecurityuser]
GO

-----CREATE SERVER ROLE FOR SHUTING DOWN
USE [master]

GO

CREATE SERVER ROLE [shutdownadmin]

GO

use [master]

GO

GRANT SHUTDOWN TO [shutdownadmin]

GO

----ADD securityuser to the new role

ALTER SERVER ROLE [shutdownadmin] ADD MEMBER [securityuser]

GO

---ADD security user to the securityadmin role
ALTER SERVER ROLE [securityadmin] ADD MEMBER [securityuser]

GO
```

### .2 DB Level Security

In this level we are dealing with the database objects such as tables, views, stored procedures, etc.

```sql
---CREATE DB LEVEL Security
USE [SecurityTest]
GO

--- Create dummy procedures 
-- should be run in separet query sheet
 
create procedure pr_001_procedure as
select 1 
go 

create procedure pr_002_procedure as
select 1 
go 

create procedure pr_003_procedure as
select 1 
go 

create procedure pr_004_procedure as
select 1 
go 

create procedure pr_005_procedure as
select 1 
go 

create procedure pr_006_procedure as
select 1 
go 



---CREATE ROLE FOR EXECUTING STORED PROCEDURES
CREATE ROLE db_SPExecute

---ASSIGN MEMBERS TO ROLE
USE [SecurityTest]
GO
EXEC sp_addrolemember N'db_SPExecute', N'securityuser'
GO

USE [SecurityTest]
GO
EXEC sp_addrolemember N'db_SPExecute', N'weaksecurityuser'
GO

--Data Control Language

----GRANT EXECUTE PERMISSIONS TO ROLE

SELECT 'GRANT EXECUTE ON ' +SPECIFIC_NAME+' to db_SPExecute',*
FROM INFORMATION_SCHEMA.ROUTINES
where ROUTINE_NAME like 'pr_00%'

---CREATE ROLE FOR VIEWING DEFINITIONS OF STORED PROCEDURES

CREATE ROLE db_SPReadDef

---ASSIGN securityuser to ROLE

USE [SecurityTest]
GO
EXEC sp_addrolemember N'db_SPReadDef', N'securityuser'
GO

---GRANT VIEW DEFINITION TO STORED PROCEDURES

SELECT 'GRANT VIEW DEFINITION ON ' +SPECIFIC_NAME+' to db_SPReadDef',*
FROM INFORMATION_SCHEMA.ROUTINES
where ROUTINE_NAME like 'pr_00%'

---TEST EXECUTING AS weaksecurityuser

EXECUTE AS USER ='weaksecurityuser'
EXEC PR_0010_PROCEDURE
REVERT

---REMOVE USER FROM SP EXECUTE ROLE

USE [SecurityTest]
GO
EXEC sp_droprolemember N'db_SPExecute', N'weaksecurityuser'
GO

---TEST EXECUTING AS weaksecurityuser

EXECUTE AS USER ='weaksecurityuser'
EXEC PR_0010_PROCEDURE
REVERT
 ---Should fail
```

### .3 Logon Trigger


```sql
USE Master
go
CREATE TRIGGER trg_track_logons
ON ALL SERVER --Database, table, etc
WITH EXECUTE AS 'securitysuper' ---IMPORTANT or it won't write to the audit table
FOR LOGON
AS
BEGIN

	IF ORIGINAL_LOGIN() = 'weaksecurityuser' 
	and
	DATEPART (hh,GETDATE()) between 1 and 23
	BEGIN
		ROLLBACK
		INSERT SecurityTest.dbo.RestrictedLogons
		(Login, TimeStamp)
		VALUES (ORIGINAL_LOGIN(),GETDATE())
	END
END

DROP TRIGGER trg_track_logons ON ALL SERVER

SELECT *
FROM SecurityTest.dbo.RestrictedLogons

TRUNCATE TABLE SecurityTest.dbo.RestrictedLogons
```



### . Schemas  

```sql
 ----CREATE SCHEMA
USE [SecurityTest]
GO
CREATE SCHEMA [security] AUTHORIZATION [securityuser]
GO
use [SecurityTest]
GO
GRANT SELECT ON SCHEMA::[security] TO [weaksecurityuser]
GO

---CREATE TABLE ON SCHEMA
CREATE TABLE security.testtable
(name varchar(100))
GO
---INSERT RECORDS
INSERT INTO SECURITY.TESTTABLE VALUES ('123')
INSERT INTO SECURITY.TESTTABLE VALUES ('456')
INSERT INTO SECURITY.TESTTABLE VALUES ('789')

---EXECUTE SELECT AS weaksecurityuser
EXECUTE AS USER ='weaksecurityuser'
SELECT * FROM SECURITY.TESTTABLE
REVERT

---EXECUTE INSERT AS weaksecurityuser ***WILL FAIL
EXECUTE AS USER ='weaksecurityuser'
INSERT INTO SECURITY.TESTTABLE VALUES ('10')
REVERT

---GRANT INSERT PERMISSIONS ON SCHEMA TO weaksecurityuse
GRANT INSERT ON SCHEMA::[security] TO [weaksecurityuser]
GO

---EXECUTE INSERT AS weaksecurityuser ***Should pass
EXECUTE AS USER ='weaksecurityuser'
INSERT INTO SECURITY.TESTTABLE VALUES ('10')
REVERT

SELECT * FROM SECURITY.TESTTABLE

--Add weaksecurity to a new database role, give access to database role and deny to weaksecurityuser

CREATE ROLE db_ReadData

---ASSIGN securityuser to ROLE

USE [SecurityTest]
GO
EXEC sp_addrolemember N'db_ReadData', N'weaksecurityuser'
GO

GRANT SELECT ON SCHEMA::Security to db_ReadData

EXECUTE AS USER ='weaksecurityuser'
Select * From SECURITY.TESTTABLE
REVERT;

DENY SELECT ON Security.TestTable to WeakSecurityUser

--Cannot select
EXECUTE AS USER ='weaksecurityuser'
Select * From SECURITY.TESTTABLE
REVERT;

--Still has insert permissions on Scehma level
EXECUTE AS USER ='weaksecurityuser'
INSERT INTO SECURITY.TESTTABLE VALUES ('10')
REVERT

--This revoke will remove the DENY and also will REVOKE Select Permissions on Table
--However, user still has select Permissions on Schema
REVOKE SELECT On Security.TestTable to WeakSecurityUser

-----FIXED Orphaned User problem
USE master
DROP LOGIN securityuser

USE SecurityTest
exec sp_change_users_login 'Report'

--Recreate Login
USE [master]
GO
CREATE LOGIN [securityuser] WITH PASSWORD=N'password'
GO

USE SecurityTest
exec sp_change_users_login 'Auto_fix','securityuser'

USE SecurityTest
exec sp_change_users_login 'Update_One','securityuser'


---Clean up
USE Master
DROP Database SecurityTest
```



```sql

----Prep for presentation

CREATE DATABASE SecurityTest

USE SecurityTest

CREATE TABLE RestrictedLogons
(login sysname not null,
timestamp datetime not null)


DECLARE @counter INT = 1
declare @sql varchar(max) = ''

WHILE @counter <> 100
BEGIN 

set @sql=''
set @sql= 'CREATE PROCEDURE PR_00'+CAST(@counter AS VARCHAR(10))+'_PROCEDURE as select 1 go'
exec (@sql)

SET @counter = @counter + 1

END


--clean up

USE SecurityTest

DECLARE @counter INT = 1
declare @sql varchar(max) = ''

WHILE @counter <> 100
BEGIN 

set @sql=''
set @sql= 'drop PROCEDURE PR_00'+CAST(@counter AS VARCHAR(10))+'_PROCEDURE'
exec (@sql)

SET @counter = @counter + 1

END

```



```sql
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
```


## End 