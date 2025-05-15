# DP- 300 Exam Preparation Notes

## Execution Plans 

- Estimated Execution Plan 
- Actual Execution Plan 
- Live Query Statistics 

```sql
SET SHOWPLAN_ALL on/off
Go

-- or 

SET SHOWPLAN_TEXT ON/OFF
GO
```

- Nested loop join - are sufficient for a cross join as well. and the advantage of nested loops is uses the least I/O, that's Input/Output, and fewest comparisons.
- Merge Join - this type used when input 1 and input 2 are not small, but also input one and input two are sorted on their joins.
- Hash Match - this is the least favorite Join, it's used for large unsorted, non indexed inputs. it can also be used in the middle of complex queries.



Seek - use index to go direct to the address of that row.
Scan - scan table for that particular row or rows.

SARGable Query - Query that use index and utilized it
Non-SARGable Query - Query that is not utilize the Index in execution, so we need to fix it, and make it SARGable.

## Indexes 

Requirements for Indexes:
- A big tables no need for index for small tables.
- Small columns size. 
- Index columns that freq used in **WHERE** clauses and they need to be sargable for example (Like, <>!=) avoid non-sargable like those functions ( isnull(), year(), etc)


Create an Index:
> we can have many non-clustered indexes, but only one clustered index.

- Non-clustered index: you can have many non-clustered index as much you want. 
- Clustered index - sorted index that can used for frequently used queries and range queries between x and y.
- Unique clustered index: used when we create a primary key, that means we have one particular row with each value, and if we are using this index with multiple value or columns means have unique combination. 
- Non-unique Clustered index: we can create such index but most of the time we create a unique clustered index.
- Filtered Index: index that target only value using **WHERE** clause in index creation.


> If you insert update delete rows from table all the indexes need to be adjusted, which may slow down you server and cause bad performance if you have many indexes that need to do operation on them.  

```sql
CREATE CLUSTERED INDEX ix_address_address1_address2
ON [SCHEMA].[TABLENAME](address1,address2)

CREATE UNIQUE CLUSTERED INDEX ix_address_address1_address2
ON [SCHEMA].[TABLENAME](address1,address2)

CREATE NONUNIQUE CLUSTERED INDEX ix_address_address1_address2
ON [SCHEMA].[TABLENAME](address1,address2)


CREATE NONCLUSTERED INDEX ix_address_address1_address2
ON [SCHEMA].[TABLENAME](address1,address2)

-- index looks for particular where clause
-- filtered index 
CREATE NONCLUSTERED INDEX ix_address_address1_address2
ON [SCHEMA].[TABLENAME](address1 desc,address2 asc)
WHERE [CITY] = 'Jinin'
WITH (FILLFACTURE=62)

```


## Dynamic Management Views (DMV)

DMV's, they  are system views they start off with `sys.dm_` then the function area `exec, tran, db` and the last will be what is the actual view is.

for exam dp-300 we need to know roughly about these views and what they actually do, 

```sql 
-- retrieve the last execution plan 

select * from sys.dm_exec_cached_plans as cp 
cross apply sys.dm_exec_sql_text(plan_handle) as st
cross apply sys.dm_exec_query_plan_stats(plan_handle) as qps

-- Top N queries ranked by average cpu time 

SELECT TOP 5 query_stats.query_hash AS "Query Hash", 
    SUM(query_stats.total_worker_time) / SUM(query_stats.execution_count) AS "Avg CPU Time",
    MIN(query_stats.statement_text) AS "Statement Text"
FROM 
    (SELECT QS.*, 
    SUBSTRING(ST.text, (QS.statement_start_offset/2) + 1,
    ((CASE statement_end_offset 
        WHEN -1 THEN DATALENGTH(st.text)
        ELSE QS.statement_end_offset END 
            - QS.statement_start_offset)/2) + 1) AS statement_text
     FROM sys.dm_exec_query_stats AS QS
     CROSS APPLY sys.dm_exec_sql_text(QS.sql_handle) as ST) as query_stats
GROUP BY query_stats.query_hash
ORDER BY 2 DESC;
GO





-- Which queries use the most cumulatvice CPU?

SELECT
    highest_cpu_queries.plan_handle,
    highest_cpu_queries.total_worker_time,
    q.dbid,
    q.objectid,
    q.number,
    q.encrypted,
    q.[text]
FROM
    (SELECT TOP 50
        qs.plan_handle,
        qs.total_worker_time
    FROM
        sys.dm_exec_query_stats qs
ORDER BY qs.total_worker_time desc) AS highest_cpu_queries
CROSS APPLY sys.dm_exec_sql_text(plan_handle) AS q
ORDER BY highest_cpu_queries.total_worker_time DESC;


-- Long running queries that consume CPU are still running

PRINT '--top 10 Active CPU Consuming Queries by sessions--';
SELECT TOP 10 req.session_id, req.start_time, cpu_time 'cpu_time_ms', OBJECT_NAME(ST.objectid, ST.dbid) 'ObjectName', SUBSTRING(REPLACE(REPLACE(SUBSTRING(ST.text, (req.statement_start_offset / 2)+1, ((CASE statement_end_offset WHEN -1 THEN DATALENGTH(ST.text)ELSE req.statement_end_offset END-req.statement_start_offset)/ 2)+1), CHAR(10), ' '), CHAR(13), ' '), 1, 512) AS statement_text
FROM sys.dm_exec_requests AS req
    CROSS APPLY sys.dm_exec_sql_text(req.sql_handle) AS ST
ORDER BY cpu_time DESC;
GO


```



