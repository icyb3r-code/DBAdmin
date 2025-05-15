# ORACLE 12.1c Standalone to RAC Conversion 



## Introduction 



**Requirements**

1. Oracle Linux 8.1 

2. Oracle 19.3 Grid Infrastructure (GI)

3. Oracle 12.1 Oracle Database (DB)

4. VMware workstation  pro 16.1

5. Virtual Machine Resource Allocation:

   1. Node1
      1. 8 GB VM RAM
      2. 60 GB OS & DB VM Disks 
      3. 25 GB Grid VM Disks 
      4. 4 Cores
      5. 2 VNIC Private/Public
   2. Node2
      1. 8 GB VM RAM
      2. 45 GB VM Disk
      3. 4 Cores
      4. 2 VNIC Private/Public
3. Shared Disk (VSAN)
      1. 10, 25,15 GB ASM shared VM disks

**Steps**

1. Oracle Linux 8.3 installation.
2. Oracle 
3. DNS BIND installation and Configuration
4. 

## OS Installation

Follow the video on my youtube channel 



## Installation Prerequisites 

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
 # search for kmod 
 dnf search *oracleasm*

# install the oracle ASMlib, support, Kmod 
 dnf localinstall oracleasmlib-2.0.17-1.el8.x86_64 -y 
 dnf localinstall oracleasm-support-2.1.11-2.el7.x86_64 -y
 
# check if the packages installed or not 
dnf list installed | grep -i oracleasm
rpm -qa | grep -i oracleasm
oracleasm-support-2.1.11-2.el7.x86_64
oracleasmlib-2.0.17-1.el8.x86_64
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
 usermod -a -G asmadmin oracle
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
 echo 123qwe | passwd oracle --stdin
 passwd grid
```

Create the Directories for the Oracle Grid installation 

```bash
mkdir -p /u01/19c/oracle/ora_base
mkdir -p /u01/19c/oracle/db_home
mkdir -p /u01/19c/grid/grid_home
mkdir  -p /u01/19c/grid/grid_base
chown -R oracle:oinstall /u01
chown -R grid:oinstall /u01/19c/grid/
chmod -R 775 /u01

mkdir -p /u01/12r1c/oracle/db_home
mkdir -p /u01/12r1c/oracle/ora_base
chown -R oracle:oinstall /u01/12r1c/
chmod 775 /u01/12r1c/


```



```bash
mkdir -p /u01/12r1c/oracle/ora_base/db_home
chown -R oracle:oinstall /u01/12r1c/
chmod -R 775 /u01/12r1c
```

Create the Directories for the Oracle Database installation 

```bash
mkdir -p /u01/grid_base
chown -R grid:oinstall /u01/grid_base
mkdir -p /u01/19c/grid_home
chown -R grid:oinstall /u01/19c/
chmod -R 775 /u01
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

Switch to the `grid` user and edit the Grid `.bash_profile`, before edit the file I will take backup for it first

```bash
su - grid
cd /home/grid
cp .bash_profile .bash_profile.bkp
```



Copy and paste this to grid home directory 

```bash
# Node1 Copy this 
export ORA_SID=+ASM1

# Node2 Copy this 
export ORA_SID=+ASM2

cat > /home/grid/.grid_env <<EOF
host=\$(hostname -s)
if [ \$host == "rac1" ]; then 
    ORA_SID=+ASM1
elif [ \$host == "rac2" ]; then
    ORA_SID=+ASM2
else 
 echo "Host not meet the option $host"
fi
 
# User specific environment and startup programs

ORACLE_SID=\$ORA_SID; export ORACLE_SID
ORACLE_BASE=/u01/19c/grid/grid_base; export ORACLE_BASE
ORACLE_HOME=/u01/19c/grid/grid_home; export ORACLE_HOME
ORACLE_TERM=xterm; export ORACLE_TERM
JAVA_HOME=/usr/bin/java; export JAVA_HOME
TNS_ADMIN=\$ORACLE_HOME/network/admin; export TNS_ADMIN

PATH=.:\${JAVA_HOME}/bin:\${PATH}:\$HOME/bin:\$ORACLE_HOME/bin
PATH=\${PATH}:/usr/bin:/bin:/usr/local/bin
export PATH
umask 022
EOF
echo '. ~/.grid_env' >> /home/grid/.bash_profile
# apply below if you run the above script from root otherwise ignore it 
chown grid:oinstall /home/grid/.grid_env
```

