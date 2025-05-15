Use Master
GO
create procedure pr_AuditingLogReport
@auditname varchar(100) = 'Audit001'
as
Begin


--Fancier reporting with parameters
--Setup my parameters
declare @auditpath varchar(1000)
---declare @auditname varchar(100) = 'Audit001' --- could potentially pass this from an SSRS Report as a report parameters

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

End