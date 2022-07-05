# Oracle 19C database 



## Introduction 

### Installation prerequisites 

This series I will try to cover the Oracle 19c Single Instance installation, but before start you need the following softwares: 

* Oracle DB 19c (19.3) EE x64 : Download [link](https://www.oracle.com/database/technologies/oracle-database-software-downloads.html#19c)
* Operating System Oracle linux 8.x x64: Download [link](https://yum.oracle.com/oracle-linux-isos.html)
* VMware or VBox 64x : Download Vbox [link](https://www.virtualbox.org/wiki/Downloads) VMware [link](https://my.vmware.com/en/web/vmware/downloads/info/slug/desktop_end_user_computing/vmware_workstation_pro/16_0) [Optional]

### Installation Process

* Download the Softwares.
* Install OS Oracle Linux 8 and create VM snapshot.
* Apply Oracle DB 19c prerequisites and Create VM snapshot.
* Install Oracle DB Software only without DB and create VM snapshot. 
* Create DB.
* Test Database. 



## OS Installation 

this can be done on vmware straight forward:

## Oracle DB 19c Prerequisites 

### Automatic setup 

If you plan to use the "oracle-database-preinstall-19c" package to  perform all your prerequisite setup, issue the following command.

```
# dnf install -y oracle-database-preinstall-19c
```

this can be done if you install oracle database on RedHat 8 or Centos 8 use this to pull the package from oracle linux 8 Repo:

```
# dnf install -y https://yum.oracle.com/repo/OracleLinux/OL8/baseos/latest/x86_64/getPackage/oracle-database-preinstall-19c-1.0-1.el8.x86_64.rpm
```



### Additional Setup



Set the password for the "oracle" user.

```
passwd oracle
```

Set secure Linux to permissive by editing the "/etc/selinux/config" file, making sure the SELINUX flag is set as follows.

```
SELINUX=permissive
```

Once the change is complete, restart the server or run the following command.

```
# setenforce Permissive
```

If you have the Linux firewall enabled, you will need to disable or configure it, To disable it, do the following.

```
# systemctl stop firewalld
# systemctl disable firewalld
```

ICreate the directories in which the Oracle software will be installed.

```
mkdir -p /u01/app/oracle/product/19.3/dbhome_1
mkdir -p /u02/oradata
chown -R oracle:oinstall /u01 /u02
chmod -R 775 /u01 /u02
```

Putting  mount points directly under root without mounting separate disks to them is typically a bad idea. It's done here for simplicity, but for a real  installation "/" storage should be reserved for the OS.

Unless you are working from the console, or using SSH tunnelling, login as root and issue the following command.

```
xhost +<machine-name>
```

 The scripts are created using the `cat` command, with all the "$" characters escaped. If you want to manually create these files, rather than using the `cat` command, remember to remove the "\" characters before the "$" characters.

Create a "scripts" directory.

```
mkdir /home/oracle/scripts
```

Create an environment file called "setEnv.sh". The "$" characters are escaped using "\". If you are not creating the file with the `cat` command, you will need to remove the escape characters.

```

## copy this script to your terminal

cat > /home/oracle/scripts/setEnv.sh <<EOF

# Oracle Settings
export TMP=/tmp
export TMPDIR=\$TMP

export ORACLE_HOSTNAME=mydb.localdomain
export ORACLE_UNQNAME=mydb
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=\$ORACLE_BASE/product/19.3/dbhome_1
export ORA_INVENTORY=/u01/app/oraInventory
export ORACLE_SID=mydb
export PDB_NAME=pdb1
export DATA_DIR=/u02/oradata

export PATH=/usr/sbin:/usr/local/bin:\$PATH
export PATH=\$ORACLE_HOME/bin:\$PATH

export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=\$ORACLE_HOME/jlib:\$ORACLE_HOME/rdbms/jlib

EOF
```

Add a reference to the "setEnv.sh" file at the end of the "/home/oracle/.bash_profile" file.

```
echo ". /home/oracle/scripts/setEnv.sh" >> /home/oracle/.bash_profile
```



## Oracle 19c Software Installation 

**Oracle DB software**

Download from host to vm oracle Linux 8 using this way , you can do the same using FTP, SFTP or SCP: 

```bash
# windows or linux host using powershell or cmd 
# got to the location of zip file and run this below command:
$ python3 -m http.server 8888

# On Oracle linux 8 download 
$ wget http://{your_host_ip}:8888/{file_name}.zip
```

**ORACLE Linux xhost**

```bash
$ export DISPLAY=:0
$ xhost +x 

```

**Oracle bypass OS verification**

```bash
$ export CV_ASSUME_DISTID=OEL7.8
```