## Automate Deployment on Azure

- Using Deployment template 
- Using Azure Resource Manager (ARM) Template 
- Using Bicep 
- Using PowerShell 
	- create a resource group `New-AzResourceGroup`
	- create a SQL Server `New-AzSqlServer` or `New-AzSqlInstance` or `New-AzSqlVM` 
	- create a SQL Database `New-AzSqlDatabase`
- Using Azure CLI 
	- Create Resource Group. `az group create`
	- Create Sql Server. `az sql server create` or `az sql mi create` or `az vm create`
	- Create Sql Database. `az sql db create `

## Partitioning Strategy 

Data and Table database partitioning strategies 
- Horizontal partitioning known as database sharding 
- Vertical Partitioning Known as Functional Partitioning 
- Add more resource to existing DB called Vertical scaling

## Compression 

Compression reduce data size to save more space, but the downside is that we need extra time and compute power, both to compress and retrieve the data.

we have 3 main type of compression: 
- None.
- Row Compression - individual row compression or items  
	- Prefix Compression - it will save the prefix of each item in compression information structure area in the page header  each prefix will be replaced with any match in the page to save more space . see below figure

![](attachments/Pasted%20image%2020220811153450.png)

prefix compression done by looking at one particular column.
	- Dictionary Compression - it will come after the prefix compression and it look after all the columns 
- Page Compression

> - We can compress a tables either stored with a clustered index or without, so table without clustered index called a heap
> - We can compress indexes, we can compress non-clustered index, and a complete indexed view
> - Different table partitions can be compressed, using different settings 
> 
> - We Can't use a data Compress  with a tables which have sparse  columns
> - We can't compress system tables 
> - 


if we need to change the compression from row to page or from row to off in a clustered index we need to drop the index and rebuild the table. 

Column-store 


## Migration 

Type of Migration 

- Azure Migration - Lift and Shift SQL server to a virtual machine, discover and assess sql data estate at scale.
- SQL Server Migration Assistant (SSMA) - Migrate (Access,DB2,MySQL,Oracle and SAP ASE) to Azure SQL Server database or on premises .
- Data Migration Assistant (DMA) - Migrate SQL server to Azure SQL server, Managed Instance, Azure VM or On-Premises database.
- Azure Database Migration Services (DMS) - you need to create an Azure service you have two options **standard** supports offline only up to 4 vcores  or **premium** supports offline and online migration free for 6 months, it will migrate sql server to azure SQL Database, Postgres to Azure Postgres and MongoDB to Azure Cosmos (MongoDB) - Note that Only Azure SQL Managed Instance, MongoDB and PostgreSQL can be Migrated online.
- Database Experimentation Assistant (DEA) - help to compare workload between the source and target SQL server. 
- Migrate Between Azure SQL services.
	- Using Export/Import Data from Task menu - good for copying tables but weak one comes to copy views and procedures
	- Using Data Tier Applications (DAC) - you can migrate direct to Azure or save if to a disk with **.bacpac** which stands for backup package 
	- Using Azure SQL Database Export/Import Database - to use those web tools you need to have a storage account (Storage Container)
	- Using **sqlpackage.exe** - this is a .NET CLI tool or program that allow us to export and import Azure SQL Databases as a **.bacpac** extension 
	- Using Powershell - `az db export az db import` 


## Security 

AuthN vs AuthZ : authentication how is access, authorization what can access.

