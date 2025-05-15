----CREATE LOGINS
---FIRST LOGIN FOR SYSADMIN called securitysuper
USE [master]
GO
CREATE LOGIN [securitysuper] WITH PASSWORD=N'securepassword', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
GO

EXEC master..sp_addsrvrolemember @loginame = N'securitysuper', @rolename = N'sysadmin'
GO

---SECOND LOGIN for securityuser, has ability to shutdown server and change permissions.
USE [master]
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

---CREATE DB LEVEL Security

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


-----FIXED Orphaned User problem
USE SecurityTest
exec sp_change_users_login 'Report'

USE SecurityTest
exec sp_change_users_login 'Auto_fix','securityuser'

USE SecurityTest
exec sp_change_users_login 'Update_One','securityuser'

