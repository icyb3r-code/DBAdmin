
# Microsoft SQL server 2019



This Docuemt has many topics related to microsoft sql server 2019. This document will grow during my learning and studing SQL server and more topics and expereince I will gain, I will add more in future.



## Sql server best practice during installation

* To have better perofrmance Create Separate Hard Drives for:
    * backups
    * Logs 
    * Data
    * TempDB [if possible]
* Format Disk with 64K allocation unite size
* Add 1433 port to firewall inbound outbound
* Add 1434 Dedicated port (DAC) to firewall (needed if Database hanged the DBA can access using this port)

## Database Creation

Create new database is easy task you need just to right clieck and new database from the menu, below few steps you need to take care of:
* In Options Window keep below options as is:
   * Recovery model ==> full
   * Auto Close ==> False (if database Idel will auto close)
   * Auto Shrink ==> False (this will cuz system dagradation  if enabled) [will auto shrink datafile and logfiles]
   * Auto Stats and Auto Update Stats keep them true
   * database read-only keep it false.
   * Encryption Enabled ( this for TDE)

## SQL Server Agent 

* Allow you to automate tasks.
* If Database Engine Service is Down the agent is down.
* Using agent you can setup SMTP to be alerted or notified using email.
* You can create schedular & Job to automate tasks 

## DataFiles & FileGroups 

* Database have datafiles and primary Filegroup.
* Datafile is physicaly created on the HDD.
* FileGroup is logically created in DB.
* Datafile extension is MDF (Master Data File) and NDF (Non-Master Data file)
* If we create database using T-SQL command like below:
```sql
create database testdb;
-- this will take all default settings from the Module database, so the module database is like a template to create a new database.
```
* The Default table creation will be on primary filegroup.
```sql
create table t1 (
    id_n int identity(1,1),
    name varvhar(100)
)
```
* To change the Default filegroup of the table to antoher filegroup like (filegroup1) you can do like below:
```sql
create table t1 (
    id_n int identity(1,1),
    name varvhar(100)
) on filegroup1
```
* FileGroup fills its belong datafiles using Proportional Fill Algorithm, means that it will check the datafiles percentage and write that data for the higher percentage to unused space.



## Transaction Log 



* More than one Datafile increase the performance.
* More than one transcational log will not inhance the performance.
* Transcation Log file don't have filegroup. 
* T-Log refare to Transaction Logs. 
* T-Log affect the recovery  Mode.
* Transactions are (Update,Insert,Delete).
* Committed Transaction (complete Transa)
* RolledBack Transactopm(incomplet Transa)
* 