AAD (Azure Active Directory): 

3 Ways for Azure Authentication:
- Federation Authentication - 
- Cloud-Only Identity - Using Azure Cloud active Directory 
- Hybrid Authentication - Using Cloud or maybe using password hash 
- Pass-through 

```sql

-- Deny is higher than grant
Revoke --> Remove YES and NO
Grant  --> YES
Deny   --> NO

-- General Syntax 

AUTHORIZATION PERMISSION ON SECUREABLE::NAME TO PRINCIPAL WITH GRANT OPTION;

-- Authorization - grant revoke deny
-- PERMISSION - SELECT Update delete .. etc
-- Secureable - Object Name - Table, View, Schema, db, server and role .. etc
-- Principal - Windows user, SQL login, Role .. etc 

```

- Table - Select, Update, Insert, Delete, Control, References, Take Ownership, View Change Tracking, View Definitions
	- Control - means grant select update insert delete 
	- References - means grant view foreign Keys 
	- Take Ownership - change who has ownership of that table .
	- View definition - means grant the principal the ability to view the script of that object or table.
- Schema - ALTER (CREATE, ALTER, DROP Table ..)
- Functions/Stored Procedures - Alter, Execute, View Change Tracking, View Definition.

Ownership Chaining 

```sql
 Create Procedure SalesLT.StoredProcedure AS 
 SELECT * FROM SalesLT.MyTable

-- then EXECUTE Stored Porcedure , No Select Table premission 

-- yes this execute will bring data, even you don't have permission on that table, and you have only permission on that stored procedure, but they should have same schema. that called Ownership Chaining 

```

Run Procedure as someone else

```sql 
create proc saleslt.storedprocedure with execute as [susan@microsoft.com] as 
....
...
..

```

List all the permission that I have 

```sql
select * from sys.fn_my_permissions(NULL,'DATABASE')
-- permissions for particular user
select * from sys.fn_my_permissions('Susan','DATABASE')
-- Permissions for Particular object - table
select * from sys.fn_my_permissions('SalesLT.Customer','DATABASE')

```

Create a custom Role:

```sql 

create role mycustomRole1

Grant select on object::[SalesLT].[Address] To MycustomeRole1

Alter Role MyCustomRole1 ADD MEMBER [Susan@microsoft.com]

```

**Implement the Least Privileged User Account (LUA)**

Database users and systems can be grouped based on their roles. Consider different groups of users as follows:

-    Users who require access just to read and export data from the database
-   Users who can read and write to specific schema (edit access)
-   Privileged users who can add and delete the schema (data definition language)
 -   Privileged and administrative users who can add and grant access rights to various users


## Transparent Data Encryption (TDE)

TDE encrypt and D-encrypt data at the page level at rest. in short words when write data its encrypt when read data is d-encrypt. 
Don't get confused by TLS, Transport Layer Security which encrypts data when it's in transit.

Azure SQL Server have two options to transparent data encryption **Service-Managed Key** and the second one is **Customer-managed Key**

Database Encryption Key (DEK) - symmetric key means that one key needed to encrypt and d-encrypt data. 

The Key will be protected by TDE protector, Using Service-managed Certificate or its protected by asymmetric key, which could be stored in Azure Key Vault. 

Enable TDE:

- Using Azure web interface - only for Azure Database.
- Using T-SQL - Both Azure SQL database and Managed Instance database.

```SQL
ALTER DATABASE TESTDB SET ENCRYPTION ON
```

However, we can't switch the TDE Protector to a key in the key vault in T-SQL. to achieve this we using powershell check below.

- Using Powershell - `Set-AzSqlServerTransparentDataEncryptionProtector` `Add-Az-SqlServerKeyVaultKey` `Set-AzSqlDatabaseTransparentDataEncryption` 

Object level Encryption 

Always Encrypted

To encrypt Column:
- Randomized  - can't be used in equality joins, group by, indexes and distinct
- Deterministic - you can use it 


To See the Encrypted Columns, using SSMS you need to restart the SSMS and 

![](attachments/Pasted%20image%2020220813163417.png)

Then you need to make sure that your user is added to Access Policy List and have keys permission.

Then you need to check below option in SSMS

![](attachments/Pasted%20image%2020220813163838.png)

Role Separation

-- Security Administrator - keys/key store 
-- Database Administrator - Metadata about key 

If you want to implement the Role Separation, So you need to do it using Powershell not using SSMS, below the steps:

