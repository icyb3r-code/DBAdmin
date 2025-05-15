---Put Traceflags 3004 and 3605 in startup

USE Master
Drop database DBMulti

CREATE DATABASE DBMulti
 ON  PRIMARY 
( NAME = N'DBMulti1', FILENAME = N'Z:\SQLDATA\DBMulti1.mdf' , SIZE = 3MB , FILEGROWTH = 128KB ),
( NAME = N'DBMulti2', FILENAME = N'Z:\SQLDATA\Disk2\DBMulti2.mdf' , SIZE = 3MB , FILEGROWTH = 128KB )
 LOG ON 
( NAME = N'DBMulti_log', FILENAME = N'Y:\SQLLOGS\DBMulti_log.ldf' , SIZE = 1MB , FILEGROWTH = 1MB)
GO

ALTER DATABASE DBMulti SET RECOVERY SIMPLE


USE DBMulti 
GO 

--Drop Table TestRRPFA
Create Table TestRRPFA
(ID INT identity (1,1),
Name Char(4000) DEFAULT 'AYMAN',
Name2 Char(4049) DEFAULT 'AYMAN')


--CHECKPOINT
--go
--DBCC DROPCLEANBUFFERS

----http://www.mssqltips.com/sqlservertip/1805/different-ways-to-determine-free-space-for-sql-server-databases-and-database-files/
---Thanks Greg Robidoux for the free space code
---I added FreeSpaceKB and NumberOfFreePages
SELECT DB_NAME() AS DbName, 
name AS FileName, 
size as NumberOfPages,
size/128.0 AS CurrentSizeMB,  
size/128.0 - CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT)/128.0 AS FreeSpaceMB,
size*8- CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT)*8 AS FreeSpaceKB,
size- CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT) AS NumberOfFreePages
FROM sys.database_files; 
--.8125mb
--2.93mb
---Note to self... hey idiot, remember the Table is large enough to have it's own extent so it will grow an extent when it allocates more space

SET NOCOUNT ON
--Initial Load 20 seconds
INSERT INTO TestRRPFA DEFAULT VALUES
GO 1000

---After initial load

INSERT INTO TestRRPFA DEFAULT VALUES
GO 8

SELECT DB_NAME() AS DbName, 
name AS FileName, 
size as NumberOfPages,
size/128.0 AS CurrentSizeMB,  
size/128.0 - CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT)/128.0 AS FreeSpaceMB,
size*8- CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT)*8 AS FreeSpaceKB,
size- CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT) AS NumberOfFreePages
FROM sys.database_files; 


---Each file is growing one at a time
DBCC TraceON (1117)
--DBCC TraceOFF (1117)
---This trace flag causes both files to grow together


----ADD SECONDARY FILEGROUP
---ADD TWO FILES each on a "Different" Drive

ALTER DATABASE DBMulti ADD FILEGROUP SecondFG

ALTER DATABASE [DBMulti] ADD FILE ( NAME = N'DBMulti3', FILENAME = N'Z:\SQLDATA\DBMulti3.ndf' , SIZE = 3072KB , FILEGROWTH = 128KB ) TO FILEGROUP [SecondFG]
GO
ALTER DATABASE [DBMulti] ADD FILE ( NAME = N'DBMulti4', FILENAME = N'Z:\SQLData\DISK2\DBMulti4.ndf' , SIZE = 3072KB , FILEGROWTH = 128KB ) TO FILEGROUP [SecondFG]
GO


--Drop Table TestRRPFASecondFG
---Table created on the other file group
Create Table TestRRPFASecondFG
(ID INT identity (1,1),
Name Char(4000) DEFAULT 'AYMAN',
Name2 Char(4049) DEFAULT 'AYMAN')
ON SecondFG


SELECT DB_NAME() AS DbName, 
name AS FileName, 
size as NumberOfPages,
size/128.0 AS CurrentSizeMB,  
size/128.0 - CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT)/128.0 AS FreeSpaceMB,
size*8- CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT)*8 AS FreeSpaceKB,
size- CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT) AS NumberOfFreePages
FROM sys.database_files; 
--.8125mb
--2.93mb
---Note to self... hey idiot, remember the Table is large enough to have it's own extent so it will grow an extent when it allocates more space

SET NOCOUNT ON
--Initial Load 20 seconds
INSERT INTO TestRRPFASecondFG DEFAULT VALUES
GO 1000

---After initial load

INSERT INTO TestRRPFASecondFG DEFAULT VALUES
GO 8

SELECT DB_NAME() AS DbName, 
name AS FileName, 
size as NumberOfPages,
size/128.0 AS CurrentSizeMB,  
size/128.0 - CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT)/128.0 AS FreeSpaceMB,
size*8- CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT)*8 AS FreeSpaceKB,
size- CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT) AS NumberOfFreePages
FROM sys.database_files; 

---Create index on different file group
ALTER DATABASE DBMulti ADD FILEGROUP IndexFG


ALTER DATABASE [DBMulti] ADD FILE ( NAME = N'IndexFG', FILENAME = N'Z:\SQLDATA\IndexFG.ndf' , SIZE = 3072KB , FILEGROWTH = 128KB ) TO FILEGROUP IndexFG
GO

--_WARNING POOR INDEX DESIGN
---Index Created on the primary table
CREATE NONCLUSTERED INDEX NCIDX_TEST on TestRRPFA(ID) INCLUDE (Name) ON INDEXFG
CREATE NONCLUSTERED INDEX NCIDX_TEST2 on TestRRPFA(ID) INCLUDE (Name2) ON INDEXFG
--Redo Inserts on first created table
--Creating clustered index on another file group moves the table and its data to the other file group and its data file(s)

/* Other Free Space info

EXEC sp_HelpDB 'DBMulti'


USE master

----Size of individual files on each DB
select size*8/1024 AS SIZEMB,*
FROM sys.master_files m
INNER JOIN sys.databases d ON m.database_id=d.database_id
where d.name = 'DbMulti'
ORDER BY d.name

*/