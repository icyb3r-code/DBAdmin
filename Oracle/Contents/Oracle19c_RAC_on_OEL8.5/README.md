# Oracle 19c RAC

Hi everyone, I will start complete guide of  Oracle RAC 19c lab setup. I have listed all the main points that I will cover during my up coming videos on my youtube channel, so it can be easy for you to follow and understand each point, besides that those steps will save your time if you follow, so I put those point in a notepad as you can see here:

## TOC
- [Oracle 19c RAC](#oracle-19c-rac)
  * [Requirements](#requirements)
  * [Setup VM Network](#setup-vm-network)
    + [NAT](#nat)
    + [Hostonly](#hostonly)
  * [OS Installation](#os-installation)
    + [Network & Host](#network---host)
    + [Software Selection](#software-selection)
    + [Root Password](#root-password)
    + [User Creation](#user-creation)
    + [Begin Installation](#begin-installation)
    + [Post Installation](#post-installation)
  * [Format Oracle Binaries Disk](#format-oracle-binaries-disk)
    + [Create LVM](#create-lvm)
    + [Make Files system](#make-files-system)
    + [Add to fstab](#add-to-fstab)
  * [Setup Prerequisites](#setup-prerequisites)
    + [Prerequisites installation](#prerequisites-installation)
    + [Create Env Variables](#create-env-variables)
    + [Disable Unwanted Services](#disable-unwanted-services)
  * [Setup Cluster Network](#setup-cluster-network)
    + [Cluster Network](#cluster-network)
    + [Host file](#host-file)
  * [Setup DNS](#setup-dns)
    + [Install BIND9](#install-bind9)
    + [Configure BIND](#configure-bind)
    + [Forward Backward Zones](#forward-backward-zones)
    + [Test DNS Configuration](#test-dns-configuration)
    + [Use DNS](#use-dns)
  * [Clone VM](#clone-vm)
    + [Poweroff Node 1](#poweroff-node-1)
    + [Clone](#clone)
    + [Edit Network](#edit-network)
  * [ASM Shared Disks](#asm-shared-disks)
    + [Create VSAN Disk](#create-vsan-disk)
    + [Add Disk on Both Nodes](#add-disk-on-both-nodes)
  * [Format Disks](#format-disks)
  * [Setup GI + ASM AFD](#setup-gi---asm-afd)
    + [Upload files](#upload-files)
    + [Unzip files](#unzip-files)
    + [Prerequisites](#prerequisites)
    + [Installation](#installation)
    + [Check Cluster Status](#check-cluster-status)
  * [Database Installation](#database-installation)
    + [Install DB Software Only](#install-db-software-only)
    + [Create Data,FRA](#create-data-fra)
    + [Create DB](#create-db)
  * [Patch DB](#patch-db)
    + [Node 1](#node-1)
      - [Check](#check)
      - [Analyze](#analyze)
      - [Apply](#apply)
    + [Node 2](#node-2)
      - [Check](#check-1)
      - [Analyze](#analyze-1)
      - [Apply](#apply-1)
    + [Data Patch](#data-patch)
    + [Check Version](#check-version)
  * [Manage Cluster Services](#manage-cluster-services)


## Requirements 
1.  Oracle Linux 8.5
2.  Oracle 19.3 Grid Infrastructure (GI)
4.  Oracle 19.3 Oracle Database (DB)
5.  Oracle Grid & Database RU 19.15 (Relase Update) 
6.  VirtualBox
7.   VBox Network
	1. Host only subnet 10.10.30.0/24
	2. NAT subnet 10.10.20.0/24
8.  Virtual Machine Resource Allocation:
    1.  Node1
        1.  8 GB VM RAM
        2.  25 GB OS VM DISK
        3.  40 GB GRID & DB Binaries VM DISK
        4.  4 Cores
        5.  2 VNIC Private/Public
    2.  Node2
        1.  8 GB VM RAM
        2. 25 GB OS VM DISK
        3. 40 GB GRID & DB Binaries VM DISK
        3. 4 Cores
        4. 2 VNIC Private/Public
9. Shared Disk (VSAN)
	1. 40 GB ASM shared VM disks.
10. 2 NIC (Network Interface Card) , 4 NIC (Redundant) 
11. 2 Network Switches, 4 Switches (redundant) 
12. DNS server 

## Setup VM Network
### NAT 
Change NAT subnet to `10.10.20.0/24` DHCP as well

### Hostonly
Change HostOnly to `10.10.30.0/24` 

## OS Installation 

After download the Oracle 8u5, you can create a vm and select the iso as virutal CD/DVD then start the VM that you create and boot up the ISO media and follow the below steps:


![](attachments/Pasted%20image%2020220530103222.png)


Click Installation Destination:

![](attachments/Pasted%20image%2020220530103544.png)

![](attachments/Pasted%20image%2020220530103915.png)


![](attachments/Pasted%20image%2020220530103956.png)


![](attachments/Pasted%20image%2020220530104125.png)


![](attachments/Pasted%20image%2020220530104325.png)


![](attachments/Pasted%20image%2020220530104403.png)


![](attachments/Pasted%20image%2020220530104447.png)

![](attachments/Pasted%20image%2020220530104528.png)

### Network & Host

![](attachments/Pasted%20image%2020220530104625.png)

![](attachments/Pasted%20image%2020220601231409.png)


### Software Selection

![](attachments/Pasted%20image%2020220530105300.png)


1- Performance Tools
2- Legac Linux Compatibility 
3- Development Tools
4- Graphic Administration Tools 
5- System Tools



![](attachments/Pasted%20image%2020220530105230.png)


### Root Password 

![](attachments/Pasted%20image%2020220530105339.png)

![](attachments/Pasted%20image%2020220530105410.png)


### User Creation

![](attachments/Pasted%20image%2020220530105542.png)


![](attachments/Pasted%20image%2020220530105648.png)


### Begin Installation

![](attachments/Pasted%20image%2020220530105446.png)

![](attachments/Pasted%20image%2020220530105714.png)

![](attachments/Pasted%20image%2020220530130810.png)

![](attachments/Pasted%20image%2020220530150809.png)

![](attachments/Pasted%20image%2020220530150855.png)

![](attachments/Pasted%20image%2020220530151018.png)


### Post Installation

* Remove screen lock and sleep.
* Increase terminal font size.
* Auto connect network interfaces.
* Add static network IP.
* Install guest addition tools 
```bash
sudo dnf install kernel-uek-devel-$(uname -r) gcc binutils automake make perl bzip2 elfutils-libelf-devel

/run/media/admin/VBox_GAs_6.1.32/VBoxLinuxAdditions.run

```


## Format Oracle Binaries Disk
### Create LVM

list all the avilable disks on the OS:
```bash
[admin@rac1 ~]$ lsblk 
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda     259:0    0   25G  0 disk 
├─sda1 259:1    0  500M  0 part /boot
└─sda2 259:2    0 24.5G  0 part 
  ├─ol-root 252:0    0 16.5G  0 lvm  /
  └─ol-swap 252:1    0    8G  0 lvm  [SWAP]
sdb     259:3    0   40G  0 disk 
[admin@rac1 ~]$
```

formate the disk using below command:

```bash
[root@rac1 ~]# fdisk /dev/sdb

Welcome to fdisk (util-linux 2.32.1).
Changes will remain in memory only, until you decide to write them.
Be careful before using the write command.

Device does not contain a recognized partition table.
Created a new DOS disklabel with disk identifier 0xb21e6b55.

Command (m for help): n
Partition type
   p   primary (0 primary, 0 extended, 4 free)
   e   extended (container for logical partitions)
Select (default p): 

Using default response p.
Partition number (1-4, default 1): 
First sector (2048-83886079, default 2048): 
Last sector, +sectors or +size{K,M,G,T,P} (2048-83886079, default 83886079): 

Created a new partition 1 of type 'Linux' and of size 40 GiB.

Command (m for help): p

Disk /dev/sdb: 40 GiB, 42949672960 bytes, 83886080 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0xb21e6b55

Device     Boot Start      End  Sectors Size Id Type
/dev/sdb1        2048 83886079 83884032  40G 83 Linux

Command (m for help): t
Selected partition 1
Hex code (type L to list all codes): 8e
Changed type of partition 'Linux' to 'Linux LVM'.

Command (m for help): p
Disk /dev/sdb: 40 GiB, 42949672960 bytes, 83886080 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0xb21e6b55

Device     Boot Start      End  Sectors Size Id Type
/dev/sdb1        2048 83886079 83884032  40G 8e Linux LVM

Command (m for help): w
The partition table has been altered.
Calling ioctl() to re-read partition table.
Syncing disks.

[root@rac1 ~]#
```

Create PV 
```bash
[root@rac1 ~]# pvcreate /dev/sdb1 
  Physical volume "/dev/sdb1" successfully created.
[root@rac1 ~]# pvs 
  PV             VG Fmt  Attr PSize   PFree  
  /dev/sda2 ol lvm2 a--  <24.51g      0 
  /dev/sdb1    lvm2 ---  <40.00g <40.00g
[root@rac1 ~]#
```

Create VG

```bash
[root@rac1 ~]# vgcreate db /dev/sdb1 
  Volume group "db" successfully created
[root@rac1 ~]# vgs
  VG #PV #LV #SN Attr   VSize   VFree  
  db   1   0   0 wz--n- <40.00g <40.00g
  ol   1   2   0 wz--n- <24.51g      0 
[root@rac1 ~]# 
```

Create LV 

```bash
[root@rac1 ~]# lvcreate db -n u01 -l 100%FREE
  Logical volume "u01" created.
[root@rac1 ~]# lvs 
  LV   VG Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  u01  db -wi-a----- <40.00g                                                    
  root ol -wi-ao---- <16.51g                                                    
  swap ol -wi-ao----   8.00g                                                    
[root@rac1 ~]# 
```

### Make Files system

```bash

[root@rac1 ~]# mkfs -t xfs /dev/mapper/db-u01 
meta-data=/dev/mapper/db-u01     isize=512    agcount=4, agsize=2621184 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=0
         =                       reflink=1
data     =                       bsize=4096   blocks=10484736, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1
log      =internal log           bsize=4096   blocks=5119, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0

[root@rac1 ~]# fsck -N /dev/db/u01 
fsck from util-linux 2.32.1
[/usr/sbin/fsck.xfs (1) -- /u01] fsck.xfs /dev/mapper/db-u01 
[root@rac1 ~]# 
```

### Add to fstab

```
vim /etc/fstab
/dev/db/u01	/u01	xfs	defaults	0	0

```

Mount the u01

```bash
[root@rac1 ~]# umount /u01
```

Check the list of disks 

```bash
[root@rac1 ~]# lsblk 
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda     259:0    0   25G  0 disk 
├─sda1 259:1    0  500M  0 part /boot
└─sda2 259:2    0 24.5G  0 part 
  ├─ol-root 252:0    0 16.5G  0 lvm  /
  └─ol-swap 252:1    0    8G  0 lvm  [SWAP]
sdb     259:3    0   40G  0 disk 
└─sdb1 259:4    0   40G  0 part 
  └─db-u01  252:2    0   40G  0 lvm  /u01
[root@rac1 ~]#
```

Reboot to check if everything is ok

```bash
reboot
```


## Setup Prerequisites

### Prerequisites installation
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
# Search for preinstall package
dnf search preinstall-19c

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
# add asmdba group to oracle user asmadmin
 usermod -a -G  asmdba oracle
 id oracle 
```

Create Grid user:

```bash
# create grid user 
 useradd -u 54331 -g oinstall -G dba,asmdba,asmadmin,asmoper,racdba grid
id grid 
```

Change the password for Oracle and Grid user:

```bash
# create grid oracle user passwords 
 passwd oracle
 echo password | passwd oracle --stdin
 echo password | passwd grid --stdin
 passwd grid
```

Create the Directories for the Oracle Grid installation 

```bash
mkdir -p /u01/19c/oracle/ora_base/db_home
mkdir -p /u01/19c/grid/grid_home
mkdir  -p /u01/19c/grid/grid_base
chown -R oracle:oinstall /u01
chown -R grid:oinstall /u01/19c/grid/
chmod -R 775 /u01

```


Check the NTP service 

```bash
# chrony both servers
vim /etc/chrony.conf

server 0.jp.pool.ntp.org iburst
server 1.jp.pool.ntp.org iburst
server 2.jp.pool.ntp.org iburst
server 3.jp.pool.ntp.org iburst

systemctl restart chronyd

chronyc sources


systemctl status chronyd

```

set secure linux to permissive 

```bash
# change SELINUX=enforcing to SELINUX=permissive
sed -i s/SELINUX=enforcing/SELINUX=permissive/g /etc/selinux/config
# Or Disabled it 
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


### Create Env Variables
Switch to the `grid` user and edit the Grid `.bash_profile`, before edit the file I will take backup for it first

```bash
su - grid
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

# Create oracle db 19c env profile
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
source ~/.db19_env
alias db19_env='. ~/.db19_env'
EOF
# apply below if you run the above script from root otherwise ignore it   
chown oracle:oinstall /home/oracle/.bash_profile
chown oracle:oinstall /home/oracle/.db19_env
```

apply the profile from oracle user 

```bash
source /home/oracle/.bash_profile
env | grep ORACLE_
exit
```


### Disable Unwanted Services
stop below services Need **ROOT**  Privilege:

```bash
systemctl stop tuned.service ktune.service
systemctl stop firewalld.service
systemctl stop postfix.service
systemctl stop avahi-daemon.service
systemctl stop avahi-daemon.socket

systemctl stop atd.service
systemctl stop bluetooth.service
systemctl stop wpa_supplicant.service
systemctl stop accounts-daemon.service
systemctl stop ModemManager.service
systemctl stop debug-shell.service
systemctl stop rtkit-daemon.service
systemctl stop rpcbind.service
systemctl stop rpcbind.socket
systemctl stop rngd.service
systemctl stop upower.service
systemctl stop rhsmcertd.service
systemctl stop colord.service
systemctl stop libstoragemgmt.service
systemctl stop ksmtuned.service
systemctl stop brltty.service


systemctl disable tuned.service ktune.service
systemctl disable firewalld.service
systemctl disable postfix.service
systemctl disable avahi-daemon.socket
systemctl disable avahi-daemon.service
systemctl disable bluetooth.service
systemctl disable wpa_supplicant.service
systemctl disable accounts-daemon.service
systemctl disable atd.service cups.service
systemctl disable ModemManager.service
systemctl disable debug-shell.service
systemctl disable rpcbind.service
systemctl disable rpcbind.socket
systemctl disable rngd.service
systemctl disable upower.service
systemctl disable rhsmcertd.service
systemctl disable rtkit-daemon.service
systemctl disable mcelog.service
systemctl disable colord.service
systemctl disable libstoragemgmt.service
systemctl disable ksmtuned.service
systemctl disable brltty.service

```


## Setup Cluster Network


To setup 2 Nodes Oracle RAC network we need 9 IPs 7 on public network and two IPs on private network for cluster interconnect communications. 

### Cluster Network 

The Current Lab network setup will be simple as shown below

![](attachments/Pasted%20image%2020220602231907.png)


 For maximum HA and the Best Practice to have redundant network setup, you need  4 NIC 4 Switches
  
![](attachments/Pasted%20image%2020220602231751.png)

### Host file 
add below to host file `/etc/hosts`
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

```


## Setup DNS
On first node you can configure DNS but the best practice to have DNS server out of RAC nodes:

### Install BIND9

```bash

# DNS Server
dnf makecache

dnf install bind bind-utils -y

hostnamectl
```

### Configure BIND

```bash
systemctl stop named
systemctl disable named 

# backup the file 
cp /etc/named.conf /etc/named.conf.bkp

# I wrote a simple script to generate the named.conf based on your system


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


```

### Forward Backward Zones

```bash
# I wrote a simple script to generate  forward and backward zones 


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



# change the owner 
chown named:named /var/named/forward.racdomain.com
chown named:named /var/named/backward.racdomain.com
```


### Test DNS Configuration
```bash
# check the configurations 
named-checkconf
named-checkzone racdomain.com /var/named/forward.racdomain.com
named-checkzone 10.10.20.111 /var/named/backward.racdomain.com
systemctl start named
systemctl enable named
```

### Use DNS 

```bash

################################
######  DNS Client Node 1 ######
################################

# edit resolv.conf
cat > /etc/resolv.conf <<EOF
search racdomain.com
nameserver 10.10.20.111
EOF

# edit the network profiles may different in your system
nano /etc/sysconfig/network-scripts/ifcfg-enp0s3
# add this line to this file 
DNS1=10.10.20.111

#  allow the dns traffic 

firewall-cmd  --add-service=dns --zone=public  --permanent
firewall-cmd --reload

################################
######  DNS Client Node 2 ######
################################

# edit system 
cat > /etc/resolv.conf <<EOF
search racdomain.com
nameserver 10.10.20.111
EOF

# edit the network profiles may different in your system
nano /etc/sysconfig/network-scripts/ifcfg-enp0s3
# add this line to this file 
DNS1=10.10.20.111

# test from the client
nslookup rac1
nslookup rac2 

ping rac1
ping rac2

```


## Clone VM
### Poweroff Node 1

Poweroff the Oracle linux VM
```bash
poweroff
```


### Clone

Select first node VM from Main menu  and right click mouse select `Clone`  then follow below screenshots:

press the expirt mode below windows will show up.

![](attachments/Pasted%20image%2020220605211253.png)

after finish click clone

![](attachments/Pasted%20image%2020220605211333.png)

once clone finished you can see the cloned VM listed as below screen shot
![](attachments/Pasted%20image%2020220605211356.png)



### Edit Network
Startup the Second node and change the following:
* Change the IP for both Public and Private network.
* change the hostname as below 
```bash
	[root@rac1 ~]# hostnamectl set-hostname rac2.racdomain.com
[root@rac1 ~]# hostnamectl 
   Static hostname: rac2.racdomain.com
         Icon name: computer-vm
           Chassis: vm
        Machine ID: f0e024b338264ff68fec7de92dd97d63
           Boot ID: 3f0decbb597c45a69d602f14f3e5c641
    Virtualization: vmware
  Operating System: Oracle Linux Server 8.5
       CPE OS Name: cpe:/o:oracle:linux:8:5:server
            Kernel: Linux 5.4.17-2136.300.7.el8uek.x86_64
      Architecture: x86-64
[root@rac1 ~]#
```
* Stop DNS service called `named.service`
```bash
	systemctl stop named.service
	systemctl disable named.service
``` 
shutdown the second node (RAC2)

```bash
poweroff
```

## ASM Shared Disks 
### Create VSAN Disk
Go to Oracle VM VirtualBox Manager click `ctrl + D` Virtual Media Manager will Pop up create 3 virtual hard dirve with fix size select the size as following
* 5 G for CRS
* 15G for FRA
*  20G for DATA

![](attachments/Pasted%20image%2020220605221649.png)


![](attachments/Pasted%20image%2020220605221411.png)

![](attachments/Pasted%20image%2020220605221551.png)

Repeate above operation for the other two disks 

![](attachments/Pasted%20image%2020220605221148.png)



### Add Disk on Both Nodes

Node 1

![](attachments/Pasted%20image%2020220605222728.png)

Node 2 

![](attachments/Pasted%20image%2020220605222658.png)


## Format Disks 

Start First Node and using fdisk to format the three disks 
```bash
fdisk /dev/sdc
fdisk /dev/sdd
fdisk /dev/sde
```

```bash
[root@rac1 ~]# lsblk 
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda           8:0    0   25G  0 disk 
├─sda1        8:1    0  500M  0 part /boot
└─sda2        8:2    0 24.5G  0 part 
  ├─ol-root 252:0    0 16.3G  0 lvm  /
  └─ol-swap 252:1    0  8.2G  0 lvm  [SWAP]
sdb           8:16   0   40G  0 disk 
└─sdb1        8:17   0   40G  0 part 
  └─db-u01  252:2    0   40G  0 lvm  /u01
sdc           8:32   0    5G  0 disk 
└─sdc1        8:33   0    5G  0 part 
sdd           8:48   0   20G  0 disk 
└─sdd1        8:49   0   20G  0 part 
sde           8:64   0   15G  0 disk 
└─sde1        8:65   0   15G  0 part 

```

then startup the second node the shared disks should be formated there:
```bash
[root@rac2 ~]# lsblk 
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda           8:0    0   25G  0 disk 
├─sda1        8:1    0  500M  0 part /boot
└─sda2        8:2    0 24.5G  0 part 
  ├─ol-root 252:0    0 16.3G  0 lvm  /
  └─ol-swap 252:1    0  8.2G  0 lvm  [SWAP]
sdb           8:16   0   40G  0 disk 
└─sdb1        8:17   0   40G  0 part 
  └─db-u01  252:2    0   40G  0 lvm  /u01
sdc           8:32   0    5G  0 disk 
└─sdc1        8:33   0    5G  0 part 
sdd           8:48   0   20G  0 disk 
└─sdd1        8:49   0   20G  0 part 
sde           8:64   0   15G  0 disk 
└─sde1        8:65   0   15G  0 part 

```

## Setup GI + ASM AFD

For the ASM disk setup will use ASM Filter Driver to configure the disk and managed them.

### Upload files 

Using NAT port forwarding i can upload the files to first node, to setup port forwarding, go to File -> Preferences -> Network -> Edit Nat Adapter -> Port Forwarding: 

![](attachments/Pasted%20image%2020220605230147.png)

or add both nodes if you want to access both of them using putty or ssh client 

![](attachments/Pasted%20image%2020220625140324.png)

Then Click Ok,check if the ports (2122,2222) are listening on localhost using below command:

```bash 
ss -alnt | grep "2*22" # for linux 
netstat -ano | findstr "2*22" # for windows 
```

If the ports are not show up, then you may need to poweroff your VMS. and restart virtualbox service, to do so:

```bash
sudo systemctl restart virtualbox # for linux 
# run services.msc then search for vbox service and restart it
```

PowerOn the VM first node then run below command from your host machine 

```bash 
ss -alnt | grep "2*22" # for linux 
netstat -ano | findstr "2*22" # for windows 
```

Upload the Oracle binaries to Node 1:

```bash
scp -P 2122 LINUX.X64_193000_db_home.zip LINUX.X64_193000_grid_home.zip p33803476_190000_Linux-x86-64.zip p6880880_210000_Linux-x86-64.zip  grid@127.0.0.1:/u01
```

### Unzip files 

```bash

unzip /u01/LINUX.X64_193000_grid_home.zip -d $ORACLE_HOME

mv $ORACLE_HOME/OPatch/ $ORACLE_HOME/OPatch_BKP

unzip /u01/p6880880_210000_Linux-x86-64.zip -d $ORACLE_HOME

unzip p33803476_190000_Linux-x86-64.zip -d /u01

```

### Prerequisites 


```bash
#node1 and node2 
ssh-keygen -t rsa

# node2
ssh-copy-id grid@rac1.racdomain.com

# node1
ssh-copy-id grid@rac2.racdomain.com

# ssh grid@rac1 date
# ssh grid@rac2 date

# fix the error INS-06006
cp -p /usr/bin/scp /usr/bin/scp.bkp
echo "/usr/bin/scp.bkp -T \$*" > /usr/bin/scp


$ORACLE_HOME/runcluvfy.sh stage -pre crsinst -n rac1,rac2 -networks enp0s3:10.10.20.0:PUBLIC/enp0s8:10.10.30.0:cluster_interconnect -method root -verbose 




```

### Installation

```bash
[grid@rac1 ~]$ export DISPLAY=:0.0
[grid@rac1 ~]$ xhost +

export CV_ASSUME_DISTID=OEL7.9

# Go to grid home and run below command 
./gridSetup.sh -applyPSU /u01/33803476/

```

Before proceed to installation, keep installer running, then proceed to create CRS votting disk for cluster, for more details check out this [link](https://docs.oracle.com/en/database/oracle/oracle-database/21/ladbi/configuring-asmfd-during-install.html#GUID-A82EE293-226B-431D-9888-4F957AE19234)

```bash

[root@rac1 ~]# source /home/grid/.grid_env
[root@rac1 ~]# export ORACLE_BASE=/tmp
[root@rac1 ~]# asmcmd afd_label CRS1 /dev/sdc1 --init
[root@rac1 ~]# asmcmd afd_lslbl /dev/sdc1
# if you want to remove the label and you see that you create it by mistake with different disk use below command
[root@rac1 ~]#asmcmd afd_unlabel /dev/sdc1 --init

------------------------------------------------------------
Label                     Duplicate  Path
============================================================
CRS1                                  /dev/sdc1
[root@rac1 ~]#
[root@rac1 ~]# unset ORACLE_BASE
```

Now We can Proceed with the installation using GUI

![](attachments/Pasted%20image%2020220606101502.png)


![](attachments/Pasted%20image%2020220606101542.png)

![](attachments/Pasted%20image%2020220606101630.png)

![](attachments/Pasted%20image%2020220606101828.png)

![](attachments/Pasted%20image%2020220606101919.png)

![](attachments/Pasted%20image%2020220606102003.png)

![](attachments/Pasted%20image%2020220606102035.png)

![](attachments/Pasted%20image%2020220606102143.png)

![](attachments/Pasted%20image%2020220606102226.png)

![](attachments/Pasted%20image%2020220606102257.png)


![](attachments/Pasted%20image%2020220606102317.png)

![](attachments/Pasted%20image%2020220606102344.png)

![](attachments/Pasted%20image%2020220606102414.png)

![](attachments/Pasted%20image%2020220606102447.png)

![](attachments/Pasted%20image%2020220606102519.png)

![](attachments/Pasted%20image%2020220606105107.png)

![](attachments/Pasted%20image%2020220606105143.png)

![](attachments/Pasted%20image%2020220606105230.png)

Two scripts should be run as root on both nodes 

![](attachments/Pasted%20image%2020220606113032.png)




Node 1:

```bash

# Script 1

[root@rac1 ~]# /u01/19c/grid/oraInventory/orainstRoot.sh
Changing permissions of /u01/19c/grid/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/19c/grid/oraInventory to oinstall.
The execution of the script is complete.

# Script 2

[root@rac1 ~]# /u01/19c/grid/grid_home/root.sh
Performing root user operation.

The following environment variables are set as:
    ORACLE_OWNER= grid
    ORACLE_HOME=  /u01/19c/grid/grid_home

Enter the full pathname of the local bin directory: [/usr/local/bin]: 
   Copying dbhome to /usr/local/bin ...
   Copying oraenv to /usr/local/bin ...
   Copying coraenv to /usr/local/bin ...


Creating /etc/oratab file...
Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
Relinking oracle with rac_on option
Using configuration parameter file: /u01/19c/grid/grid_home/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/19c/grid/grid_base/crsdata/rac1/crsconfig/rootcrs_rac1_2022-06-06_10-57-45AM.log
2022/06/06 10:58:02 CLSRSC-594: Executing installation step 1 of 19: 'SetupTFA'.
2022/06/06 10:58:02 CLSRSC-594: Executing installation step 2 of 19: 'ValidateEnv'.
2022/06/06 10:58:02 CLSRSC-594: Executing installation step 3 of 19: 'CheckFirstNode'.
2022/06/06 10:58:04 CLSRSC-594: Executing installation step 4 of 19: 'GenSiteGUIDs'.
2022/06/06 10:58:05 CLSRSC-594: Executing installation step 5 of 19: 'SetupOSD'.
Redirecting to /bin/systemctl restart rsyslog.service
2022/06/06 10:58:06 CLSRSC-594: Executing installation step 6 of 19: 'CheckCRSConfig'.
2022/06/06 10:58:09 CLSRSC-594: Executing installation step 7 of 19: 'SetupLocalGPNP'.
2022/06/06 10:58:20 CLSRSC-594: Executing installation step 8 of 19: 'CreateRootCert'.
2022/06/06 10:58:24 CLSRSC-594: Executing installation step 9 of 19: 'ConfigOLR'.
2022/06/06 10:58:41 CLSRSC-594: Executing installation step 10 of 19: 'ConfigCHMOS'.
2022/06/06 10:58:41 CLSRSC-594: Executing installation step 11 of 19: 'CreateOHASD'.
2022/06/06 10:58:46 CLSRSC-594: Executing installation step 12 of 19: 'ConfigOHASD'.
2022/06/06 10:58:51 CLSRSC-330: Adding Clusterware entries to file 'oracle-ohasd.service'
2022/06/06 10:59:16 CLSRSC-594: Executing installation step 13 of 19: 'InstallAFD'.
2022/06/06 10:59:53 CLSRSC-4002: Successfully installed Oracle Trace File Analyzer (TFA) Collector.
2022/06/06 10:59:56 CLSRSC-594: Executing installation step 14 of 19: 'InstallACFS'.
2022/06/06 11:00:20 CLSRSC-594: Executing installation step 15 of 19: 'InstallKA'.
2022/06/06 11:00:26 CLSRSC-594: Executing installation step 16 of 19: 'InitConfig'.

[INFO] [DBT-30161] Disk label(s) created successfully. Check /u01/19c/grid/grid_base/cfgtoollogs/asmca/asmca-220606AM110058.log for details.


2022/06/06 11:02:11 CLSRSC-482: Running command: '/u01/19c/grid/grid_home/bin/ocrconfig -upgrade grid oinstall'
CRS-4256: Updating the profile
Successful addition of voting disk b064bcb91a2e4f58bfa5b9daa9cb1cc6.
Successfully replaced voting disk group with +CRS.
CRS-4256: Updating the profile
CRS-4266: Voting file(s) successfully replaced
##  STATE    File Universal Id                File Name Disk group
--  -----    -----------------                --------- ---------
 1. ONLINE   b064bcb91a2e4f58bfa5b9daa9cb1cc6 (AFD:CRS1) [CRS]
Located 1 voting disk(s).
2022/06/06 11:03:17 CLSRSC-594: Executing installation step 17 of 19: 'StartCluster'.
2022/06/06 11:04:26 CLSRSC-343: Successfully started Oracle Clusterware stack
2022/06/06 11:04:26 CLSRSC-594: Executing installation step 18 of 19: 'ConfigNode'.
2022/06/06 11:05:45 CLSRSC-594: Executing installation step 19 of 19: 'PostConfig'.
2022/06/06 11:06:09 CLSRSC-325: Configure Oracle Grid Infrastructure for a Cluster ... succeeded
[root@rac1 ~]# 

```

Node 2:

```bash

[root@rac2 grid_home]# /u01/19c/grid/oraInventory/orainstRoot.sh
Changing permissions of /u01/19c/grid/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/19c/grid/oraInventory to oinstall.
The execution of the script is complete.

[root@rac2 grid_home]# /u01/19c/grid/grid_home/root.sh
Performing root user operation.

The following environment variables are set as:
    ORACLE_OWNER= grid
    ORACLE_HOME=  /u01/19c/grid/grid_home

Enter the full pathname of the local bin directory: [/usr/local/bin]: 
   Copying dbhome to /usr/local/bin ...
   Copying oraenv to /usr/local/bin ...
   Copying coraenv to /usr/local/bin ...


Creating /etc/oratab file...
Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
Relinking oracle with rac_on option
Using configuration parameter file: /u01/19c/grid/grid_home/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/19c/grid/grid_base/crsdata/rac2/crsconfig/rootcrs_rac2_2022-06-06_11-26-28AM.log
2022/06/06 11:26:34 CLSRSC-594: Executing installation step 1 of 19: 'SetupTFA'.
2022/06/06 11:26:34 CLSRSC-594: Executing installation step 2 of 19: 'ValidateEnv'.
2022/06/06 11:26:34 CLSRSC-594: Executing installation step 3 of 19: 'CheckFirstNode'.
2022/06/06 11:26:35 CLSRSC-594: Executing installation step 4 of 19: 'GenSiteGUIDs'.
2022/06/06 11:26:36 CLSRSC-594: Executing installation step 5 of 19: 'SetupOSD'.
Redirecting to /bin/systemctl restart rsyslog.service
2022/06/06 11:26:36 CLSRSC-594: Executing installation step 6 of 19: 'CheckCRSConfig'.
2022/06/06 11:26:37 CLSRSC-594: Executing installation step 7 of 19: 'SetupLocalGPNP'.
2022/06/06 11:26:39 CLSRSC-594: Executing installation step 8 of 19: 'CreateRootCert'.
2022/06/06 11:26:39 CLSRSC-594: Executing installation step 9 of 19: 'ConfigOLR'.
2022/06/06 11:26:51 CLSRSC-594: Executing installation step 10 of 19: 'ConfigCHMOS'.
2022/06/06 11:26:51 CLSRSC-594: Executing installation step 11 of 19: 'CreateOHASD'.
2022/06/06 11:26:53 CLSRSC-594: Executing installation step 12 of 19: 'ConfigOHASD'.
2022/06/06 11:27:00 CLSRSC-330: Adding Clusterware entries to file 'oracle-ohasd.service'
2022/06/06 11:27:20 CLSRSC-594: Executing installation step 13 of 19: 'InstallAFD'.
2022/06/06 11:27:41 CLSRSC-594: Executing installation step 14 of 19: 'InstallACFS'.
2022/06/06 11:28:06 CLSRSC-594: Executing installation step 15 of 19: 'InstallKA'.
2022/06/06 11:28:07 CLSRSC-594: Executing installation step 16 of 19: 'InitConfig'.
2022/06/06 11:28:18 CLSRSC-594: Executing installation step 17 of 19: 'StartCluster'.
2022/06/06 11:28:39 CLSRSC-4002: Successfully installed Oracle Trace File Analyzer (TFA) Collector.
2022/06/06 11:29:05 CLSRSC-343: Successfully started Oracle Clusterware stack
2022/06/06 11:29:05 CLSRSC-594: Executing installation step 18 of 19: 'ConfigNode'.
2022/06/06 11:29:17 CLSRSC-594: Executing installation step 19 of 19: 'PostConfig'.
2022/06/06 11:29:28 CLSRSC-325: Configure Oracle Grid Infrastructure for a Cluster ... succeeded

```

Click Ok to continue the installation

![](attachments/Pasted%20image%2020220606113722.png)

![](attachments/Pasted%20image%2020220606113817.png)

![](attachments/Pasted%20image%2020220606113959.png)

### Check Cluster Status 

```bash
[root@rac1 ~]# crsctl stat res -t 
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details       
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       rac1                     STABLE
               ONLINE  ONLINE       rac2                     STABLE
ora.chad
               ONLINE  ONLINE       rac1                     STABLE
               ONLINE  ONLINE       rac2                     STABLE
ora.net1.network
               ONLINE  ONLINE       rac1                     STABLE
               ONLINE  ONLINE       rac2                     STABLE
ora.ons
               ONLINE  ONLINE       rac1                     STABLE
               ONLINE  ONLINE       rac2                     STABLE
ora.proxy_advm
               OFFLINE OFFLINE      rac1                     STABLE
               OFFLINE OFFLINE      rac2                     STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.ASMNET1LSNR_ASM.lsnr(ora.asmgroup)
      1        ONLINE  ONLINE       rac1                     STABLE
      2        ONLINE  ONLINE       rac2                     STABLE
ora.CRS.dg(ora.asmgroup)
      1        ONLINE  ONLINE       rac1                     STABLE
      2        ONLINE  ONLINE       rac2                     STABLE
ora.LISTENER_SCAN1.lsnr
      1        ONLINE  ONLINE       rac2                     STABLE
ora.LISTENER_SCAN2.lsnr
      1        ONLINE  ONLINE       rac1                     STABLE
ora.LISTENER_SCAN3.lsnr
      1        ONLINE  ONLINE       rac1                     STABLE
ora.asm(ora.asmgroup)
      1        ONLINE  ONLINE       rac1                     Started,STABLE
      2        ONLINE  ONLINE       rac2                     Started,STABLE
ora.asmnet1.asmnetwork(ora.asmgroup)
      1        ONLINE  ONLINE       rac1                     STABLE
      2        ONLINE  ONLINE       rac2                     STABLE
ora.cvu
      1        ONLINE  ONLINE       rac1                     STABLE
ora.qosmserver
      1        ONLINE  ONLINE       rac1                     STABLE
ora.rac1.vip
      1        ONLINE  ONLINE       rac1                     STABLE
ora.rac2.vip
      1        ONLINE  ONLINE       rac2                     STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       rac2                     STABLE
ora.scan2.vip
      1        ONLINE  ONLINE       rac1                     STABLE
ora.scan3.vip
      1        ONLINE  ONLINE       rac1                     STABLE
--------------------------------------------------------------------------------
[root@rac1 ~]#

```

## Database Installation

### Install DB Software Only 

```bash

[oracle@rac1 ~]$ cd $ORACLE_HOME

[oracle@rac1 db_home]$ unzip /tmp/LINUX.X64_193000_db_home.zip -d $ORACLE_HOME 

[oracle@rac1 db_home]$ $ORACLE_HOME/OPatch/opatch version

[oracle@rac1 db_home]$ mv OPatch/ OPatch_bkp

[oracle@rac1 db_home]$ unzip /u01/p6880880_210000_Linux-x86-64.zip -d $ORACLE_HOME

[oracle@rac1 db_home]$ $ORACLE_HOME/OPatch/opatch version


export CV_ASSUME_DISTID=OEL7.9

# Fix oracl 12c DB INS-06006
$ORACLE_HOME/deinstall/sshUserSetup.sh -user oracle -hosts "rac1 rac2" -advanced -exverify -confirm -noPromptPassphrase

[oracle@rac1 db_home]$ ./runInstaller

```


![](attachments/Pasted%20image%2020220606124347.png)

![](attachments/Pasted%20image%2020220606124415.png)


![](attachments/Pasted%20image%2020220606124902.png)

![](attachments/Pasted%20image%2020220606125225.png)

![](attachments/Pasted%20image%2020220606125255.png)

![](attachments/Pasted%20image%2020220606125324.png)

![](attachments/Pasted%20image%2020220606125353.png)


![](attachments/Pasted%20image%2020220606131822.png)

![](attachments/Pasted%20image%2020220606133509.png)


run root.sh on both nodes:

Node 1:

```bash 
[root@rac1 run]# /u01/19c/oracle/ora_base/db_home/root.sh
Performing root user operation.

The following environment variables are set as:
    ORACLE_OWNER= oracle
    ORACLE_HOME=  /u01/19c/oracle/ora_base/db_home

Enter the full pathname of the local bin directory: [/usr/local/bin]: 
The contents of "dbhome" have not changed. No need to overwrite.
The contents of "oraenv" have not changed. No need to overwrite.
The contents of "coraenv" have not changed. No need to overwrite.

Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
[root@rac1 run]# 

```

Node 2:

```bash
[root@rac2 ~]# /u01/19c/oracle/ora_base/db_home/root.sh
Performing root user operation.

The following environment variables are set as:
    ORACLE_OWNER= oracle
    ORACLE_HOME=  /u01/19c/oracle/ora_base/db_home

Enter the full pathname of the local bin directory: [/usr/local/bin]: 
The contents of "dbhome" have not changed. No need to overwrite.
The contents of "oraenv" have not changed. No need to overwrite.
The contents of "coraenv" have not changed. No need to overwrite.

Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
[root@rac2 ~]#
```

click Ok and close 

![](attachments/Pasted%20image%2020220606133731.png)

### Create Data,FRA
Node 1:

```bash
[root@rac1 run]# source /home/grid/.grid_env 
[root@rac1 run]# export ORACLE_BASE=/tmp
[root@rac1 run]# lsblk 
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda           8:0    0   25G  0 disk 
├─sda1        8:1    0  500M  0 part /boot
└─sda2        8:2    0 24.5G  0 part 
  ├─ol-root 252:0    0 16.3G  0 lvm  /
  └─ol-swap 252:1    0  8.2G  0 lvm  [SWAP]
sdb           8:16   0   40G  0 disk 
└─sdb1        8:17   0   40G  0 part 
  └─db-u01  252:2    0   40G  0 lvm  /u01
sdc           8:32   0    5G  0 disk 
└─sdc1        8:33   0    5G  0 part 
sdd           8:48   0   20G  0 disk 
└─sdd1        8:49   0   20G  0 part 
sde           8:64   0   15G  0 disk 
└─sde1        8:65   0   15G  0 part 
[root@rac1 run]# asmcmd -V 
asmcmd version 19.15.0.0.0
[root@rac1 run]# asmcmd afd_lsdsk
---------------------------------------------------------
Label                     Filtering   Path
=========================================================
CRS1                        ENABLED   /dev/sdc1
[root@rac1 run]# asmcmd afd_label FRA1 /dev/sde1
[root@rac1 run]# asmcmd afd_label DATA1 /dev/sdd1
[root@rac1 run]# asmcmd afd_lsdsk
----------------------------------------------------------
Label                     Filtering   Path
==========================================================
CRS1                        ENABLED   /dev/sdc1
DATA1                       ENABLED   /dev/sdd1
FRA1                        ENABLED   /dev/sde1
[root@rac1 run]#
[root@rac1 run]# ls -l /dev/oracleafd/disks/
total 12
-rw-rw-r--. 1 grid oinstall 10 Jun  6 10:59 CRS1
-rw-rw-r--. 1 grid oinstall 10 Jun  6 13:43 DATA1
-rw-rw-r--. 1 grid oinstall 10 Jun  6 13:43 FRA1
[root@rac1 run]# 
```

Node 2:

```bash
[root@rac1 run]# source /home/grid/.grid_env 
[root@rac1 run]# export ORACLE_BASE=/tmp
[root@rac1 run]# asmcmd -V 
asmcmd version 19.15.0.0.0
[root@rac2 ~]# asmcmd afd_lsdsk
---------------------------------------------------------
Label                     Filtering   Path
=========================================================
CRS1                        ENABLED   /dev/sdc1
DATA1                       ENABLED   /dev/sdd1
FRA1                        ENABLED   /dev/sde1
[root@rac2 ~]#

# if the above list not updated after you changed from the first node try below command 
[root@rac2 ~]# asmcmd afd_scan
# then 
[root@rac2 ~]# asmcmd afd_lsdsk


```

using grid user

```bash
asmca
```

Right Click on `Disk Groups` list then select `Create`

![](attachments/Pasted%20image%2020220606135838.png)

![](attachments/Pasted%20image%2020220606135954.png)

![](attachments/Pasted%20image%2020220606140045.png)

![](attachments/Pasted%20image%2020220606140133.png)

![](attachments/Pasted%20image%2020220606140220.png)



### Create DB

```bash
# using oracle user 
dbca
```

![](attachments/Pasted%20image%2020220606134002.png)

![](attachments/Pasted%20image%2020220606140620.png)

![](attachments/Pasted%20image%2020220606140641.png)

![](attachments/Pasted%20image%2020220606141402.png)

![](attachments/Pasted%20image%2020220606141457.png)

![](attachments/Pasted%20image%2020220606141532.png)

![](attachments/Pasted%20image%2020220606141619.png)

![](attachments/Pasted%20image%2020220606141846.png)

![](attachments/Pasted%20image%2020220606141723.png)

![](attachments/Pasted%20image%2020220606141955.png)

![](attachments/Pasted%20image%2020220606142029.png)

![](attachments/Pasted%20image%2020220606142120.png)

![](attachments/Pasted%20image%2020220607235437.png)

![](attachments/Pasted%20image%2020220607235506.png)

![](attachments/Pasted%20image%2020220607235557.png)

![](attachments/Pasted%20image%2020220607235705.png)

![](attachments/Pasted%20image%2020220607235745.png)

![](attachments/Pasted%20image%2020220608002110.png)



## Patch DB 
### Node 1

#### Check
Run below command using oracle user 

```bash

[oracle@rac1 tmp]$ cat /tmp/patch_db.txt 
/tmp/33803476/33806152
/tmp/33803476/33815596

[oracle@rac1 tmp]$ $ORACLE_HOME/OPatch/opatch prereq CheckSystemSpace -phBaseFile /tmp/patch_db.txt 
Oracle Interim Patch Installer version 12.2.0.1.30
Copyright (c) 2022, Oracle Corporation.  All rights reserved.

PREREQ session

Oracle Home       : /u01/19c/oracle/ora_base/db_home
Central Inventory : /u01/19c/grid/oraInventory
   from           : /u01/19c/oracle/ora_base/db_home/oraInst.loc
OPatch version    : 12.2.0.1.30
OUI version       : 12.2.0.7.0
Log file location : /u01/19c/oracle/ora_base/db_home/cfgtoollogs/opatch/opatch2022-06-08_00-33-16AM_1.log

Invoking prereq "checksystemspace"

Prereq "checkSystemSpace" passed.

OPatch succeeded.

```

#### Analyze

```bash
# analyze
[root@rac1 ~]# source /home/oracle/.db19_env 
[root@rac1 ~]# $ORACLE_HOME/OPatch/opatchauto apply /u01/33803476 -oh $ORACLE_HOME -analyze

OPatchauto session is initiated at Wed Jun  8 00:40:20 2022

System initialization log file is /u01/19c/oracle/ora_base/db_home/cfgtoollogs/opatchautodb/systemconfig2022-06-08_12-40-25AM.log.

Session log file is /u01/19c/oracle/ora_base/db_home/cfgtoollogs/opatchauto/opatchauto2022-06-08_12-41-03AM.log
The id for this session is 5UVE

Executing OPatch prereq operations to verify patch applicability on home /u01/19c/oracle/ora_base/db_home
Patch applicability verified successfully on home /u01/19c/oracle/ora_base/db_home


Executing patch validation checks on home /u01/19c/oracle/ora_base/db_home
Patch validation checks successfully completed on home /u01/19c/oracle/ora_base/db_home


Verifying SQL patch applicability on home /u01/19c/oracle/ora_base/db_home
SQL patch applicability verified successfully on home /u01/19c/oracle/ora_base/db_home

OPatchAuto successful.

--------------------------------Summary--------------------------------

Analysis for applying patches has completed successfully:

Host:rac1
RAC Home:/u01/19c/oracle/ora_base/db_home
Version:19.0.0.0.0


==Following patches were SKIPPED:

Patch: /tmp/33803476/33815607
Reason: This patch is not applicable to this specified target type - "rac_database"

Patch: /tmp/33803476/33575402
Reason: This patch is not applicable to this specified target type - "rac_database"

Patch: /tmp/33803476/33911149
Reason: This patch is not applicable to this specified target type - "rac_database"


==Following patches were SUCCESSFULLY analyzed to be applied:

Patch: /tmp/33803476/33815596
Log: /u01/19c/oracle/ora_base/db_home/cfgtoollogs/opatchauto/core/opatch/opatch2022-06-08_00-41-22AM_1.log

Patch: /tmp/33803476/33806152
Log: /u01/19c/oracle/ora_base/db_home/cfgtoollogs/opatchauto/core/opatch/opatch2022-06-08_00-41-22AM_1.log



OPatchauto session completed at Wed Jun  8 00:42:54 2022
Time taken to complete the session 2 minutes, 34 seconds


```

#### Apply

```bash

[root@rac1 ~]# $ORACLE_HOME/OPatch/opatchauto apply /u01/33803476 -oh $ORACLE_HOME 

OPatchauto session is initiated at Wed Jun  8 00:44:46 2022

System initialization log file is /u01/19c/oracle/ora_base/db_home/cfgtoollogs/opatchautodb/systemconfig2022-06-08_12-44-52AM.log.

Session log file is /u01/19c/oracle/ora_base/db_home/cfgtoollogs/opatchauto/opatchauto2022-06-08_12-45-12AM.log
The id for this session is RX22

Executing OPatch prereq operations to verify patch applicability on home /u01/19c/oracle/ora_base/db_home
Patch applicability verified successfully on home /u01/19c/oracle/ora_base/db_home


Executing patch validation checks on home /u01/19c/oracle/ora_base/db_home
Patch validation checks successfully completed on home /u01/19c/oracle/ora_base/db_home


Verifying SQL patch applicability on home /u01/19c/oracle/ora_base/db_home
SQL patch applicability verified successfully on home /u01/19c/oracle/ora_base/db_home


Preparing to bring down database service on home /u01/19c/oracle/ora_base/db_home
Successfully prepared home /u01/19c/oracle/ora_base/db_home to bring down database service


Bringing down database service on home /u01/19c/oracle/ora_base/db_home
Following database(s) and/or service(s) are stopped and will be restarted later during the session: prod
Database service successfully brought down on home /u01/19c/oracle/ora_base/db_home


Performing prepatch operation on home /u01/19c/oracle/ora_base/db_home
Perpatch operation completed successfully on home /u01/19c/oracle/ora_base/db_home


Start applying binary patch on home /u01/19c/oracle/ora_base/db_home
Binary patch applied successfully on home /u01/19c/oracle/ora_base/db_home


Performing postpatch operation on home /u01/19c/oracle/ora_base/db_home
Postpatch operation completed successfully on home /u01/19c/oracle/ora_base/db_home


Starting database service on home /u01/19c/oracle/ora_base/db_home
Database service successfully started on home /u01/19c/oracle/ora_base/db_home


Preparing home /u01/19c/oracle/ora_base/db_home after database service restarted
No step execution required.........
 

Trying to apply SQL patch on home /u01/19c/oracle/ora_base/db_home
SQL patch applied successfully on home /u01/19c/oracle/ora_base/db_home

OPatchAuto successful.

--------------------------------Summary--------------------------------

Patching is completed successfully. Please find the summary as follows:

Host:rac1
RAC Home:/u01/19c/oracle/ora_base/db_home
Version:19.0.0.0.0
Summary:

==Following patches were SKIPPED:

Patch: /tmp/33803476/33815607
Reason: This patch is not applicable to this specified target type - "rac_database"

Patch: /tmp/33803476/33575402
Reason: This patch is not applicable to this specified target type - "rac_database"

Patch: /tmp/33803476/33911149
Reason: This patch is not applicable to this specified target type - "rac_database"


==Following patches were SUCCESSFULLY applied:

Patch: /tmp/33803476/33806152
Log: /u01/19c/oracle/ora_base/db_home/cfgtoollogs/opatchauto/core/opatch/opatch2022-06-08_00-48-00AM_1.log

Patch: /tmp/33803476/33815596
Log: /u01/19c/oracle/ora_base/db_home/cfgtoollogs/opatchauto/core/opatch/opatch2022-06-08_00-48-00AM_1.log



OPatchauto session completed at Wed Jun  8 00:56:59 2022
Time taken to complete the session 12 minutes, 13 seconds

```

### Node 2

#### Check

```bash

[oracle@rac2 ~]$ $ORACLE_HOME/OPatch/opatch prereq CheckSystemSpace -phBaseFile /tmp/patch_db.txt 
Oracle Interim Patch Installer version 12.2.0.1.30
Copyright (c) 2022, Oracle Corporation.  All rights reserved.

PREREQ session

Oracle Home       : /u01/19c/oracle/ora_base/db_home
Central Inventory : /u01/19c/grid/oraInventory
   from           : /u01/19c/oracle/ora_base/db_home/oraInst.loc
OPatch version    : 12.2.0.1.30
OUI version       : 12.2.0.7.0
Log file location : /u01/19c/oracle/ora_base/db_home/cfgtoollogs/opatch/opatch2022-06-08_01-42-50AM_1.log

Invoking prereq "checksystemspace"

Prereq "checkSystemSpace" passed.

OPatch succeeded.
```

#### Analyze

```bash
[oracle@rac2 u01]$ su - root
Password: 
[root@rac2 ~]# source /home/oracle/.db19_env 
[root@rac2 ~]# $ORACLE_HOME/OPatch/opatchauto apply /u01/33803476 -oh $ORACLE_HOME -analyze

OPatchauto session is initiated at Wed Jun  8 01:33:33 2022

System initialization log file is /u01/19c/oracle/ora_base/db_home/cfgtoollogs/opatchautodb/systemconfig2022-06-08_01-33-40AM.log.

Session log file is /u01/19c/oracle/ora_base/db_home/cfgtoollogs/opatchauto/opatchauto2022-06-08_01-34-03AM.log
The id for this session is RQSL

Executing OPatch prereq operations to verify patch applicability on home /u01/19c/oracle/ora_base/db_home
Patch applicability verified successfully on home /u01/19c/oracle/ora_base/db_home


Executing patch validation checks on home /u01/19c/oracle/ora_base/db_home
Patch validation checks successfully completed on home /u01/19c/oracle/ora_base/db_home


Verifying SQL patch applicability on home /u01/19c/oracle/ora_base/db_home
SQL patch applicability verified successfully on home /u01/19c/oracle/ora_base/db_home

OPatchAuto successful.

--------------------------------Summary--------------------------------

Analysis for applying patches has completed successfully:

Host:rac2
RAC Home:/u01/19c/oracle/ora_base/db_home
Version:19.0.0.0.0


==Following patches were SKIPPED:

Patch: /tmp/33803476/33815607
Reason: This patch is not applicable to this specified target type - "rac_database"

Patch: /tmp/33803476/33575402
Reason: This patch is not applicable to this specified target type - "rac_database"

Patch: /tmp/33803476/33911149
Reason: This patch is not applicable to this specified target type - "rac_database"


==Following patches were SUCCESSFULLY analyzed to be applied:

Patch: /tmp/33803476/33815596
Log: /u01/19c/oracle/ora_base/db_home/cfgtoollogs/opatchauto/core/opatch/opatch2022-06-08_01-34-26AM_1.log

Patch: /tmp/33803476/33806152
Log: /u01/19c/oracle/ora_base/db_home/cfgtoollogs/opatchauto/core/opatch/opatch2022-06-08_01-34-26AM_1.log



OPatchauto session completed at Wed Jun  8 01:36:08 2022
Time taken to complete the session 2 minutes, 36 seconds
```

#### Apply

```bash
[root@rac2 ~]# $ORACLE_HOME/OPatch/opatchauto apply /u01/33803476 -oh $ORACLE_HOME 

OPatchauto session is initiated at Wed Jun  8 01:44:49 2022

System initialization log file is /u01/19c/oracle/ora_base/db_home/cfgtoollogs/opatchautodb/systemconfig2022-06-08_01-44-54AM.log.

Session log file is /u01/19c/oracle/ora_base/db_home/cfgtoollogs/opatchauto/opatchauto2022-06-08_01-45-12AM.log
The id for this session is 7F7L

Executing OPatch prereq operations to verify patch applicability on home /u01/19c/oracle/ora_base/db_home
Patch applicability verified successfully on home /u01/19c/oracle/ora_base/db_home


Executing patch validation checks on home /u01/19c/oracle/ora_base/db_home
Patch validation checks successfully completed on home /u01/19c/oracle/ora_base/db_home


Verifying SQL patch applicability on home /u01/19c/oracle/ora_base/db_home
SQL patch applicability verified successfully on home /u01/19c/oracle/ora_base/db_home


Preparing to bring down database service on home /u01/19c/oracle/ora_base/db_home
Successfully prepared home /u01/19c/oracle/ora_base/db_home to bring down database service


Bringing down database service on home /u01/19c/oracle/ora_base/db_home
Following database(s) and/or service(s) are stopped and will be restarted later during the session: prod
Database service successfully brought down on home /u01/19c/oracle/ora_base/db_home


Performing prepatch operation on home /u01/19c/oracle/ora_base/db_home
Perpatch operation completed successfully on home /u01/19c/oracle/ora_base/db_home


Start applying binary patch on home /u01/19c/oracle/ora_base/db_home
Binary patch applied successfully on home /u01/19c/oracle/ora_base/db_home


Performing postpatch operation on home /u01/19c/oracle/ora_base/db_home
Postpatch operation completed successfully on home /u01/19c/oracle/ora_base/db_home


Starting database service on home /u01/19c/oracle/ora_base/db_home
Database service successfully started on home /u01/19c/oracle/ora_base/db_home


Preparing home /u01/19c/oracle/ora_base/db_home after database service restarted
No step execution required.........
 

Trying to apply SQL patch on home /u01/19c/oracle/ora_base/db_home
SQL patch applied successfully on home /u01/19c/oracle/ora_base/db_home

OPatchAuto successful.

--------------------------------Summary--------------------------------

Patching is completed successfully. Please find the summary as follows:

Host:rac2
RAC Home:/u01/19c/oracle/ora_base/db_home
Version:19.0.0.0.0
Summary:

==Following patches were SKIPPED:

Patch: /tmp/33803476/33815607
Reason: This patch is not applicable to this specified target type - "rac_database"

Patch: /tmp/33803476/33575402
Reason: This patch is not applicable to this specified target type - "rac_database"

Patch: /tmp/33803476/33911149
Reason: This patch is not applicable to this specified target type - "rac_database"


==Following patches were SUCCESSFULLY applied:

Patch: /tmp/33803476/33806152
Log: /u01/19c/oracle/ora_base/db_home/cfgtoollogs/opatchauto/core/opatch/opatch2022-06-08_01-48-09AM_1.log

Patch: /tmp/33803476/33815596
Log: /u01/19c/oracle/ora_base/db_home/cfgtoollogs/opatchauto/core/opatch/opatch2022-06-08_01-48-09AM_1.log



OPatchauto session completed at Wed Jun  8 02:32:30 2022
Time taken to complete the session 47 minutes, 41 seconds
[root@rac2 ~]# 

```

### Data Patch

```bash
[oracle@rac1 ~]$ $ORACLE_HOME/OPatch/datapatch -verbose
SQL Patching tool version 19.15.0.0.0 Production on Wed Jun  8 04:22:16 2022
Copyright (c) 2012, 2022, Oracle.  All rights reserved.

Log file for this invocation: /u01/19c/oracle/ora_base/cfgtoollogs/sqlpatch/sqlpatch_217606_2022_06_08_04_22_16/sqlpatch_invocation.log

Connecting to database...OK
Gathering database info...done

Note:  Datapatch will only apply or rollback SQL fixes for PDBs
       that are in an open state, no patches will be applied to closed PDBs.
       Please refer to Note: Datapatch: Database 12c Post Patch SQL Automation
       (Doc ID 1585822.1)

Bootstrapping registry and package to current versions...done
Determining current state...done

Current state of interim SQL patches:
  No interim patches found

Current state of release update SQL patches:
  Binary registry:
    19.15.0.0.0 Release_Update 220331125408: Installed
  PDB CDB$ROOT:
    Applied 19.15.0.0.0 Release_Update 220331125408 successfully on 08-JUN-22 02.32.06.874332 AM
  PDB PDB$SEED:
    Applied 19.15.0.0.0 Release_Update 220331125408 successfully on 08-JUN-22 02.32.14.722388 AM
  PDB PRODPDB1:
    Applied 19.15.0.0.0 Release_Update 220331125408 successfully on 08-JUN-22 02.32.22.122060 AM

Adding patches to installation queue and performing prereq checks...done
Installation queue:
  For the following PDBs: CDB$ROOT PDB$SEED PRODPDB1
    No interim patches need to be rolled back
    No release update patches need to be installed
    No interim patches need to be applied

SQL Patching tool complete on Wed Jun  8 04:22:52 2022
[oracle@rac1 ~]$ 


```

### Check Version 

```bash
[oracle@rac1 ~]$ cat s.sh 
sqlplus -s / as sysdba <<SQL
set pages 100 lines 500
col comp_name for a40
col version for a15
col version_ful for a15
col status for a15
--col con_id for a10
select comp_name, version, version_full,status,con_id from cdb_registry order by con_id;
SQL

```

```bash
[oracle@rac1 ~]$ ./s.sh 

COMP_NAME				 VERSION	 VERSION_FULL			STATUS		    CON_ID
---------------------------------------- --------------- ------------------------------ --------------- ----------
Oracle Database Catalog Views		 19.0.0.0.0	 19.15.0.0.0			VALID			 1
Oracle Database Vault			 19.0.0.0.0	 19.15.0.0.0			VALID			 1
Oracle Real Application Clusters	 19.0.0.0.0	 19.15.0.0.0			VALID			 1
JServer JAVA Virtual Machine		 19.0.0.0.0	 19.15.0.0.0			VALID			 1
Oracle XDK				 19.0.0.0.0	 19.15.0.0.0			VALID			 1
Oracle Database Java Packages		 19.0.0.0.0	 19.15.0.0.0			VALID			 1
OLAP Analytic Workspace 		 19.0.0.0.0	 19.15.0.0.0			VALID			 1
Oracle XML Database			 19.0.0.0.0	 19.15.0.0.0			VALID			 1
Oracle Workspace Manager		 19.0.0.0.0	 19.15.0.0.0			VALID			 1
Oracle Text				 19.0.0.0.0	 19.15.0.0.0			VALID			 1
Oracle Multimedia			 19.0.0.0.0	 19.15.0.0.0			VALID			 1
Spatial 				 19.0.0.0.0	 19.15.0.0.0			LOADING 		 1
Oracle OLAP API 			 19.0.0.0.0	 19.15.0.0.0			VALID			 1
Oracle Label Security			 19.0.0.0.0	 19.15.0.0.0			VALID			 1
Oracle Database Packages and Types	 19.0.0.0.0	 19.15.0.0.0			VALID			 1
Oracle Database Catalog Views		 19.0.0.0.0	 19.15.0.0.0			VALID			 3
Oracle Database Vault			 19.0.0.0.0	 19.15.0.0.0			VALID			 3
Oracle Real Application Clusters	 19.0.0.0.0	 19.15.0.0.0			VALID			 3
JServer JAVA Virtual Machine		 19.0.0.0.0	 19.15.0.0.0			VALID			 3
Oracle XDK				 19.0.0.0.0	 19.15.0.0.0			VALID			 3
Oracle Database Java Packages		 19.0.0.0.0	 19.15.0.0.0			VALID			 3
OLAP Analytic Workspace 		 19.0.0.0.0	 19.15.0.0.0			VALID			 3
Oracle XML Database			 19.0.0.0.0	 19.15.0.0.0			VALID			 3
Oracle Workspace Manager		 19.0.0.0.0	 19.15.0.0.0			VALID			 3
Oracle Text				 19.0.0.0.0	 19.15.0.0.0			VALID			 3
Oracle Multimedia			 19.0.0.0.0	 19.15.0.0.0			VALID			 3
Spatial 				 19.0.0.0.0	 19.15.0.0.0			LOADING 		 3
Oracle OLAP API 			 19.0.0.0.0	 19.15.0.0.0			VALID			 3
Oracle Label Security			 19.0.0.0.0	 19.15.0.0.0			VALID			 3
Oracle Database Packages and Types	 19.0.0.0.0	 19.15.0.0.0			VALID			 3

30 rows selected.

```

## Manage Cluster Services
To manage cluster components and elements, oracle invented two tools that you can find them in the grid home under bin directory, which they help you to manage and control the cluster, the commands are `crsctl` and `srvctl` so what is the difference between them? and how we can use them?

**Crsctl** command is used to manage the elements of the **clusterware** (crs, css, evm to be more precise. There are other components of the clusteware such as OCR,voting disk, managed by other tools )  while **srvctl** is used to manage the elements of the **cluster**  (databases,instances,listeners, services etc) . For exemple, with **crsctl** you can tune the heartbeat of the cluster, while with **srvctl** you will set up the load balancing at the service level.  **Srvtcl** was introduced with Oracle 9i and **crsctl** was introduced with Oracle 10g and both have been improved since. There is sometimes some confusion among DBAs because both commands can be used to start the database, **crsctl** starting the whole clusterware + cluster, while **srvctl** is starting the other elements, such as database, listener, services, _but not the clusterware_. Somewhere in Oracle documentation 10g, it is written that Oracle corporation suggest you to use srvctl command to start the databases in the cluster.

```bash

# stop both nodes cluster services 

# list help menu for command 
crsctl -h
crs check -h 

# enable auto start for HAS 
crsctl enable crs

# check crs high avialability services are online 
crsctl check crs

# will stop once node 
crsctl stop crs # -f to force if the cluster is stuck

# stop all cluster services
# you need high availablity service (HAS) and CRS  running on both nodes 

crsctl stop cluster -all 
crsctl stop cluster -n rac1/rac2 

crsctl start  cluster -all
crsctl start  cluster -n rac1

# stop / start instance
srvctl stop instance -d PROD  -i PROD2
srvctl start instance -d PROD  -i PROD2

# status of database and services 
srvctl status database -d prod

# check configuration of the services 
srvctl config database -d prod

# modify the configuration of the service 

# search for the option 
srvctl modify database -h | grep -i pfile



# create service and remove it
[oracle@rac1 ~]$ srvctl add service -d prod -pdb prodpdb1 -service sales -preferred PROD1,PROD2
[oracle@rac1 ~]$ srvctl status service -d prod
Service sales is not running.
[oracle@rac1 ~]$ srvctl start service -d prod -s sales
[oracle@rac1 ~]$ srvctl status service -d prod
Service sales is running on instance(s) PROD1,PROD2
[oracle@rac1 ~]$ srvctl stop  service -d prod  -s sales
[oracle@rac1 ~]$ srvctl remove  service -d prod  -s sales
[oracle@rac1 ~]$ srvctl status service -d prod



```