- Security Administrator
	- Create Column Master Key in Windows Certificate Store.
	- Import The SqlServer Module 
	- Create a SqlServerMasterKeySettings Object for your column master key 
	- Generate a column encryption key encrypt i with the column Master key 
	- Share the Location of the column master key and an encrypted value of the column encryption key with the DBA.
	- Read the Key data back to verify.
	- Read the key data back to verify
- Database Administrator 
	- Obtain the location of the column master key 
	- Import the SqlServer Module 
	- Connect to your database.
	- Create a SqlColumnMasterKeySetting object for your column 
	- Create column master key metadata in the database 
	- Generate a column encryption key, encrypt it with the column master key

## Column-Level Security 

Check [here](https://www.snp.com/blog/bring-your-data-securely-to-the-cloud-with-azure-synapse-analytics) for more details 

![](attachments/Pasted%20image%2020220822221849.png)



## Row-level Security 

![](attachments/Pasted%20image%2020220822221852.png)

## Dynamic Data Masking

![](attachments/Pasted%20image%2020220822221858.png)


- CLE Column Level Encryption 

```sql 
alter table [SalesLT].[Address]
Alter Column [StateProvince]
Add Mask With (FUNCTION = 'default')
-- partial(1,"xxxxxxxx",1)
-- email()
-- random(1,1000)


-- Execlude user from masking 

GRANT UNMASK TO [Susan@microsoft.com]

-- remove execluding
REVOKE UNMASK TO [Susan@microsoft.com]

```

## Database-Level Firewall Rules

we have to levels firewall:

- Server-Level Firewall 
- Database-Level Firewall 

Server-Level Firewall

```sql 
use master

Select * from sys.firewall_rules

exec sp_set_firewall_rule @name = N'MyFirewallRule', @start_ip_address = '86.134.144.145', @end_ip_address = '86.134.144.146'

exec sp_delete_firewall_rule @name = N'MyFirewallRule'

```

Database-Level Firewall 

To set Database Firewall, you can't do it using Azure portal, and can only be done by T-SQL, Powershell CLI and  REST API.

```sql

select * from sys.database_firewall_rules

execute sp_set_database_firewall_rule @name = N'MyDatabaseFirewallRule', @start_ip_address = '192.168.1.1', @end_ip_address = '192.168.1.200'

exec sp_delete_database_firewall_rule @name = N'MyFirewallRule'
```

## Data Classification Strategy 

you can add classification on a table columns using both T-SQL and Azure Portal 

```sql

select * from sys.sensitivity_classifications

select * from sys.columns where object_id = 1506104406


add sensitivity classification to 
[saleslt].[address].PostalCode
with(
LABEL='Highly Configential',
INFORMATION_TYPE='Financial',
RANK=LOW
)

DROP SENSITIVITY CLASSIFICATION FROM [saleslt].[address].PostalCode
```


## Database Auditing 

Server Policy Audit, Microsoft recommend to use only server level auditing  


## Ledger Table

- Updateable table ledger - needs a history table. view and storage 
- Append-Only Ledger table - no need for history table, onlu view and storage.

two location to store the ledger 
- Azure Confidential Ledger storage 
- Azure Blob storage 


## Index Maintenance Tasks 

```sql
-- Find Missing Indexes 
Select * from sys.dm_db_missing_index_details

-- Assess fragmentation of database indexes
Select db_name(database_id) as DBName, object_name(object_id) as ObjectName, avg_fragmentation_in_percent, page_count, * from sys.dm_db_index_physical_stats(NULL,NULL,NULL,NULL,NULL)

DBCC SHOWCONFIG -- deprecated 


-- assess columnstore
select deleted_rows,total_rows from sys.dm_db_column_store_row_group_physical_stats
```

Index Maintenance have two options:
- Reorganize - when we have less than 30% fragmentation  - for columnstore index we should organize if we above 20%
- Rebuild - when we have more that 30% fragmentation 


## Auto Tuning 

```sql
-- Which Index are Auto-created?
select * from sys.indexes 
where auto_created = 1


-- change database auto-tune
alter database dbname set automatic_tuning = AUTO --| INHERIT | CUSTOM

-- CREATE_INDEX | DROP_INDEX options cant be used on Azure managed instance 
Alter Database dbname set automatic_tuning (FORCE_LAST_GOOD_PLAN = ON, CREATE_INDEX = ON, DROP_INDEX = OFF)

-- What are the Tuning  Recommendations? 
select * from sys.dm_db_tuning_recommendations

```

## Identify Session Cause blocking 

```sql
-- Blocking - cause by poor Application design or by long running query

-- to view locks 
select * from sys.dm_tran_locks

-- S Select X exclusive IX Intent Exclusive 


-- to view blocking
select session_id,blocking_session_id,start_time,status,command,db_name(database_id) as [database],
wait_type, wait_resource, wait_time, open_transaction_count
From sys.dm_exec_requests
where blocking_session_id > 0;

```

## Isolation Levels 

Isolation level types 
- Read uncommitted - ignore the blocking cause dirty read means read data that not committed yet
```sql
 set transaction isolation level read uncommitted 
```
- Read Committed - No dirty read - it will not block if the read_committed_snapshot off it will block if on by default its off, and the default read_committed_snapshot value for Azure database is ON ,therefor doesn't block. 
- Repeatable Read -  you can read and get the same exact data and for that reason it does block any updates.
- Snapshot - If firstly, the database is not in a recovery state, so therefor you are not restoring it from backup, secondly if you have another alter database set to database which allow snapshot isolation see below second alter statement.
- Serializable - No dirty read  cant read statement that have been modified, but not committed 

```sql 
alter database [dbname] set READ_COMMITTED_SNAPSHOT ON/OFF[Default]


Alter database [dbname] set allow_snapshot_isolation on

-- to check the isolation level 

DBCC USEROPTIONS

```

- **Dirty Reads** A _dirty read_ occurs when a transaction reads data that has not yet been committed. For example, suppose transaction 1 updates a row. Transaction 2 reads the updated row before transaction 1 commits the update. If transaction 1 rolls back the change, transaction 2 will have read data that is considered never to have existed.
    
- **Nonrepeatable Reads** A _nonrepeatable read_ occurs when a transaction reads the same row twice but gets different data each time. For example, suppose transaction 1 reads a row. Transaction 2 updates or deletes that row and commits the update or delete. If transaction 1 rereads the row, it retrieves different row values or discovers that the row has been deleted.
    
- **Phantoms** A _phantom_ is a row that matches the search criteria but is not initially seen. For example, suppose transaction 1 reads a set of rows that satisfy some search criteria. Transaction 2 generates a new row (through either an update or an insert) that matches the search criteria for transaction 1. If transaction 1 reexecutes the statement that reads the rows, it gets a different set of rows.

![](attachments/Pasted%20image%2020220815135036.png)

## Intelligent Query Processing (IQP)

- Server-Wide Configuration Options
```sql
select * from sys.configurations
exec sp_configure '101',0 -- not in azure sql database
```
- Database-Wide Configuration Options
```sql
select * from sys.database_scoped_configurations

alter database scoped configuration set [Batch_mode_on_rowstore] = on

select * from [SalesLT].[Address] OPTIONS (USE Hint ('DISALLOW_BATCH_MODE'))

```

![](attachments/Pasted%20image%2020220815144049.png)


## DB Console Command (DBCC )


```sql

-- check logical and physical integrity of all objects
DBCC CHECKDB
DBCC CHECKDB(DBNAME)

-- Check the consistency of disk space allocation structures 
DBCC CHECKALLOC
DBCC CHECKALLOC(DBNAME)

-- CHECK ALL TABLES AND INDEX VIEWS
DBCC CHECKTABLE -- CANT BE RAN LIKE THIS NEED TABLE NAME
DBCC CHECKTABLE('[SALESLT].[ADDRESS]')

-- CHECKS 
DBCC CHECKCATALOG
DBCC CHECKCATALOG(DBNAME)

-- DBCC CHECKDB, CHECKALLOC AND CHECKCATALOG OPTIONS:
DBCC CHECKDB(0,NOINDEX)

-- BELOW NEED SINGLE_USER MODE
ALTER DATABASE [DBNAME] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
DBCC CHECKDB(0,REPAIR_BUILD)
GO
ALTER DATABASE [DBNAME] SET MULTI_USER WITH ROLLBACK IMMEDIATE
GO

DBCC CHECKDB(0,REPAIR_FAST)

-- BELOW DBCC NEEDS AN EMERGENCY AND SINGLE_USER MODE
ALTER DATABASE [DBNAME] SET EMERGENCY
GO
ALTER DATABASE [DBNAME] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
DBCC CHECKDB(0,REPAIR_ALLOW_DATA_LOSS)
GO
ALTER DATABASE [DBNAME] SET MULTI_USER WITH ROLLBACK IMMEDIATE
GO

```