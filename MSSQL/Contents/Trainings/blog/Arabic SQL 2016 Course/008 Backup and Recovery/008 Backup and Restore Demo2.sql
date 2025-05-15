USE Master
Create Database ManyBackupTest
------
------Full Backup to same file
BACKUP Database ManyBackupTest to Disk = N'E:\MSSQL\Backups\ManyBackupTest.bak'
GO

------Backup Diff to same file
BACKUP Database ManyBackupTest to Disk = N'E:\MSSQL\Backups\ManyBackupTest.bak'
WITH DIFFERENTIAL
GO
------Backup Log to same file
BACKUP LOG ManyBackupTest to Disk = N'E:\MSSQL\Backups\ManyBackupTest.bak'
GO

-----Check the validity of the backup
RESTORE VERIFYONLY 
FROM Disk = N'E:\MSSQL\Backups\ManyBackupTest.bak'

---Quick way to see file name information (logical/Physical) on a backup file
RESTORE FILELISTONLY
FROM Disk = N'E:\MSSQL\Backups\ManyBackupTest.bak'

/*
The type of file, one of:
L = Microsoft SQL Server log file
D = SQL Server data file
F = Full Text Catalog
FOR DETAILS VISIT: http://msdn.microsoft.com/en-us/library/ms173778.aspx
*/

RESTORE HEADERONLY
FROM Disk = N'E:\MSSQL\Backups\ManyBackupTest.bak'

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
@physicalname = N'E:\MSSQL\Backups\BackupDevice1.bak'
GO

BACKUP Database ManyBackupTest to BackupDevice1
GO

Restore FILELISTONLY
FROM BackupDevice1

RESTORE HEADERONLY
FROM DISK = 'E:\MSSQL\Backups\BackupDevice1.bak'


---Remove Backup Device ---WILL NOT DELETE LOCAL FILE!!
/****** Object:  BackupDevice [BackupDevice1]    Script Date: 1/24/2013 7:43:28 PM ******/
EXEC master.dbo.sp_dropdevice @logicalname = N'BackupDevice1'
GO
---Trying a DB Restore after the Device is removed will fail
---It will by default look for the last backup 
---because we did not select copy-only it will look for the one on the backup Device
---If we did not delete the backup device file, we can recreate the device and resume the restore

--Encrypt a Backup file ***Does Not Require TDE** SQL 2014+
--Need to Create a MasterKey in the Master Database
Use Master
Create Master Key
Encryption By Password =  'Pa$$w0rd'
    
--Create Certificate in Master Database
Create Certificate BackupEncryptionCertificate
with Subject = 'Certificate to be used to Encrypt and Decrypt Backups'
    
--Use Certificate to Encrypt Backup
BACKUP Database ManyBackupTest to Disk = N'E:\MSSQL\Backups\ManyBackupTest_Encrypted.bak'
WITH Encryption
(
ALGORITHM = AES_256,
SERVER CERTIFICATE = BackupEncryptionCertificate
)
GO

--Backup to Network Path
BACKUP Database ManyBackupTest
TO DISK = '\\SQL2016\SQLShare\BackupToUrl.bak'
WITH COMPRESSION

--Will need a master key, but we already created it
--Backup To Azure
CREATE CREDENTIAL AzureStorageCredential 
WITH IDENTITY = 'aymanazstore', 
SECRET = '<storage key>'; --storage account key

BACKUP DATABASE ManyBackupTest 
TO URL = 'https://aymanazstore.blob.core.windows.net/sqlbackup/ManyBackupTest.bak' 
      WITH CREDENTIAL = 'AzureStorageCredential'
     ,COMPRESSION
     ,STATS = 5;
GO 
---URL Format 'https:// <mystorageaccountname>.blob.core.windows.net/<mystorageaccountcontainername>'

--Managed Backups in Azure
--https://msdn.microsoft.com/en-us/library/dn449491.aspx--

Use msdb;
GO
EXEC msdb.managed_backup.sp_backup_config_basic 
 @enable_backup = 1, 
 @database_name = 'ManyBackuptest',
 @container_url = 'https://aymanazstore.blob.core.windows.net/sqlbackup/', 
 @retention_days = 30
GO

---CLEAN UP
USE master
DROP Database ManyBackupTest
Drop Credential AzureStorageCredential
DROP Certificate BackupEncryptionCertificate
DROP Master Key