apply the profile for the current session and check the environment variables using grid user :

```bash
source .bash_profile 
env | grep -i "tns\|oracle"
exit
```

Switch to `oracle` user and backup the `.bash_profile` :

```bash
su - oracle 
cp .bash_profile .bash_profile.bkp
```

create new bash profile file copy the below script to your terminal and press enter:

```bash
# Node1 Copy this 
export ORA_SID=PROD1

# Node2 Copy this 
export ORA_SID=PROD2

# then on both nodes copy this for 12c Env
cat > /home/oracle/.db12r1_env <<EOF
host=\$(hostname -s)
if [ \$host == "rac1" ]; then 
    ORA_SID=PROD1
elif [ \$host == "rac2" ]; then
    ORA_SID=PROD2
else 
 echo "Host not meet the option $host"
fi

ORACLE_HOSTNAME=\$HOSTNAME; export ORACLE_HOSTNAME
ORACLE_SID=\$ORA_SID; export ORACLE_SID
ORACLE_UNQNAME=prod; export ORACLE_UNQNAME
ORACLE_BASE=/u01/12c/oracle/ora_base; export ORACLE_BASE
ORACLE_HOME=/u01/12c/oracle/ora_base/db_home; export ORACLE_HOME
ORACLE_TERM=xterm; export ORACLE_TERM

JAVA_HOME=/usr/bin/java; export JAVA_HOME
NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"; export NLS_DATE_FORMAT
TNS_ADMIN=\$ORACLE_HOME/network/admin; export TNS_ADMIN
PATH=.:\${JAVA_HOME}/bin:\${PATH}:\$HOME/bin:\$ORACLE_HOME/bin
PATH=\${PATH}:/usr/bin:/bin:/usr/local/bin
export PATH

LD_LIBRARY_PATH=\$ORACLE_HOME/lib
LD_LIBRARY_PATH=\${LD_LIBRARY_PATH}:\$ORACLE_HOME/oracm/lib
LD_LIBRARY_PATH=\${LD_LIBRARY_PATH}:/lib:/usr/lib:/usr/local/lib
export LD_LIBRARY_PATH

CLASSPATH=\$ORACLE_HOME/JRE:\$ORACLE_HOME/jlib:\$ORACLE_HOME/rdbms/jlib:\$ORACLE_HOME/network/jlib
export CLASSPATH

TEMP=/tmp ;export TMP
TMPDIR=\$tmp ; export TMPDIR
EOF

cat > /home/oracle/.db19_env <<EOF
host=\$(hostname -s)
if [ \$host == "rac1" ]; then 
    ORA_SID=PROD1
elif [ \$host == "rac2" ]; then
    ORA_SID=PROD2
else 
 echo "Host not meet the option $host"
fi

ORACLE_HOSTNAME=\$HOSTNAME; export ORACLE_HOSTNAME
ORACLE_SID=\$ORA_SID; export ORACLE_SID
ORACLE_UNQNAME=prod; export ORACLE_UNQNAME
ORACLE_BASE=/u01/19c/oracle/ora_base; export ORACLE_BASE
ORACLE_HOME=/u01/19c/oracle/ora_base/db_home; export ORACLE_HOME
ORACLE_TERM=xterm; export ORACLE_TERM

JAVA_HOME=/usr/bin/java; export JAVA_HOME
NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"; export NLS_DATE_FORMAT
TNS_ADMIN=\$ORACLE_HOME/network/admin; export TNS_ADMIN
PATH=.:\${JAVA_HOME}/bin:\${PATH}:\$HOME/bin:\$ORACLE_HOME/bin
PATH=\${PATH}:/usr/bin:/bin:/usr/local/bin
export PATH

LD_LIBRARY_PATH=\$ORACLE_HOME/lib
LD_LIBRARY_PATH=\${LD_LIBRARY_PATH}:\$ORACLE_HOME/oracm/lib
LD_LIBRARY_PATH=\${LD_LIBRARY_PATH}:/lib:/usr/lib:/usr/local/lib
export LD_LIBRARY_PATH

CLASSPATH=\$ORACLE_HOME/JRE:\$ORACLE_HOME/jlib:\$ORACLE_HOME/rdbms/jlib:\$ORACLE_HOME/network/jlib
export CLASSPATH

TEMP=/tmp ;export TMP
TMPDIR=\$tmp ; export TMPDIR
EOF

# add this to oracle bash profile 
cat  >> /home/oracle/.bash_profile <<EOF
alias db12r1_env='. ~/.db12r1_env'
alias db19_env='. ~/.db19_env'
EOF
# apply below if you run the above script from root otherwise ignore it   
chown oracle:oinstall /home/oracle/.bash_profile
chown oracle:oinstall /home/oracle/.db19_env
chown oracle:oinstall /home/oracle/.db12r1_env

```

