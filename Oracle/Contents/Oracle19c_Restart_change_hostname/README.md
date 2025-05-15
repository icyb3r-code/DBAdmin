# Change Host-name [Oracle 19c DB + Grid Infra]



## Introduction 

Welcome back again guys with a new video, this time the video will be about how we can change the host-name for Oracle or Redhat linux Operating System which contains a oracle grid + database installed on it.  it's not a complicated task if you follow me with the steps that I put for this video, but before we dive in, you may ask why we need to change the host-name, and what is the circumstances that push me to do that, one of those circumstances is you have change in comany DNS or you are cloning the production environment to Development environment, or you are doing some experimental stuff so you want to save time of redoing things.. etc.

So the main goal, to save time of redoing things if you can only clone the system and just change the host-name, this video will show you how-to 

before we start our hands-on lab, if you still don't have oracle installed you can find the link below in the video description box for my video how to install Oracle 19c Grid infrastructure + Database,  please take look at my github account, I pushed all the steps to the DBAdmin repo, you can find the link below in the description box.  

Please watch the You-tube Video:

[![Youtube Video](https://img.youtube.com/vi/MMsTZWvdFGg/0.jpg)](https://www.youtube.com/watch?v=MMsTZWvdFGg)

## Prerequisites : 

* Oracle Grid Infrastructure should be installed with ASM.
* Oracle 19c Database installed.
* OS linux 8.3 

## Steps



### Overview

1. check the grid and database status ( ps , services ) 

   1. Su - root (. oraenv ==> +ASM)
   2. database and grid processes  (ps)
   3. check the services (crsctl stat res -t )
   4. check HAS status 
   5. srvctl config asm
   6. srvctl config database -d prod

2. ASM parameter file

   1. create ASM parameter file (pfile) (create pfile='/tmp/asmpfile.ora' from spfile;)
   2. check the spfile parameter !ls /tmp/*.ora

3. Deconfig HAS (this maybe not required)

   1. . oraenv (as root)
   2. cd $OACLE_HOME/crs/install
   3. ./roothas.sh -deconfig -force

4. Change Hostname

   1. hostnamectl 
   2. hostnamectl set-hostname standby.oradomain
   3. hostnamectl 
   4. cat /etc/sysconfig/network
   5. vi /etc/hosts 
   6. grid_home/network/admin/[tnsnames.ora,sqlnet.ora]
   7. oracle_home/network/admin/[tnsnames.ora,sqlnet.ora]
   8. check for applications config files

5. Reconfigure the HAS

   1. . oraenv (as root user) (+ASM)
   2. $ORACLE_HOME/root.sh (as root user)

6. Modify Cluster Synchronization service (CSS)

   1. crsctl modify resource "ora.cssd" -init -attr "AUTO_START=1" -unsupported (as grid user)
   2. Restart HAS (crsctl stop/start has)
   3. Check HAS (crsctl stat res / -t,crsctl check has/css)

7. Add/Start Listener 

   1. srvctl add listener (as grid)
   2. srvctl start listener (as grid)
   3. srvctl status listener (as grid)

8. Add ASM service 

   1. srvctl add asm
   2. crsctl modify resource "ora.asm" -init -attr "AUTO_START=1"
   3. srvctl modify asm -spfile '+CRS/ASM/ASMPARAMETERFILE/REGISTRY.253.1073579369' -pwfile '+CRS/ASM/PASSWORD/pwdasm.256.1073579373' -diskstring '/dev/oracleasm/*' -l LISTENER
   4. create ASM instance(startup pfile='/tmp/asmpfile.ora')
   5. alter diskgroup CRS mount force;
   6. alter diskgroup DATA mount force;
   7. alter diskgroup FRA mount force;
   8. asmcmd (check crs asm spfile and pwfile)

9. Add database service

   1. asmcmd ls 
   2. echo $ORACLE_SID
   3. srvctl add database -d prod -oraclehome $ORACLE_HOME -spfile '+DATA/PROD/PARAMETERFILE/spfile.269.1073581087'
   4. srvctl start database -d prod
   5. srvctl status database -d prod
   6. sqlplus / as sysdba (show pdbs, alter pluggable database prodpdb1 open,show pdbs)

10. Check services

    1. crsctl stat res -t
    2. crsctl stop has
    3. reboot
    4. crsctl check has

    

### Details



1. check the grid and database status ( ps , services ) 

   1. Su - root (. oraenv ==> +ASM)

      ```bash
      [admin@ora19c ~]$ su - 
      Password: 
      [root@ora19c ~]# . oraenv 
      ORACLE_SID = [root] ? +ASM
      The Oracle base has been set to /u01/19c/grid_base
      [root@ora19c ~]#
      ```

   2. database and grid processes  (ps)

      ```bash
      [root@ora19c ~]# ps -ef | grep -i 'pmon\|mrp'
      grid        8012       1  0 12:43 ?        00:00:00 asm_pmon_+ASM
      oracle      8405       1  0 12:43 ?        00:00:00 ora_pmon_prod
      root        8989    8841  0 12:45 pts/0    00:00:00 grep --color=auto -i pmon\|mrp
      [root@ora19c ~]#
      ```

   3. check the services (crsctl stat res -t )

      ```bash
      [root@ora19c ~]# crsctl stat res -t
      --------------------------------------------------------------------------------
      Name           Target  State        Server                   State details       
      --------------------------------------------------------------------------------
      Local Resources
      --------------------------------------------------------------------------------
      ora.CRS.dg
                     ONLINE  ONLINE       ora19c                   STABLE
      ora.DATA.dg
                     ONLINE  ONLINE       ora19c                   STABLE
      ora.FRA.dg
                     ONLINE  ONLINE       ora19c                   STABLE
      ora.LISTENER.lsnr
                     ONLINE  ONLINE       ora19c                   STABLE
      ora.asm
                     ONLINE  ONLINE       ora19c                   Started,STABLE
      ora.ons
                     OFFLINE OFFLINE      ora19c                   STABLE
      --------------------------------------------------------------------------------
      Cluster Resources
      --------------------------------------------------------------------------------
      ora.cssd
            1        ONLINE  ONLINE       ora19c                   STABLE
      ora.diskmon
            1        OFFLINE OFFLINE                               STABLE
      ora.evmd
            1        ONLINE  ONLINE       ora19c                   STABLE
      ora.prod.db
            1        ONLINE  ONLINE       ora19c                   Open,HOME=/u01/19c/o
                                                                   racle_base/oracle/db
                                                                   _home,STABLE
      --------------------------------------------------------------------------------
      [root@ora19c ~]#
      ```

   4. check HAS status 

      ```bash
      [root@ora19c ~]# crsctl check has 
      CRS-4638: Oracle High Availability Services is online
      [root@ora19c ~]#
      ```

   5. srvctl config asm

      ```bash
      [root@ora19c ~]# srvctl config asm
      ASM home: <CRS home>
      Password file: +CRS/orapwasm
      Backup of Password file: 
      ASM listener: LISTENER
      Spfile: +CRS/ASM/ASMPARAMETERFILE/registry.253.1073579369
      ASM diskgroup discovery string: /dev/oracleasm/*
      [root@ora19c ~]#
      ```

   6. srvctl config database -d prod

      ```bash
      [root@ora19c ~]# srvctl config database -d prod
      Database unique name: prod
      Database name: prod
      Oracle home: /u01/19c/oracle_base/oracle/db_home
      Oracle user: oracle
      Spfile: +DATA/PROD/PARAMETERFILE/spfile.269.1073581087
      Password file: 
      Domain: oradomain
      Start options: open
      Stop options: immediate
      Database role: PRIMARY
      Management policy: AUTOMATIC
      Disk Groups: DATA,FRA
      Services: 
      OSDBA group: 
      OSOPER group: 
      Database instance: prod
      [root@ora19c ~]#
      ```

2. ASM parameter file

   1. create ASM parameter file (pfile) (create pfile='/tmp/asmpfile.ora' from spfile;)

      ```bash
      [root@ora19c ~]# su - grid 
      [grid@ora19c ~]$ sqlplus / as sysasm
      
      SQL*Plus: Release 19.0.0.0.0 - Production on Sun Dec 19 13:12:21 2021
      Version 19.3.0.0.0
      
      Copyright (c) 1982, 2019, Oracle.  All rights reserved.
      
      
      Connected to:
      Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
      Version 19.3.0.0.0
      
      SQL> create pfile='/tmp/asmpfile.ora' from spfile;
      
      File created.
      
      SQL> !ls /tmp/*.ora
      /tmp/asmpfile.ora
      
      SQL>
      ```

      

   2. check the spfile parameter !ls /tmp/*.ora

      ```bash
      SQL> show parameter spfile 
      
      NAME			   TYPE	    VALUE
      ------------------ -------- ------------------------------
      spfile			   string	+CRS/ASM/ASMPARAMETERFILE/regi
      						     stry.253.1073579369
      SQL>
      ```

3. Deconfig HAS (this maybe not required)

   1. . oraenv (as root)

      ```bash
      # make sure the env set to oracle grid home on root user
      [root@ora19c ~]# . oraenv 
      ORACLE_SID = [+ASM] ? +ASM
      The Oracle base remains unchanged with value /u01/19c/grid_base
      [root@ora19c ~]# 
      ```

   2. cd $OACLE_HOME/crs/install

      ```bash
      [root@ora19c ~]# cd $ORACLE_HOME/crs/install
      [root@ora19c install]#
      ```

   3. ./roothas.sh -deconfig -force

      ```bash
      [root@ora19c install]# ./roothas.sh -deconfig -force
      Using configuration parameter file: /u01/19c/grid_home/crs/install/crsconfig_params
      The log of current session can be found at:
        /u01/19c/grid_base/crsdata/ora19c/crsconfig/hadeconfig.log
      2021/12/19 13:17:31 CLSRSC-332: CRS resources for listeners are still configured
      2021/12/19 13:17:47 CLSRSC-337: Successfully deconfigured Oracle Restart stack
      [root@ora19c install]# 
      ```

4. Change Hostname

   1. hostnamectl 

      ```bash
      [root@ora19c install]# hostnamectl 
         Static hostname: ora19c.oradomain
               Icon name: computer-vm
                 Chassis: vm
              Machine ID: e035f73e138c4b0da0843542e9654f91
                 Boot ID: 88e241e5046346feb78d3e3eb216b088
          Virtualization: vmware
        Operating System: Oracle Linux Server 8.3
             CPE OS Name: cpe:/o:oracle:linux:8:3:server
                  Kernel: Linux 5.4.17-2011.7.4.el8uek.x86_64
            Architecture: x86-64
      [root@ora19c install]# 
      ```

      

   2. hostnamectl set-hostname standby.oradomain

      ```bash
      [root@ora19c install]# hostnamectl set-hostname standby.oradomain
      ```

   3. hostnamectl 

      ```bash
      [root@ora19c install]# hostnamectl 
         Static hostname: standby.oradomain
               Icon name: computer-vm
                 Chassis: vm
              Machine ID: e035f73e138c4b0da0843542e9654f91
                 Boot ID: 88e241e5046346feb78d3e3eb216b088
          Virtualization: vmware
        Operating System: Oracle Linux Server 8.3
             CPE OS Name: cpe:/o:oracle:linux:8:3:server
                  Kernel: Linux 5.4.17-2011.7.4.el8uek.x86_64
            Architecture: x86-64
      [root@ora19c install]# 
      ```

   4. cat /etc/sysconfig/network

      ```bash
      # if the hostname added to the network config you need to edit it, too. 
      [root@ora19c install]# cat /etc/sysconfig/network
      # Created by anaconda
      # oracle-database-preinstall-19c : Add NOZEROCONF=yes
      NOZEROCONF=yes
      [root@ora19c install]#
      ```

   5. vi /etc/hosts 

      ```bash
      [root@ora19c install]# vi /etc/hosts 
      [root@ora19c install]# cat /etc/hosts
      127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
      ::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
      
      10.10.20.130	standby.oradomain standby
      [root@ora19c install]#
      ```

   6. grid_home/network/admin/[tnsnames.ora,sqlnet.ora]

   7. oracle_home/network/admin/[tnsnames.ora,sqlnet.ora]

   8. check for applications config files

5. Reconfigure the HAS

   1. . oraenv (as root user) (+ASM)

   2. $ORACLE_HOME/root.sh (as root user)

      ```bash
      [root@standby grid_home]# cd $ORACLE_HOME
      [root@standby grid_home]# ./root.sh
      Performing root user operation.
      
      The following environment variables are set as:
          ORACLE_OWNER= grid
          ORACLE_HOME=  /u01/19c/grid_home
      
      Enter the full pathname of the local bin directory: [/usr/local/bin]: 
      The contents of "dbhome" have not changed. No need to overwrite.
      The contents of "oraenv" have not changed. No need to overwrite.
      The contents of "coraenv" have not changed. No need to overwrite.
      
      Entries will be added to the /etc/oratab file as needed by
      Database Configuration Assistant when a database is created
      Finished running generic part of root script.
      Now product-specific root actions will be performed.
      Using configuration parameter file: /u01/19c/grid_home/crs/install/crsconfig_params
      The log of current session can be found at:
        /u01/19c/grid_base/crsdata/standby/crsconfig/roothas_2021-12-19_01-24-53PM.log
      2021/12/19 13:24:55 CLSRSC-363: User ignored prerequisites during installation
      LOCAL ADD MODE 
      Creating OCR keys for user 'grid', privgrp 'oinstall'..
      Operation successful.
      LOCAL ONLY MODE 
      Successfully accumulated necessary OCR keys.
      Creating OCR keys for user 'root', privgrp 'root'..
      Operation successful.
      CRS-4664: Node standby successfully pinned.
      2021/12/19 13:25:03 CLSRSC-330: Adding Clusterware entries to file 'oracle-ohasd.service'
      
      standby     2021/12/19 13:25:48     /u01/19c/grid_base/crsdata/standby/olr/backup_20211219_132548.olr     724960844     
      2021/12/19 13:25:49 CLSRSC-327: Successfully configured Oracle Restart for a standalone server
      
      ```

6. Modify Cluster Synchronizaton service (CSS)

   1. crsctl modify resource "ora.cssd"

      ```bash
      [root@standby grid_home]# su - grid
      [grid@standby ~]$ crsctl modify resource "ora.cssd" -init -attr "AUTO_START=1" -unsupported
      [grid@standby ~]$
      ```

   2. Restart HAS 

      ```bash
      [grid@standby ~]$ crsctl stop has 
      CRS-2791: Starting shutdown of Oracle High Availability Services-managed resources on 'standby'
      CRS-2673: Attempting to stop 'ora.evmd' on 'standby'
      CRS-2677: Stop of 'ora.evmd' on 'standby' succeeded
      CRS-2793: Shutdown of Oracle High Availability Services-managed resources on 'standby' has completed
      CRS-4133: Oracle High Availability Services has been stopped.
      [grid@standby ~]$
      
      
      ```

   3. Check HAS (crsctl stat res / -t,crsctl check has/css)

      ```bash
      [grid@standby ~]$ crsctl stat res 
      NAME=ora.cssd
      TYPE=ora.cssd.type
      TARGET=ONLINE
      STATE=ONLINE on standby
      
      NAME=ora.diskmon
      TYPE=ora.diskmon.type
      TARGET=OFFLINE
      STATE=OFFLINE
      
      NAME=ora.evmd
      TYPE=ora.evm.type
      TARGET=ONLINE
      STATE=ONLINE on standby
      
      NAME=ora.ons
      TYPE=ora.ons.type
      TARGET=OFFLINE
      STATE=OFFLINE
      
      [grid@standby ~]$ crsctl stat res -t 
      --------------------------------------------------------------------------------
      Name           Target  State        Server                   State details       
      --------------------------------------------------------------------------------
      Local Resources
      --------------------------------------------------------------------------------
      ora.ons
                     OFFLINE OFFLINE      standby                  STABLE
      --------------------------------------------------------------------------------
      Cluster Resources
      --------------------------------------------------------------------------------
      ora.cssd
            1        ONLINE  ONLINE       standby                  STABLE
      ora.diskmon
            1        OFFLINE OFFLINE                               STABLE
      ora.evmd
            1        ONLINE  ONLINE       standby                  STABLE
      --------------------------------------------------------------------------------
      [grid@standby ~]$ 
      [grid@standby ~]$ crsctl check has 
      CRS-4638: Oracle High Availability Services is online
      [grid@standby ~]$ crsctl check css
      CRS-4529: Cluster Synchronization Services is online
      [grid@standby ~]$
      ```

      

7. Add/Start Listener 

   1. srvctl add listener (as grid)

      ```bash
      [grid@standby ~]$ srvctl add listener
      ```

   2. srvctl start listener (as grid)

      ```bash
      [grid@standby ~]$ srvctl start listener
      ```

   3. srvctl status listener (as grid)

      ```bash
      [grid@standby ~]$ srvctl status listener 
      Listener LISTENER is enabled
      Listener LISTENER is running on node(s): standby
      [grid@standby ~]$ 
      ```

8. Add ASM service 

   1. srvctl add asm

      ```bash
      [grid@standby ~]$ srvctl add asm
      ```

   2. crsctl modify resource "ora.asm" 

      ```bash
      [grid@standby ~]$ crsctl modify resource "ora.asm" -init -attr "AUTO_START=1" -unsupported
      ```

   3. create ASM instance

      ```bash
      [grid@standby ~]$ sqlplus / as sysasm
      
      SQL*Plus: Release 19.0.0.0.0 - Production on Tue Dec 21 08:38:26 2021
      Version 19.3.0.0.0
      
      Copyright (c) 1982, 2019, Oracle.  All rights reserved.
      
      Connected to an idle instance.
      
      SQL> startup pfile='/tmp/asmpfile.ora';
      ASM instance started
      
      Total System Global Area 1137173320 bytes
      Fixed Size		    8905544 bytes
      Variable Size		 1103101952 bytes
      ASM Cache		   25165824 bytes
      ASM diskgroups mounted
      SQL> alter diskgroup crs mount force;
      
      Diskgroup altered.
      
      SQL>
      ```

   4. asmcmd (check crs asm spfile and pwfile)

   5. Modify ASM

      ```bash
      [grid@standby ~]$ srvctl modify asm -spfile '+CRS/ASM/ASMPARAMETERFILE/REGISTRY.253.1073579369' -pwfile '+CRS/ASM/PASSWORD/pwdasm.256.1073579373' -diskstring '/dev/oracleasm/*' -l LISTENER
      ```

   6. 

   7. Stop ASM

      ```bash
      [grid@standby ~]$ srvctl stop asm -force
      ```

   8. Start ASM

      ```bash
      [grid@standby ~]$ srvctl start asm 
      ```

   9. Check ASM status 

      ```bash
      [grid@standby ~]$ crsctl stat res -t 
      --------------------------------------------------------------------------------
      Name           Target  State        Server                   State details       
      --------------------------------------------------------------------------------
      Local Resources
      --------------------------------------------------------------------------------
      ora.CRS.dg
                     ONLINE  ONLINE       standby                  STABLE
      ora.DATA.dg
                     ONLINE  ONLINE       standby                  STABLE
      ora.FRA.dg
                     ONLINE  ONLINE       standby                  STABLE
      ora.LISTENER.lsnr
                     ONLINE  ONLINE       standby                  STABLE
      ora.asm
                     ONLINE  ONLINE       standby                  Started,STABLE
      ora.ons
                     OFFLINE OFFLINE      standby                  STABLE
      --------------------------------------------------------------------------------
      Cluster Resources
      --------------------------------------------------------------------------------
      ora.cssd
            1        ONLINE  ONLINE       standby                  STABLE
      ora.diskmon
            1        OFFLINE OFFLINE                               STABLE
      ora.evmd
            1        ONLINE  ONLINE       standby                  STABLE
      --------------------------------------------------------------------------------
      [grid@standby ~]$
      ```

      

9. Add database service

   1. asmcmd ls 

      ```bash
      [grid@standby ~]$ asmcmd 
      ASMCMD> ls 
      CRS/
      DATA/
      FRA/
      ASMCMD> cd data
      ASMCMD> ls 
      PROD/
      ASMCMD> cd prod 
      ASMCMD> ls 
      86B637B62FE07A65E053F706E80A27CA/
      C342D1D0D2E07ACDE05382140A0AE26E/
      C342F3B7488D84D9E05382140A0A2185/
      CONTROLFILE/
      DATAFILE/
      ONLINELOG/
      PARAMETERFILE/
      TEMPFILE/
      ASMCMD> ls -l PARA*
      Type           Redund  Striped  Time             Sys  Name
      PARAMETERFILE  UNPROT  COARSE   DEC 19 12:00:00  Y    spfile.269.1073581087
      ASMCMD>
      ```

   2. echo $ORACLE_SID

      ```bash
      [oracle@standby ~]$ echo $ORACLE_SID
      prod
      [oracle@standby ~]$
      ```

      

   3. Add database service to GI

      ```bash
      srvctl add database -d prod -oraclehome $ORACLE_HOME -spfile '+DATA/PROD/PARAMETERFILE/spfile.269.1073581087'
      ```

   4. Start database

      ```bash
      [oracle@standby ~]$ srvctl start database -d prod 
      ```

      

   5. Status of database service

      ```bash
      [oracle@standby ~]$ srvctl status database -d prod 
      Database is running.
      [oracle@standby ~]$ 
      [oracle@standby ~]$ ps -ef | grep pmon 
      grid      121178    3447  0 08:42 ?        00:00:00 asm_pmon_+ASM
      oracle    121637    3447  0 08:51 ?        00:00:00 ora_pmon_prod
      [oracle@standby ~]$
      ```

      

   6. Check Pluggable database 

      ```bash
      [oracle@standby ~]$ sqlplus / as sysdba 
      
      SQL*Plus: Release 19.0.0.0.0 - Production on Tue Dec 21 08:53:56 2021
      Version 19.3.0.0.0
      
      Copyright (c) 1982, 2019, Oracle.  All rights reserved.
      
      
      Connected to:
      Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
      Version 19.3.0.0.0
      
      SQL> show pdbs 
      
          CON_ID CON_NAME			  OPEN MODE  RESTRICTED
      ---------- ------------------------------ ---------- ----------
      	 2 PDB$SEED			  READ ONLY  NO
      	 3 PRODPDB1			  MOUNTED
      SQL> alter pluggable database prodpdb1 open;
      
      Pluggable database altered.
      
      SQL> show pdbs
      
          CON_ID CON_NAME			  OPEN MODE  RESTRICTED
      ---------- ------------------------------ ---------- ----------
      	 2 PDB$SEED			  READ ONLY  NO
      	 3 PRODPDB1			  READ WRITE NO
      SQL> 
      ```

      

10. Check services

    1. Check Services status 

       ```bash
       [grid@standby ~]$ crsctl stat res -t 
       --------------------------------------------------------------------------------
       Name           Target  State        Server                   State details       
       --------------------------------------------------------------------------------
       Local Resources
       --------------------------------------------------------------------------------
       ora.CRS.dg
                      ONLINE  ONLINE       standby                  STABLE
       ora.DATA.dg
                      ONLINE  ONLINE       standby                  STABLE
       ora.FRA.dg
                      ONLINE  ONLINE       standby                  STABLE
       ora.LISTENER.lsnr
                      ONLINE  ONLINE       standby                  STABLE
       ora.asm
                      ONLINE  ONLINE       standby                  Started,STABLE
       ora.ons
                      OFFLINE OFFLINE      standby                  STABLE
       --------------------------------------------------------------------------------
       Cluster Resources
       --------------------------------------------------------------------------------
       ora.cssd
             1        ONLINE  ONLINE       standby                  STABLE
       ora.diskmon
             1        OFFLINE OFFLINE                               STABLE
       ora.evmd
             1        ONLINE  ONLINE       standby                  STABLE
       ora.prod.db
             1        ONLINE  ONLINE       standby                  Open,HOME=/u01/19c/o
                                                                    racle_base/oracle/db
                                                                    _home,STABLE
       --------------------------------------------------------------------------------
       [grid@standby ~]$
       ```

       

    2. crsctl stop has

       ```bash
       #check trace file 
       [root@standby ~] cd /u01/19c/grid_base/diag/crs/standby/crs/trace
       [root@standby ~]# crsctl stop has 
       CRS-2791: Starting shutdown of Oracle High Availability Services-managed resources on 'standby'
       CRS-2673: Attempting to stop 'ora.evmd' on 'standby'
       CRS-2673: Attempting to stop 'ora.CRS.dg' on 'standby'
       CRS-2673: Attempting to stop 'ora.prod.db' on 'standby'
       CRS-2673: Attempting to stop 'ora.LISTENER.lsnr' on 'standby'
       CRS-2677: Stop of 'ora.CRS.dg' on 'standby' succeeded
       CRS-2677: Stop of 'ora.LISTENER.lsnr' on 'standby' succeeded
       CRS-2677: Stop of 'ora.evmd' on 'standby' succeeded
       CRS-2677: Stop of 'ora.prod.db' on 'standby' succeeded
       CRS-2673: Attempting to stop 'ora.DATA.dg' on 'standby'
       CRS-2673: Attempting to stop 'ora.FRA.dg' on 'standby'
       CRS-2677: Stop of 'ora.DATA.dg' on 'standby' succeeded
       CRS-2677: Stop of 'ora.FRA.dg' on 'standby' succeeded
       CRS-2673: Attempting to stop 'ora.asm' on 'standby'
       CRS-2677: Stop of 'ora.asm' on 'standby' succeeded
       CRS-2673: Attempting to stop 'ora.cssd' on 'standby'
       CRS-2677: Stop of 'ora.cssd' on 'standby' succeeded
       CRS-2793: Shutdown of Oracle High Availability Services-managed resources on 'standby' has completed
       CRS-4133: Oracle High Availability Services has been stopped.
       [root@standby ~]# 
       ```

       

    3. reboot

       ```bash
       [root@standby ~]#
       ```

       

    4. crsctl check has

       ```bash
       [root@standby ~]# crsctl check has 
       CRS-4638: Oracle High Availability Services is online
       [root@standby ~]# crsctl check css
       CRS-4529: Cluster Synchronization Services is online
       [root@standby ~]# 
       ```

    5. Check services

       ```bash
       [root@standby ~]# crsctl stat res -t 
       --------------------------------------------------------------------------------
       Name           Target  State        Server                   State details       
       --------------------------------------------------------------------------------
       Local Resources
       --------------------------------------------------------------------------------
       ora.CRS.dg
                      ONLINE  ONLINE       standby                  STABLE
       ora.DATA.dg
                      ONLINE  ONLINE       standby                  STABLE
       ora.FRA.dg
                      ONLINE  ONLINE       standby                  STABLE
       ora.LISTENER.lsnr
                      ONLINE  ONLINE       standby                  STABLE
       ora.asm
                      ONLINE  ONLINE       standby                  Started,STABLE
       ora.ons
                      OFFLINE OFFLINE      standby                  STABLE
       --------------------------------------------------------------------------------
       Cluster Resources
       --------------------------------------------------------------------------------
       ora.cssd
             1        ONLINE  ONLINE       standby                  STABLE
       ora.diskmon
             1        OFFLINE OFFLINE                               STABLE
       ora.evmd
             1        ONLINE  ONLINE       standby                  STABLE
       ora.prod.db
             1        ONLINE  ONLINE       standby                  Open,HOME=/u01/19c/o
                                                                    racle_base/oracle/db
                                                                    _home,STABLE
       --------------------------------------------------------------------------------
       [root@standby ~]# 
       ```

       

​	

