USE Master
Create Database ManyBackupTest
------
------Full Backup to same file
BACKUP Database ManyBackupTest to Disk = N'D:\MSSQLServer\Backup\ManyBackupTest.bak'
GO

------Backup Diff to same file
BACKUP Database ManyBackupTest to Disk = N'D:\MSSQLServer\Backup\ManyBackupTest.bak'
WITH DIFFERENTIAL
GO
------Backup Log to same file
BACKUP LOG ManyBackupTest to Disk = N'D:\MSSQLServer\Backup\ManyBackupTest.bak'
GO

-----Check the validity of the backup
RESTORE VERIFYONLY 
FROM Disk = N'D:\MSSQLServer\Backup\ManyBackupTest.bak'

---Quick way to see file name information (logical/Physical) on a backup file
RESTORE FILELISTONLY
FROM Disk = N'D:\MSSQLServer\Backup\ManyBackupTest.bak'

/*
The type of file, one of:
L = Microsoft SQL Server log file
D = SQL Server data file
F = Full Text Catalog
FOR DETAILS VISIT: http://msdn.microsoft.com/en-us/library/ms173778.aspx
*/

RESTORE HEADERONLY
FROM Disk = N'D:\MSSQLServer\Backup\ManyBackupTest.bak'

/*
Backuptype:
1 = Database	2 = Transaction log		4 = File	5 = Differential database
6 = Differential file	7 = Partial	8 = Differential partial
Also a column called BackupTypeDescription :)
FOR DETAILS VISIT: http://msdn.microsoft.com/en-us/library/ms178536.aspx
*/


/*Create Backup Device*/

USE [master]
GO

/****** Object:  BackupDevice [BackupDevice1]    Script Date: 1/24/2013 7:42:58 PM ******/
EXEC master.dbo.sp_addumpdevice  @devtype = N'disk', 
@logicalname = N'BackupDevice1', 
@physicalname = N'D:\MSSQLServer\Backup\BackupDevice1.bak'
GO

BACKUP Database ManyBackupTest to BackupDevice1
GO

Restore FILELISTONLY
FROM BackupDevice1

RESTORE HEADERONLY
FROM BackupDevice1


---Remove Backup Device ---WILL NOT DELETE LOCAL FILE!!
/****** Object:  BackupDevice [BackupDevice1]    Script Date: 1/24/2013 7:43:28 PM ******/
EXEC master.dbo.sp_dropdevice @logicalname = N'BackupDevice1'
GO
---Trying a DB Restore after the Device is removed will fail
---It will by default look for the last backup 
---because we did not select copy-only it will look for the one on the backup Device
---If we did not delete the backup device file, we can recreate the device and resume the restore


---CLEAN UP
USE master
DROP Database ManyBackupTest