apply the profile from oracle user 

```bash
source /home/oracle/.bash_profile
env | grep ORACLE
exit
```

stop below services 

```bash
systemctl stop tuned.service ktune.service
systemctl stop firewalld.service
systemctl stop postfix.service
systemctl stop avahi-daemon.socket
systemctl stop avahi-daemon.service
systemctl stop atd.service
systemctl stop bluetooth.service
systemctl stop wpa_supplicant.service
systemctl stop accounts-daemon.service
systemctl stop atd.service cups.service
systemctl stop postfix.service
systemctl stop ModemManager.service
systemctl stop debug-shell.service
systemctl stop rtkit-daemon.service
systemctl stop rpcbind.service
systemctl stop rngd.service
systemctl stop upower.service
systemctl stop rhsmcertd.service
systemctl stop rtkit-daemon.service
systemctl stop ModemManager.service
systemctl stop mcelog.service
systemctl stop colord.service
systemctl stop libstoragemgmt.service
systemctl stop ksmtuned.service
systemctl stop brltty.service
systemctl stop avahi-dnsconfd.service

systemctl disable tuned.service ktune.service
systemctl disable firewalld.service
systemctl disable postfix.service
systemctl disable avahi-daemon.socket
systemctl disable avahi-daemon.service
systemctl disable atd.service
systemctl disable bluetooth.service
systemctl disable wpa_supplicant.service
systemctl disable accounts-daemon.service
systemctl disable atd.service cups.service
systemctl disable postfix.service
systemctl disable ModemManager.service
systemctl disable debug-shell.service
systemctl disable rtkit-daemon.service
systemctl disable rpcbind.service
systemctl disable rngd.service
systemctl disable upower.service
systemctl disable rhsmcertd.service
systemctl disable rtkit-daemon.service
systemctl disable ModemManager.service
systemctl disable mcelog.service
systemctl disable colord.service
systemctl disable libstoragemgmt.service
systemctl disable ksmtuned.service
systemctl disable brltty.service
systemctl disable avahi-dnsconfd.service
```





## ASM Disk configuration

