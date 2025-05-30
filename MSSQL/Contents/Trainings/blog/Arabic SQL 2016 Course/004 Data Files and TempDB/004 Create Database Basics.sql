--New Syntax for SQL 2016
DROP DATABASE IF EXISTS TestDB
Go

CREATE DATABASE TestDB
 ON  PRIMARY 
( NAME = N'TestDB', FILENAME = N'E:\MSSQL\Data\TestDB.mdf' , SIZE = 4MB , FILEGROWTH = 128KB ),
 LOG ON 
( NAME = N'TestDB_log', FILENAME = N'E:\MSSQL\Logs\TestDB_log.ldf' , SIZE = 1MB , FILEGROWTH = 1MB)
GO

---Add New file to Database
ALTER DATABASE TestDB 
ADD FILE ( NAME = N'TestDB2', FILENAME = N'E:\MSSQL\Data\TestDB2.ndf' , SIZE = 4096KB , FILEGROWTH = 128KB )
GO

--Remove File from Database

USE master;
GO
ALTER DATABASE TestDB
REMOVE FILE TestDB2;
GO

--Modify File in Database

USE master;
GO
ALTER DATABASE TestDB 
MODIFY FILE
    (NAME = TestDB,
    SIZE = 10MB);
GO

--Move File to a New locaion
--Must Phyiscally Move DB
USE master;
GO
ALTER DATABASE TestDB
MODIFY FILE
(
    NAME = TestDB,
    FILENAME = N'E:\MSSQL\Data2\TestDB.mdf'
);
GO
