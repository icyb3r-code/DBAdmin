--Step 1 Create the Server Audit

USE [master]

GO

CREATE SERVER AUDIT [Audit001]
TO FILE 
(	FILEPATH = N'E:\MSSQL\Audit Logs'
	,MAXSIZE = 0 MB
	,MAX_ROLLOVER_FILES = 2147483647
	,RESERVE_DISK_SPACE = OFF
)
WITH
(	QUEUE_DELAY = 1000
	,ON_FAILURE = CONTINUE
)
--Optional Filter
---Field must be from sys.fn_get_audit_file table valued function
WHERE server_principal_name = 'SQL2016CTP3\SQLAdmin'

---Step 2 Create Server Audit Specification to Audit Group changes at the server level
USE [master]

GO

CREATE SERVER AUDIT SPECIFICATION [ServerAuditSpecification001]
FOR SERVER AUDIT [Audit001]
ADD (SERVER_PRINCIPAL_CHANGE_GROUP) --- for when logins are altered (add,drop,etc)


GO

--Turn on Server Audit
ALTER SERVER AUDIT Audit001
WITH (STATE = ON)

--Turn on Server Audit Specification
Alter Server Audit Specification ServerAuditSpecification001
WITH (STATE = ON)


---Add to Server Audit Specification when logins change fixed roles
--Must Disable then alter then Enable
Alter Server Audit Specification ServerAuditSpecification001
WITH (STATE = OFF)
GO

ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification001]
ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP) --- for when logins fix role membership is altered
GO

ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification001]
ADD (AUDIT_CHANGE_GROUP) --- for when the Audit is Altered are altered (add,drop,etc)
GO

Alter Server Audit Specification ServerAuditSpecification001
WITH (STATE = ON)
GO



--Getting Audit information via Code

select *
from sys.server_audits

select *
from sys.dm_server_audit_status


--Reading the current Audit Log Programmatically
declare @auditpath varchar(1000)

select @auditpath=audit_file_path
from sys.dm_server_audit_status

SELECT * FROM sys.fn_get_audit_file (@auditpath,default,default);
GO

--Reading All Audit Logs Programmatically

SELECT * FROM sys.fn_get_audit_file (N'E:\MSSQL\Audit Logs\*',default,default);
GO

---List of actions
Select  action_id,name,class_desc,parent_class_desc from sys.dm_audit_actions
/*

SELECT * FROM sys.fn_get_audit_file ('E:\mssql\TestAudit1_80360140-4DA2-4D08-A957-A7EAE37CB055_0_130970173782650000.sqlaudit',default,default);
GO
*/

---Stop and Start will be Audited

ALTER SERVER AUDIT Audit001
WITH (STATE = OFF)
GO

ALTER SERVER AUDIT Audit001
WITH (STATE = ON)
GO

--Can add a user defined audit row
--Must have USER_DEFINED_AUDIT_GROUP as part of the Server or Database Audit Specification
Alter Server Audit Specification ServerAuditSpecification001
WITH (STATE = OFF)
GO

ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification001]
ADD (USER_DEFINED_AUDIT_GROUP)
GO

Alter Server Audit Specification ServerAuditSpecification001
WITH (STATE = ON)
GO

--
EXEC sp_audit_write @user_defined_event_id =  27 , 
              @succeeded =  1 
            , @user_defined_information = N'Disabled Audit001 to make the following changes: 1. ABC'


---Database Auditing
--Optional, create a new Server Audit
USE MASTER
CREATE SERVER AUDIT [Audit002]
TO FILE 
(	FILEPATH = N'E:\MSSQL\Database Audits'
	,MAXSIZE = 0 MB
	,MAX_ROLLOVER_FILES = 2147483647
	,RESERVE_DISK_SPACE = OFF
)
WITH
(	QUEUE_DELAY = 1000
	,ON_FAILURE = CONTINUE
)

ALTER SERVER AUDIT Audit002
WITH (STATE = ON)
GO