Create VMware disk for enable the UUID for vmware check the [link](https://blog.purestorage.com/purely-technical/enabling-scsi_id-on-vmware/)

```bash
# create disk using command line 
vmware-vdiskmanager -c -s 30GB -a lsilogic -t 4 ASM_DISK_01.vmdk

# create change this disk to be independent and presistence on both vms 

# edit .vmx file by adding below on both .vmx file check your disk scsi port 
disk.locking = "FALSE"
disk.EnableUUID = "TRUE"
scsi0:2.sharedBus = "VIRTUAL"

# run both machines
```



Configure the Oracle ASM using ASMLIB

```bash

# detect the Vmware disks without reboot the machine 
echo "- - -" >> /sys/class/scsi_host/host1/scan

# format the disks on both nodes
 export HDISK="/dev/sdb"
 echo -e "d\nn\n\n\n\n+5G\np\nn\np\n\n\n+15G\np\nn\np\n\n\n\n\np\nw" | fdisk $HDISK
 fdisk -l 

# configure oracleasm on both nodes
 echo -e "grid\ndba\ny\ny\n" | oracleasm configure -i
 oracleasm init 

# create ASM disks first node rac1
 oracleasm createdisk ASM_CRS1 /dev/sdb1 # (Cluster Ready Service) CRS Disk
 oracleasm createdisk ASM_DATA1 /dev/sdb2 # Data Disk 
 oracleasm createdisk ASM_FRA1 /dev/sdb3 # FRA Disk 

#list the disks 
 oracleasm listdisks
 ls -l /dev/oracleasm/disks/
 
 # second node 
 oracleasm scandisks 
 oracleasm listdisks
 ls -l /dev/oracleasm/disks/
```

Configure ASM using UDEV [ref1](https://dba010.com/2019/07/22/udev-rules-for-configuring-asm-disks/) [ref2](https://www.hhutzler.de/blog/configure-udev-rules-for-asm-devices/) [ref3](https://www.linuxsysadmins.com/creating-udev-asm-disks-using-udev-in-linux-servers/) [ref4](https://avdeo.com/2016/07/18/using-udev-to-configure-asm-disks/)     

```bash
# Remove oracle asm support package if installed 
yum remove oracleasm-support

[root@rac2 ~]# lsblk 
NAME        MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
sda           8:0    0  50G  0 disk 
├─sda1        8:1    0   1G  0 part /boot
└─sda2        8:2    0  49G  0 part 
  ├─ol-root 253:0    0  41G  0 lvm  /
  └─ol-swap 253:1    0   8G  0 lvm  [SWAP]
sdb           8:16   0  15G  0 disk 
└─sdb1        8:17   0  15G  0 part 
sdc           8:32   0  15G  0 disk 
sdd           8:48   0  15G  0 disk 
sde           8:64   0   2G  0 disk 

export HDISK="/dev/sdb"
echo -e "d\nn\n\n\n\n\np\nw" | fdisk $HDISK

export HDISK="/dev/sdc"
echo -e "d\nn\n\n\n\n\np\nw" | fdisk $HDISK

export HDISK="/dev/sdd"
echo -e "d\nn\n\n\n\n\np\nw" | fdisk $HDISK

export HDISK="/dev/sde"
echo -e "d\nn\n\n\n\n\np\nw" | fdisk $HDISK

[root@rac2 ~]# /usr/lib/udev/scsi_id -gud /dev/sdc1 
36000c2949af34b3ce69b5b7e9b7b75c8
[root@rac2 ~]# /usr/lib/udev/scsi_id -gud /dev/sdd1
36000c29831dead0544e1ad39565511dc
[root@rac2 ~]# /usr/lib/udev/scsi_id -gud /dev/sde1
36000c297733a5c5bada221af1a76f3ad

# Add the following to the "/etc/scsi_id.config" file to configure SCSI devices as trusted. Create the file if it doesn't already exist.
[root@rac1 ~]# cat /etc/scsi_id.config 
options=-g

[root@rac1 ~]# udevadm info --query=property --name /dev/sdc1

[root@rac1 ~]# gedit /etc/udev/rules.d/99-asm.rules 

KERNEL=="sd*1", SUBSYSTEM=="block", ENV{ID_SERIAL}=="36000c2949af34b3ce69b5b7e9b7b75c8", SYMLINK+="oracleasm/DAT_ASM_1", OWNER="grid", GROUP="asmadmin", MODE="0660"
KERNEL=="sd*1", SUBSYSTEM=="block", ENV{ID_SERIAL}=="36000c29831dead0544e1ad39565511dc", SYMLINK+="oracleasm/FRA_ASM_1", OWNER="grid", GROUP="asmadmin", MODE="0660
KERNEL=="sd*1", SUBSYSTEM=="block", ENV{ID_SERIAL}=="36000c297733a5c5bada221af1a76f3ad", SYMLINK+="oracleasm/CRS_ASM_1", OWNER="grid", GROUP="asmadmin", MODE="0660

fsck -N /dev/sd?1

# Load updated block device partition table
partx -u /dev/sdc1
partx -u /dev/sdd1
partx -u /dev/sde1

# test the rules are working as expected 
udevadm test /block/sdc/sdc1
udevadm test /block/sdd/sdd1
udevadm test /block/sde/sde1

# Reload the UDEV rules 
udevadm control --reload-rules && udevadm trigger --action=add


```





## DNS Installation & Configuration 

Make sure your server connected to internet then Install the bind package using `root` user or any `sudo` user:

```bash
10.10.20.111	rac1.racdomain.com	rac1 #DNS
10.10.20.112	rac2.racdomain.com	rac2 #DNS
10.10.30.111	rac1-priv.racdomain.com	rac1-priv
10.10.30.112	rac2-priv.racdomain.com	rac2-priv 
10.10.20.113	rac1-vip.racdomain.com	rac1-vip #DNS
10.10.20.114	rac2-vip.racdomain.com	rac2-vip #DNS
#10.10.20.115	rac-cluster-scan.racdomain.com	rac-cluster-scan #DNS
#10.10.20.116	rac-cluster-scan.racdomain.com	rac-cluster-scan #DNS
#10.10.20.117	rac-cluster-scan.racdomain.com	rac-cluster-scan #DNS


# DNS Server
dnf makecache

dnf install bind bind-utils -y

hostnamectl

systemctl stop named
systemctl disable named 

# backup the file 
cp /etc/named.conf /etc/named.conf.bkp

# I wrote a simple script to generate the named.conf based on your system 

# I wrote a simple script to generate  forward and backward zones 

# change the owner 
chown named:named /var/named/forward.racdomain.com
chown named:named /var/named/backward.racdomain.com

# check the configurations 
named-checkconf
named-checkzone racdomain.com /var/named/forward.racdomain.com
named-checkzone 10.10.20.111 /var/named/backward.racdomain.com

# edit system 
cat > /etc/resolv.conf <<EOF
search racdomain.com
nameserver 10.10.20.111
nameserver 10.10.20.112
nameserver 8.8.8.8
EOF

# edit the network profiles may different in your system
nano /etc/sysconfig/network-scripts/ifcfg-ens160
# add this line to this file 
DNS1=10.10.20.110

#  allow the dns traffic 

firewall-cmd  --add-service=dns --zone=public  --permanent
firewall-cmd --reload

##########################
######  DNS Client  ######
##########################

# edit system 
cat >> /etc/resolv.conf <<EOF
search racdomain
nameserver 10.10.20.111
EOF

# edit the network profiles may different in your system
nano /etc/sysconfig/network-scripts/ifcfg-ens160
# add this line to this file 
DNS1=10.10.20.111

# test from the client
nslookup rac1
nslookup rac2 

ping rac1
ping rac2


cat  > /var/named/forward.racdomain.com <<EOF
\$TTL 86400
@ IN SOA rac1.racdomain.com. admin.racdomain.com. (
                                                2021040300 ;Serial
                                                3600 ;Refresh
                                                1800 ;Retry
                                                604800 ;Expire
                                                86400 ;Minimum TTL
)

;Name Server Information
@ IN NS rac1.racdomain.com.
@ IN A  10.10.20.111
@ IN A  10.10.20.112
@ IN A  10.10.20.113
@ IN A  10.10.20.114
@ IN A  10.10.20.115
@ IN A  10.10.20.116
@ IN A  10.10.20.117

;IP Address for Name Server
rac1 IN A 10.10.20.111

;Mail Server MX (Mail exchanger) Record
;rac1.racdomain.com IN MX 10 mail.rac1.racdomain.com

;A Record for the following Host name
rac1  IN   A   10.10.20.111
rac2  IN   A   10.10.20.112
rac1-vip  IN  A  10.10.20.113
rac2-vip  IN  A  10.10.20.114
rac-cluster-scan  IN  A  10.10.20.115
rac-cluster-scan  IN  A  10.10.20.116
rac-cluster-scan  IN  A  10.10.20.117

;CNAME Record
;ftp  IN   CNAME ftp.rac1.racdomain.com.
EOF

cat > /var/named/backward.racdomain.com <<EOF
\$TTL 86400
@ IN SOA rac1.racdomain.com. admin.racdomain.com. (
                                            2021040300 ;Serial
                                            3600 ;Refresh
                                            1800 ;Retry
                                            604800 ;Expire
                                            86400 ;Minimum TTL
)
;Name Server Information
@ IN NS rac1.racdomain.com.
rac1     IN      A       10.10.20.111

;Reverse lookup for Name Server
35 IN PTR rac1.racdomain.com.

;PTR Record IP address to Hostname
111      IN      PTR     rac1.racdomain.com.
112      IN      PTR     rac2.racdomain.com.
113      IN      PTR     rac1-vip.racdomain.com
114      IN      PTR     rac2-vip.racdomain.com
115      IN      PTR     rac-cluster-scan.racdomain.com
116      IN      PTR     rac-cluster-scan.racdomain.com
117      IN      PTR     rac-cluster-scan.racdomain.com
EOF
```

script to generate the configuration files for the DNS server: 

```bash
export DNS_IP="10.10.20.111"
export DNS_DOMAIN="racdomain.com"
export DNS_NETWORK="10.10.20.0/24"
export DNS_BACKWARD="20.10.10.in-addr.arpa"
export DNS_FORWARD=$DNS_DOMAIN
export DNS_BACKWARD_FILE="backward.$DNS_DOMAIN"
export DNS_FORWARD_FILE="forward.$DNS_DOMAIN"
export DNS_HOSTNAME="rac1"
export DNS_FQDN=$DNS_HOSTNAME.$DNS_DOMAIN

cat > /etc/named.conf <<EOF
options {
	listen-on port 53 { 127.0.0.1; $DNS_IP; };
	listen-on-v6 port 53 { ::1; };
	directory 	"/var/named";
	dump-file 	"/var/named/data/cache_dump.db";
	statistics-file "/var/named/data/named_stats.txt";
	memstatistics-file "/var/named/data/named_mem_stats.txt";
	secroots-file	"/var/named/data/named.secroots";
	recursing-file	"/var/named/data/named.recursing";
	allow-query     { localhost; $DNS_NETWORK; };

	recursion yes;

	dnssec-enable yes;
	dnssec-validation yes;

	managed-keys-directory "/var/named/dynamic";

	pid-file "/run/named/named.pid";
	session-keyfile "/run/named/session.key";

	/* https://fedoraproject.org/wiki/Changes/CryptoPolicy */
	include "/etc/crypto-policies/back-ends/bind.config";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

zone "." IN {
	type hint;
	file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";

//forward zone
zone "$DNS_DOMAIN" IN {
     type master;
     file "$DNS_FORWARD_FILE";
     allow-update { none; };
     allow-query { any; };
};

//backward zone or reverse zone
zone "$DNS_BACKWARD" IN {
     type master;
     file "$DNS_BACKWARD_FILE";
     allow-update { none; };
     allow-query { any; };
};
EOF


#cat > ~/forward.racdomain <<EOF
cat > /var/named/forward.racdomain.com <<EOF
\$TTL 86400
@ IN SOA $DNS_FQDN. admin.$DNS_DOMAIN. (
                                                2021040300 ;Serial
                                                3600 ;Refresh
                                                1800 ;Retry
                                                604800 ;Expire
                                                86400 ;Minimum TTL
)

;Name Server Information
@ IN NS $DNS_FQDN.
@ IN A  10.10.20.111
@ IN A  10.10.20.112

;IP Address for Name Server
$DNS_HOSTNAME IN A 10.10.20.111

;Mail Server MX (Mail exchanger) Record
;rac1.racdomain.com IN MX 10 mail.rac1.racdomain.com

;A Record for the following Host name
$DNS_HOSTNAME  IN   A   $DNS_IP
rac2  IN   A   10.10.20.112


;CNAME Record
;ftp  IN   CNAME ftp.$DNS_FQDN.
EOF


# cat > ~/backward.racdomain <<EOF
cat > /var/named/backward.racdomain.com <<EOF
\$TTL 86400
@ IN SOA $DNS_FQDN. admin.$DNS_DOMAIN. (
                                            2021040300 ;Serial
                                            3600 ;Refresh
                                            1800 ;Retry
                                            604800 ;Expire
                                            86400 ;Minimum TTL
)
;Name Server Information
@ IN NS $DNS_FQDN.
$DNS_HOSTNAME     IN      A       $DNS_IP

;Reverse lookup for Name Server
35 IN PTR $DNS_FQDN.

;PTR Record IP address to Hostname
111      IN      PTR     $DNS_FQDN.
112      IN      PTR     rac2.racdomain.com.
EOF
```



## Grid Installation



```bash
#node1 and node2 
ssh-keygen -t rsa

# node2
ssh-copy-id grid@rac1.racdomain.com

# node1
ssh-copy-id grid@rac2.racdomain.com

# ssh oracle@node1 date
# ssh oracle@node2 date
# fix the error INS-06006
cp -p /usr/bin/scp /usr/bin/scp.bkp
echo "/usr/bin/scp.bkp -T \$*" > /usr/bin/scp

./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose

[grid@rac1 ~]$ export DISPLAY=:0.0
[grid@rac1 ~]$ xhost +

export CV_ASSUME_DISTID=OEL7.6

# Go to grid home and run below command 
./gridSetup.sh





# change the disk compatiblitiy 
# use grid env 
sqlplus / as sysasm
select NAME,STATE,COMPATIBILITY,DATABASE_COMPATIBILITY from v$asm_diskgroup;
alter diskgroup FRA set ATTRIBUTE 'compatible.rdbms' ='12.1.0.2.0';
alter diskgroup DATA set ATTRIBUTE 'compatible.rdbms' ='12.1.0.2.0';


```



## Install DB Software Only 



```bash
export CV_ASSUME_DISTID=OEL7.6

# Fix oracl 12c DB INS-06006
./sshUserSetup.sh -user oracle -hosts "rac1 rac2" -advanced -exverify -confirm -noPromptPassphrase

```







