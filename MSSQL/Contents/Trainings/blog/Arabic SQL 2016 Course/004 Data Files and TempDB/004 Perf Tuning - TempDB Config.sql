---One file per Core? Not really... start with 8

---Alter Current File
ALTER DATABASE TempDB
MODIFY FILE
(Name = 'TempDev', 
Size = 1MB,
FileGrowth=1MB)
GO

ALTER DATABASE TempDB
ADD FILE 
(Name = 'TempDev2',
FileName ='E:\MSSQL\TEMPDB\TempDB2.mdf',
Size = 1MB, 
FileGrowth = 1MB)
GO

ALTER DATABASE TempDB
ADD FILE 
(Name = 'TempDev3',
FileName ='E:\MSSQL\TEMPDB\TempDB3.mdf',
Size = 1MB, 
FileGrowth = 1MB)
GO

ALTER DATABASE TempDB
ADD FILE 
(Name = 'TempDev4',
FileName ='E:\MSSQL\TEMPDB\TempDB4.mdf',
Size = 1MB, 
FileGrowth = 1MB)
GO