USE [AdventureWorksDW2014]

GO

CREATE DATABASE AUDIT SPECIFICATION [ADWDatabaseAudit]
FOR SERVER AUDIT [Audit002]
ADD (UPDATE ON DATABASE::[AdventureWorksDW2014] BY [public]),  --Audits and UPDATES in the entire DB for PUBLIC
ADD (SELECT ON OBJECT::[dbo].[DimCustomer] BY [public]), --Audits and SELECTS on the Customer Table for PUBLIC
ADD (AUDIT_CHANGE_GROUP)  --Audits Changes to Audit
GO

ALTER DATABASE AUDIT SPECIFICATION [ADWDatabaseAudit]
WITH (STATE = ON)
GO

SELECT * FROM sys.fn_get_audit_file (N'E:\MSSQL\Database Audits\*',default,default);
GO

Select *
from dbo.DimCustomer

Create Table TestUpdate
(column1 int)

Insert into TestUpdate Values (1)

Update TestUpdate
Set column1 = 100

Select *
from TestUpdate

---Simple Audit Reporting Query

WITH CTEAuditActionNames as
(
select distinct action_id,name from sys.dm_audit_actions
)

SELECT AF.server_instance_name,AF.event_time,AA.name,AF.succeeded,
AF.server_principal_name,AF.session_server_principal_name, AF.database_principal_name,
AF.database_name,AF.schema_name,AF.object_name,AF.statement, AF.user_defined_information
FROM sys.fn_get_audit_file (N'E:\MSSQL\Audit Logs\*',default,default) AF
	inner join CTEAuditActionNames AA on AF.action_id=AA.action_id
Order by AF.event_time
GO

---Database Audit Spec
WITH CTEAuditActionNames as
(
select distinct action_id,name from sys.dm_audit_actions
)

SELECT AF.server_instance_name,AF.event_time,AA.name,AF.succeeded,
AF.server_principal_name,AF.session_server_principal_name, AF.database_principal_name,
AF.database_name,AF.schema_name,AF.object_name,AF.statement, AF.user_defined_information
FROM sys.fn_get_audit_file (N'E:\MSSQL\Database Audits\*',default,default) AF
	inner join CTEAuditActionNames AA on AF.action_id=AA.action_id
Order by AF.event_time
GO

--Fancier reporting with parameters
--Setup my parameters
declare @auditpath varchar(1000)
declare @auditname varchar(100) = 'Audit001' --- could potentially pass this from an SSRS Report as a report parameters

select @auditpath=audit_file_path
from sys.dm_server_audit_status
where name = @auditname;


WITH CTEAuditActionNames as
(
select distinct action_id,name from sys.dm_audit_actions
)

SELECT AF.server_instance_name,AF.event_time,AA.name,AF.succeeded,
AF.server_principal_name,AF.session_server_principal_name, AF.database_principal_name,
AF.database_name,AF.schema_name,AF.object_name,AF.statement, AF.user_defined_information
FROM sys.fn_get_audit_file (@auditpath,default,default) AF
	inner join CTEAuditActionNames AA on AF.action_id=AA.action_id
Order by AF.event_time
GO



---Clean Up
Use AdventureWorksDW2014
GO
Drop Table TestUpdate

ALTER DATABASE AUDIT SPECIFICATION [ADWDatabaseAudit]
WITH (STATE = OFF)
GO
DROP DATABASE AUDIT SPECIFICATION [ADWDatabaseAudit]
GO

USE MASTER
ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification001]
WITH (STATE = OFF)
GO
DROP SERVER AUDIT SPECIFICATION [ServerAuditSpecification001]
GO

ALTER SERVER AUDIT Audit001
WITH (STATE = OFF)
GO
ALTER SERVER AUDIT Audit002
WITH (STATE = OFF)
GO


DROP SERVER AUDIT Audit001
GO
DROP SERVER AUDIT Audit002
GO
