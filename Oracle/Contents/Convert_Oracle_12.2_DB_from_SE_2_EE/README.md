## Convert DB from Standard to Enterprise Edition

### Method 1

If you are using the Standard Edition of the Oracle Database and want to move to the Enterprise Edition, then complete the following steps:

* Ensure that the release number of your Standard Edition server  software is the same release as the Enterprise Edition server software.

* For example, if your Standard Edition server software is release  12.2.0.1, then you should upgrade to release 12.2.0.1 of the Enterprise  Edition.

- Shut down your database stop listener. [ If your operating system is Windows, then stop all Oracle services,  including the OracleServiceSID Oracle service, where SID is the instance name. ]
- Copy the important files and directories that needed for the database such as network,dbs ...etc, if you have any sensitive data in home will be deleted as well.

- Deinstall the Standard Edition server software. [Link1](https://docs.oracle.com/en/database/oracle/oracle-database/12.2/ladbi/oracle-deinstallation-tool-deinstall.html#GUID-71E860C5-4E1E-4D2F-AFD1-141709A172C0) , Link2

  ```bash
  ./runInstaller -deinstall -home /u01/app/oracle/product/12.2.0.1/db_1/
  ```

- Install the Enterprise Edition server software using the Oracle Universal Installer.

- Select the same Oracle home that was used for the de-installed  Standard Edition. During the installation, be sure to select the  Enterprise Edition.

- When prompted, choose Software Only from the Database Configuration screen.

- Start up your database.

Your database is now upgraded to the Enterprise Edition.
 You can verify it from the banner:

```sql
SQL> select banner from v$version;

BANNER
--------------------------------------------------------------------------------
Oracle Database 12c Enterprise Edition Release 12.2.0.1.0 - 64bit Production
PL/SQL Release 12.2.0.1.0 - Production
CORE	12.2.0.1.0	Production
TNS for Linux: Version 12.2.0.1.0 - Production
NLSRTL Version 12.2.0.1.0 - Production

```



### Method 2

You are using a Standard Edition (SE) database and want to convert  it to the Enterprise Edition (EE) because functionality you require is  not part of the SE. Since the same “SQL.BSQ” script is used to create  the database for each version, the databases are internally almost  identical. The conversion process is therefore not very complicated.

The following steps need to be taken to convert your SE database to an EE:

1. **Backup the database and Oracle Home.**

2. **Back up all database files under the current Oracle home that you need to keep.**
   | On Unix, back up $Oracle_Home/dbs/.
   | On Windows, back up $Oracle_Home/database/.
   | $Oracle_Home/network/admin

3. **Deinstall oracle home using below command**

   ```bash
   ./runInstaller -deinstall -home /u01/app/oracle/product/12.2.0.1/db_1/
   ```

4. **Install the EE software in a new ORACLE_HOME.**

5. **Copy the Listener files and parameter files** in new oracle home.

6. **Startup the database** from new home of Enterprise Edition.

7. **Run the “catalog.sql” and “catproc.sql”** scripts.  (the execution of these two scripts may be not mandatory in all the  cases but better to run them because of complexity of data dictionary  and to be sure that all EE objects are created)

8. **Recompile all invalid objects** in the database by executing utlrp.sql script. You can execute this script 2-3 times to validate the dependencies.

**Note:** Please ensure that the release number (and patch level) of your  Enterprise Edition server software is the same release as the original  Standard Edition server software.
For example, if your Standard  Edition server software is release 12.2.0.1.0, then you must use release  12.2.0.1.0 of the Enterprise Edition

**You can verify current edition of the oracle database by connecting to the database or by querying the v$banner view.**







