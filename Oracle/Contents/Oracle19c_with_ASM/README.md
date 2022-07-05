# [ Oracle Complete Scenario ] GI 19c [ASM] DB 19c on [ Oracle Linux 8.3 ] + RMAN

In this Document we will start with oracle linux 8.3 installation, then move to apply the prerequisites for both GI and DB, after that we going to proceed to Oracle Grid Infrastructure 12.2 installation with ASM then Oracle 19.3 Database software only installation, Once we finish the installation, we will create database, then using RMAN we'll simulate the weekly full backup and daily archivelog backup from the database, then create objects during this process, after finish all of this, we will drop the database, and we going to try to rebuild it by restoring the RMAN backup taken from dropped one.

**Requirements:*

1. Oracle Linux 8.3.
2. Oracle 19.3 Grid Infrastructure (GI)
3. Oracle 19.3 Database (DB)
4. VMWare or VBox 
5. Vitrual Machine Resource allocation:
   * s8 GB RAM
   * 4 Cores [CPU]
   * 60 GB Virtual Disk for OS
   * 30 GB Virtual Disk for ASM 
   * 5 GB Virtual Disk for RMAN Backup

**The steps that we are going to follow are:**

1. Prepare the OS for Grid and DB installation 
2. Installing oracle grid infrastructure 19.3 software
3. Create Data and FRA disk groups 
4. Installing Oracle DB 19.3 software only
5. Create database using dbca
6. RMAN backup strategy 
7. Configure RMAN and Perform a weekly Full backup
8. Create Database Objects
9. Simulate the archivelog daily backup  
10. Drop/Delete DB 
11. Restore DB from Backup
12. Add DB service

## Prepare the OS for the Installation [Prerequisites]

You need for oracle ASMLib and you can download it here [ASMLib8](https://www.oracle.com/linux/downloads/linux-asmlib-v8-downloads.html) [ASMLib7](https://t.co/LdLARKARIW?amp=1) [ASMSupport](https://t.co/vQUxkhSNaq?amp=1) 

check the Internet connectivity using ping :

```bash
# check internet connectivity 
 ping www.google.com
```

check cache to download the metadata from online repo:

```bash
# check the cache
 dnf makecache
```

Install prerequisites and ASM required packages:

```bash
# Install oracle prereqisites  
 dnf install oracle-database-preinstall-19c -y 
```

this step is optional if you want to update the system:

```bash
# Optional 
dnf check-update # list the packages that need for update  
dnf update 
dnf clean all
```

Create OS groups for asm administration and operation:

```bash
# Create ASM groups 
groupadd -g 54327 asmdba
groupadd -g 54328 asmoper
groupadd -g 54329 asmadmin
```

Add `asmdba` as secondary group to oracle user:

```bash
# add asmdba group to oracle user
 usermod -a -G asmadmin,asmdba oracle
 id oracle 
```

Create Grid user:

```bash
# create grid user 
 useradd -u 54331 -g oinstall -G dba,asmdba,asmadmin,asmoper,racdba grid
```

Change the password for Oracle and Grid user:

```bash
# create grid oracle user passwords 
 passwd oracle
 passwd grid
```

Create the Directories for the Oracle Grid installation 

```bash
mkdir -p /u01/19c/oracle_base
mkdir -p /u01/19c/oracle_base/oracle/db_home
chown -R oracle:oinstall /u01
```

Create the Directories for the Oracle Database installation 

```bash
mkdir -p /u01/19c/grid_base
mkdir -p /u01/19c/grid_home
chown -R grid:oinstall /u01/19c/grid_base /u01/19c/grid_home
chmod -R 775 /u01
```

Switch to the `grid` user and edit the Grid `.bash_profile`, before edit the file I will take backup for it first

```bash
su - grid
cd /home/grid
cp .bash_profile .bash_profile.bkp

```

Copy and paste this to grid home directory 

```bash
cat > /home/grid/.grid19c_env <<EOF
# User specific environment and startup programs
ORACLE_SID=+ASM; export ORACLE_SID
ORACLE_BASE=/u01/19c/grid_base; export ORACLE_BASE
ORACLE_HOME=/u01/19c/grid_home; export ORACLE_HOME
ORACLE_TERM=xterm; export ORACLE_TERM
JAVA_HOME=/usr/bin/java; export JAVA_HOME
TNS_ADMIN=\$ORACLE_HOME/network/admin; export TNS_ADMIN
PATH=.:\${JAVA_HOME}/bin:\${PATH}:\$HOME/bin:\$ORACLE_HOME/bin
PATH=\${PATH}:/usr/bin:/bin:/usr/local/bin
export PATH
umask 022
EOF
```

apply the profile for the current session and check the environment variables:

```bash
echo "source ~/.grid19c_env" >> ~/.bash_profile
source .bash_profile
env | grep -i "tns\|oracle"exit
```

Switch to `oracle` user and backup the `.bash_profile` :

```bash
su - oracle 
cp .bash_profile .bash_profile.bkp
```

create new bash profile file copy the below script to your terminal and press enter:

```bash
cat > /home/oracle/.db19c_env <<EOF
# specific environment and startup programs
ORACLE_HOSTNAME=\$HOSTNAME; export ORACLE_HOSTNAME
ORACLE_SID=prod; export ORACLE_SID
ORACLE_UNQNAME=prod; export ORACLE_UNQNAME
ORACLE_BASE=/u01/19c/oracle_base; export ORACLE_BASE
ORACLE_HOME=\$ORACLE_BASE/oracle/db_home; export ORACLE_HOME
ORACLE_TERM=xterm; export ORACLE_TERM
JAVA_HOME=/usr/bin/java; export JAVA_HOME
TNS_ADMIN=\$ORACLE_HOME/network/admin; export TNS_ADMIN
PATH=.:\${JAVA_HOME}/bin:\${PATH}:\$HOME/bin:\$ORACLE_HOME/bin
PATH=\${PATH}:/usr/bin:/bin:/usr/local/bin
NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"; export NLS_DATE_FORMAT
TNS_ADMIN=\$ORACLE_HOME/network/admin; export TNS_ADMIN
PATH=.:\${JAVA_HOME}/bin:\${PATH}:\$HOME/bin:\$ORACLE_HOME/bin
PATH=\${PATH}:/usr/bin:/bin:/usr/local/bin
TEMP=/tmp ;export TMP
TMPDIR=\$tmp ; export TMPDIR
export PATH
umask 022
EOF
```

apply the profile 

```bash
echo "source ~/.db19c_env" >> ~/.bash_profile
source /home/oracle/.bash_profile
env | grep ORACLE
exit
```

Check the NTP service 

```bash
systemctl status chronyd
```

set secure linux to permissive 

```bash
# change SELINUX=enforcing to SELINUX=permissive
sed -i s/SELINUX=enforcing/SELINUX=permissive/g /etc/selinux/config
sed -i s/SELINUX=enforcing/SELINUX=disabled/g /etc/selinux/config
cat /etc/selinux/config
# Forse the change  
setenforce Permissive

# create limitation in security forlder for grid user 
cp /etc/security/limits.d/oracle-database-preinstall-19c.conf /etc/security/limits.d/grid-database-preinstall-19c.conf

# rename oracle with grid in this file grid-database-preinstall-19c.conf
# use vim 
vim /etc/security/limits.d/grid-database-preinstall-19c.conf
:%s/oracle/grid/g
:x
```

allow the port 1521 port in the Linux firewall [ref-link](https://www.ateam-oracle.com/opening-ports-in-linux-7-firewalls-for-oracle-analytics-cloud-access-to-databases-and-remote-data-connector)

```bash
# allow the traffic for the port 1521
firewall-cmd  --permanent --add-port=1521/tcp
firewall-cmd --list-ports
# OR Stop the firewall and disable it 
systemctl stop firewalld
systemctl disable firewalld
```



Configure the Oracle ASM

```bash
# Add to the vmx file for the VM
disk.EnableUUID = "TRUE"

# detect the Vmware disks without reboot the machine 
echo "- - -" >> /sys/class/scsi_host/host1/scan

# format the disks on both nodes
 export HDISK="/dev/sdb"
 echo -e "d\nn\n\n\n\n+5G\np\nn\np\n\n\n+15G\np\nn\np\n\n\n\n\np\nw" | fdisk $HDISK
 fdisk -l 

udevadm info --query=property --name /dev/sdb1
udevadm info --query=property --name /dev/sdb2
udevadm info --query=property --name /dev/sdb3
/lib/udev/scsi_id -gud /dev/
vim /etc/udev/rules.d/99-asm-disks.rules

36000c29d381cc4882ee074a9333f9ee2
# paste below to the file 

KERNEL=="sd*",ENV{DEVTYPE}=="partition",ATTR{partition}=="1",PROGRAM=="/lib/udev/scsi_id -gud /dev/$name",RESULT=="36000c2901abcc9d26317288407432092",SYMLINK+="oracleasm/OCR_ASM_1", OWNER="grid", GROUP="asmadmin", MODE="0660"
KERNEL=="sd*",ENV{DEVTYPE}=="partition",ATTR{partition}=="2",PROGRAM=="/lib/udev/scsi_id -gud /dev/$name",RESULT=="36000c2901abcc9d26317288407432092",SYMLINK+="oracleasm/DAT_ASM_1", OWNER="grid", GROUP="asmadmin", MODE="0660"
KERNEL=="sd*",ENV{DEVTYPE}=="partition",ATTR{partition}=="3",PROGRAM=="/lib/udev/scsi_id -gud /dev/$name",RESULT=="36000c2901abcc9d26317288407432092",SYMLINK+="oracleasm/FRA_ASM_1", OWNER="grid", GROUP="asmadmin", MODE="0660"

fsck -N /dev/sdb?

# Load updated block device partition table
partx -u /dev/sdb1
partx -u /dev/sdb2
partx -u /dev/sdb3

# test the rules are working as expected 
udevadm test /block/sdb/sdb1
udevadm test /block/sdb/sdb2
udevadm test /block/sdb/sdb3

# Reload the UDEV rules 
udevadm control --reload-rules && udevadm trigger --action=add
```







## Installing oracle grid infrastructure 19c software 

Download the Oracle grid 12.2 software from edelivary.oracle.com then use your preferred way to move them to the server using `scp , ftp, sftp` then unzip the files:

```bash
unzip LINUX.X64_193000_grid_home.zip
```

if you working remotely you need to configure the display for remote connection x11 forwarding:

```bash
export DISPLAY=10.10.20.1:0.0
xhost +
# to test the x11 forwarding run below command 
xev
export CV_ASSUME_DISTID=OEL7.6
```

 

then we need to run the setup script to start the installation. 

```bash
./gridSetup.sh
```

change the discovery path as shown below:

![image-20210318123531045](/Oracle19c_With_ASM.assets/image-20210318123531045.png)

fill the windows same as below 

![image-20210318123422962](Oracle19c_With_ASM.assets/image-20210318123422962.png)

click next and set a same password for all of the accounts

![image-20210318123658435](Oracle19c_With_ASM.assets/image-20210318123658435.png)

press yes and continue the installation steps 

![image-20210318123738568](Oracle19c_With_ASM.assets/image-20210318123738568.png)

then next 

![image-20210318123808232](Oracle19c_With_ASM.assets/image-20210318123808232.png)

then next 

![image-20210318123837269](Oracle19c_With_ASM.assets/image-20210318123837269.png)

the below should the same check the oracle home and oracle base are important this will be the path of directories where oracle will be installed:

![image-20210318123958986](Oracle19c_With_ASM.assets/image-20210318123958986.png)

click next 

![image-20210318130440286](Oracle19c_With_ASM.assets/image-20210318130440286.png)



click next

![image-20210318130504286](Oracle19c_With_ASM.assets/image-20210318130504286.png)

Click Fix & Check Again

![image-20210318130604188](Oracle19c_With_ASM.assets/image-20210318130604188.png)

Click OK

![image-20210318130631619](Oracle19c_With_ASM.assets/image-20210318130631619.png)

Ignore if the other Unfixed issues then Next 

![image-20210318131005536](Oracle19c_With_ASM.assets/image-20210318131005536.png)

The summary window will show up click next 

![image-20210318131039256](Oracle19c_With_ASM.assets/image-20210318131039256.png)

The installation process will start here 



It will ask you to run the two scripts as root.

![image-20210522100053712](Oracle19c_With_ASM.assets/image-20210522100053712.png)

fist script ran from script 

![image-20210522100239683](Oracle19c_With_ASM.assets/image-20210522100239683.png)



the second script ran from root and it will take time to finished. 

![image-20210522110156257](Oracle19c_With_ASM.assets/image-20210522110156257.png)



![image-20210522110242702](Oracle19c_With_ASM.assets/image-20210522110242702.png)

Once the both scripts finished successfully you can Press OK on the dialog and continue with the installation:

![image-20210522110322791](Oracle19c_With_ASM.assets/image-20210522110322791.png)

close the windows 

![image-20210522122215970](Oracle19c_With_ASM.assets/image-20210522122215970.png)

lets check the grid services 

```bash
# from Grid user crsctl stat res -tsqlplus -s / as sysdba <<EOFselect instance_name from v\$instance;EOF
```



## Create Data and FRA disk groups

Then We need to create the DATA and FRA disk groups to install oracle database on them.

```bash
asmca
```

this windows will pop up

 ![image-20210318163014064](Oracle19c_With_ASM.assets/image-20210318163014064.png)

Using mouse right click on the DIsk Groups then new windows will pop up

Create Data Disk group

![image-20210522190531532](Oracle19c_With_ASM.assets/image-20210522190531532.png)

Create FRA Disk Group

![image-20210522190639624](Oracle19c_With_ASM.assets/image-20210522190639624.png)

At the end you should have like below screenshoot 

![image-20210522191009066](Oracle19c_With_ASM.assets/image-20210522191009066.png)

check the cluster resource if the disk groups have the cluster services using below command:

```bash
crsctl stat res -t
# the restult should be 
# ora.CRS.dg    ONLINE  ONLINE       oracle                   STABLE
# ora.DATA.dg   ONLINE  ONLINE       oracle                   STABLE
# ora.FRA.dg    ONLINE  ONLINE       oracle                   STABLE
```



## Installing Oracle DB 19c software Only

unzip the oracle database 19c zipped files in the home dir location :

```bash
unzip LINUX.X64_193000_db_home.zip
```

Go to database directory and run below command 

```bash
export CV_ASSUME_DISTID=OEL7.6

./runInstaller
```



click install software only option then next 

![image-20210522202916090](Oracle19c_With_ASM.assets/image-20210522202916090.png)

Single instance database installation 

![image-20210522202958811](Oracle19c_With_ASM.assets/image-20210522202958811.png)

Enterprise Edition 

![image-20210522203101063](Oracle19c_With_ASM.assets/image-20210522203101063.png)



check the oracle base and oracle home then click next 

![image-20210522203250799](Oracle19c_With_ASM.assets/image-20210522203250799.png)





Check the OS groups then next 

![image-20210522203347599](Oracle19c_With_ASM.assets/image-20210522203347599.png)

Click press Ignore then next if there is any warnings otherwise Check the sammary and Click Install  

![image-20210522203444162](Oracle19c_With_ASM.assets/image-20210522203444162.png)





The Installation begin 

![image-20210522203553559](Oracle19c_With_ASM.assets/image-20210522203553559.png)

ask us to run the root.sh as `root` user 

![image-20210522203725396](Oracle19c_With_ASM.assets/image-20210522203725396.png)

Run the root.sh in the terminal as user 

![image-20210522203847556](Oracle19c_With_ASM.assets/image-20210522203847556.png)

Press OK and then close the window

![image-20210522203934597](Oracle19c_With_ASM.assets/image-20210522203934597.png)

## Create database using dbca

To create database we need to run the below command as `oracle` user 

```bash
dbca
```

select create new database 

![image-20210522204212498](Oracle19c_With_ASM.assets/image-20210522204212498.png)

Select Advance Mode then next 

![image-20210522204256293](Oracle19c_With_ASM.assets/image-20210522204256293.png)

Select General Purpose or Transaction Processing 

![image-20210522204338107](Oracle19c_With_ASM.assets/image-20210522204338107.png)

 Fill the textboxes with the required data based on your need:

![image-20210522204454133](Oracle19c_With_ASM.assets/image-20210522204454133.png)

Use ASM as database storage 

![image-20210522204611045](Oracle19c_With_ASM.assets/image-20210522204611045.png)

Enable the FRA and select ASM as FRA storage

![image-20210522204945557](Oracle19c_With_ASM.assets/image-20210522204945557.png)







Click next 

![image-20210522205040736](Oracle19c_With_ASM.assets/image-20210522205040736.png)

click next

![image-20210522205120402](Oracle19c_With_ASM.assets/image-20210522205120402.png)



Fill the data and see below screenshoot:

![image-20210522205423070](Oracle19c_With_ASM.assets/image-20210522205423070.png)

Deselect EM and click next:

![image-20210522205503479](Oracle19c_With_ASM.assets/image-20210522205503479.png)

Fill the Password and click next 

![image-20210522205605005](Oracle19c_With_ASM.assets/image-20210522205605005.png)



Create database and next 

![image-20210522205657215](Oracle19c_With_ASM.assets/image-20210522205657215.png)



Check the summary and Finish 

![image-20210522205752572](Oracle19c_With_ASM.assets/image-20210522205752572.png)

once finished we can close the windows 

![image-20210522220123601](Oracle19c_With_ASM.assets/image-20210522220123601.png)



## RMAN backup strategy 

Note: in this scenario I'm using the control file instead of RMAN catalog database and the RMAN control file autobackup should be enabled.

**FULL Backup**

I will take RMAN full backup pluse archivelog files once a week and delete the archivelog files from the disk once the successful backup finished

**Archivelog Backup**

I will incrementally backup the archivelog 



## Configure RMAN and Perform a weekly Full backup

Using `oracle` on Linux OS to create a backup Directory as shown below:

```bash
mkdir -p /u02/backup
```



Check the RMAN configuration 

```bash
# This will show the default configuration show all
# check if autobackup for control file are enabled 
# We need to modify some 
configuration CONFIGURE SNAPSHOT CONTROLFILE NAME TO '/u02/backup/snapcf_PROD.f';
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/u02/backup/ctr_%F';
configure channel device type disk format '/u02/backup/bkp_%U.bkp';
```

Need to run below script once a week use cronjob to make it weekly bases job on your Linux OS: and to backup the Database as full backup run below script: 

```bash
rman target / nocatalog <<RMAN
run {
allocate channel c1 device type disk format '/u02/backup/bkp1_%U';
allocate channel c2 device type disk format '/u02/backup/bkp2_%U'; 
show all;crosscheck backup;
crosscheck archivelog all;
delete noprompt expired backup;delete noprompt obsolete;
sql "alter system checkpoint";
SQL "ALTER SYSTEM ARCHIVE LOG CURRENT";
backup archivelog all  tag="ARC_BACKUP_20210324"  MAXSETSIZE 50M;BACKUP FILESPERSET 1 FULL DATABASE SKIP READONLY TAG='FULL_BACKUP_20210324' PLUS ARCHIVELOG NOT BACKED UP 1 TIMES TAG='ARC_BACKUP_20210324' format='/u02/backup/ARC_%T_%p.bkp';
DELETE NOPROMPT ARCHIVELOG ALL BACKED UP 1 TIMES TO DEVICE TYPE DISK;
SQL "ALTER SYSTEM ARCHIVE LOG CURRENT";
}
RMAN
```



## Create Database Objects

Use `oracle` on Linux OS go to the Documents directory `/home/oracle/Documents` and run below commands :

```bash
cat > 1.sql <<EOFconnect hr/hr1234@prod1pdbinsert into emp values (1,'icyb3r');insert into emp values (2,'icyb3r2');commit;EOFcat > 2.sql <<EOFconnect hr/hr1234@prod1pdbinsert into emp values (3,'icyb3r3');insert into emp values (4,'icyb3r4');commit;EOFcat > 3.sql <<EOFconnect hr/hr1234@prod1pdbinsert into emp values (5,'icyb3r5');insert into emp values (6,'icyb3r6');commit;EOFcat > 4.sql <<EOFconnect hr/hr1234@prod1pdbinsert into emp values (7,'icyb3r7');insert into emp values (8,'icyb3r8');commit;EOFcat > 5.sql <<EOFconnect hr/hr1234@prod1pdbinsert into emp values (9,'icyb3r9');insert into emp values (10,'icyb3r10');commit;EOFcat > 6.sql <<EOFconnect hr/hr1234@prod1pdbinsert into emp values (11,'icyb3r11');insert into emp values (12,'icyb3r12');commit;EOFcat > u.sql <<EOFcreate user hr identified by hr1234;grant connect,resource to hr;--alter user hr quota 100M on users;grant unlimited tablespace to hr ;EOFcat > arc.sql <<EOFalter system checkpoint;alter system archive log current;EOFcat > c.sql <<EOFalter session set container=prod1pdb;connect hr/hr1234@prod1pdbEOFcat > s.sql <<EOFconnect hr/hr1234@prod1pdbselect * from emp;EOFcat > t.sql <<EOFconnect hr/hr1234@prod1pdbcreate table emp (id number (10),name varchar2(45));EOF
```

on the same directory `/home/oracle/Documents` login to oracle sqlplus using this cmmand `sqlplus / as sysdba`  and run below scripts:

```sql
-- create HR user @cu -- Create table emp@t--insert records @1-- archive log file @arc--insert records @2-- archive log file @arc
```



## Simulate the archivelog daily backup 

Note this should run as daily bases using cronjob on your Linux os.

Tag here for the next day after the backup taken `TAG='ARC_BACKUP_20210325'` 

```bash
rman target / nocatalog <<RMANrun {allocate channel c1 device type disk format '/u02/backup/ARC1_%U';SQL "ALTER SYSTEM ARCHIVE LOG CURRENT";BACKUP ARCHIVELOG ALL NOT BACKED UP 1 TIMES TAG='ARC_BACKUP_20210325'  MAXSETSIZE 50M;DELETE NOPROMPT ARCHIVELOG ALL BACKED UP 1 TIMES TO DEVICE TYPE DISK;}RMAN
```

Login to sqlplus and add more records from this direcotry  `/home/oracle/Documents` :

```sql
--add more records @3--archive the log file @arc-- insert recods @4--archive the log file @arc
```



run backup for archive log files and change the tag `TAG='ARC_BACKUP_20210326'` for the next day 

```bash
rman target / nocatalog <<RMANrun {allocate channel c1 device type disk format '/u02/backup/ARC1_%U';SQL "ALTER SYSTEM ARCHIVE LOG CURRENT";BACKUP ARCHIVELOG ALL NOT BACKED UP 1 TIMES TAG='ARC_BACKUP_20210326'  MAXSETSIZE 50M;DELETE NOPROMPT ARCHIVELOG ALL BACKED UP 1 TIMES TO DEVICE TYPE DISK;}RMAN
```



using sqlplus again and make sure that you are on this location  `/home/oracle/Documents` :

```sql
--add more records @5--archive the log file @arc-- insert recods @6--archive the log file @arc
```



run backup for archive log files and change the tag `TAG='ARC_BACKUP_20210327'` for the next day 

```bash
rman target / nocatalog <<RMANrun {allocate channel c1 device type disk format '/u02/backup/ARC1_%U';SQL "ALTER SYSTEM ARCHIVE LOG CURRENT";BACKUP ARCHIVELOG ALL NOT BACKED UP 1 TIMES TAG='ARC_BACKUP_20210327'  MAXSETSIZE 50M;DELETE NOPROMPT ARCHIVELOG ALL BACKED UP 1 TIMES TO DEVICE TYPE DISK;}RMAN
```



## Drop/Delete DB

Using `dbca` we can delete the database from the system:



## Restore DB from Backup

* Create a dummy init file.
* Startup nomount usning that dummy init file.
* login to rman and restore spfile from pfile
* copy the spfile to ASM 
* edit the pfile to point to the spfile in ASM
* startup force nomount the instance to take the new spfile 
* login to rman again 
* restore the control file that contains the full backup
* mount the database 
* restore database 
* recover database 
* startup force nomount 
* restore control file from last backup
* mount database
* recover database

```bash
restore archivelog all;crosscheck archivelog all;switch database to copy;catalog start with '+DATA';list backup of archivelog all;report schema 
```

Using grid user you need to create the below directory 

```bash
alter diskgroup DATA add directory '+DATA/PROD';alter diskgroup DATA add directory '+DATA/PROD/DATAFILE';alter diskgroup DATA add directory '+DATA/PROD/BE20CD2F85936486E0530100007F91C9';alter diskgroup DATA add directory '+DATA/PROD/FD9AC20F64D244D7E043B6A9E80A2F2F';alter diskgroup DATA add directory '+DATA/PROD/BE20CD2F85936486E0530100007F91C9/DATAFILE';alter diskgroup DATA add directory '+DATA/PROD/FD9AC20F64D244D7E043B6A9E80A2F2F/DATAFILE';alter diskgroup DATA add directory '+DATA/PROD/PARAMETERFILE';alter diskgroup DATA add directory '+DATA/PROD/TEMPFILE';alter diskgroup DATA add directory '+DATA/PROD/BE20B9BE42B92155E0530100007FCCB4';alter diskgroup DATA add directory '+DATA/PROD/CONTROLFILE';alter diskgroup DATA add directory '+DATA/PROD/ONLINELOG';alter diskgroup FRA add directory '+FRA/PROD';alter diskgroup FRA add directory '+FRA/PROD/CONTROLFILE';alter diskgroup FRA add directory '+FRA/PROD/ONLINELOG';alter diskgroup FRA add directory '+FRA/PROD/ARCHIVELOG';
```





## Add DB service

Once we finished we need to add database service to the cluster ware that will be managed through it:

```bash
srvctl add database -d PROD -a DATA,FRA -o $ORACLE_HOME -p +DATA/PROD/spfilePROD.orasrvctl sart database -d prod srvctl status database -d prod# Listener status and services lsnrctl status lsnrctl services # inside the sqlplus we need to open the pluggable database sqlplus -s / as sysdba <<SQLFalter pluggable database prod1pdb open;SQLF
```

**Netca**

create service name on the server to be able to connect to the prod1pdb pluggable database

**Verify** 

Using `oracle` user move to `/home/oracle/Documents` then user this command:

```sql
sqlplus -s / as sysdba <<SQLFconnect hr/hr1234@prod1pdbselect * from emp;SQLF
```



```bash
# stop all resources crsctl stop resource -all# stop high availablity services crsctl stop has
```













