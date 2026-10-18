# MongoDB 

## TOC

* Installation
* Stop/Start Safely 
* Configuration
* Query
* Data In & Data out
* Indexing
* Replica Sets 
* Sharding
* Monitoring
* Security
* Miscellaneous

## Installation 

### Package Distributions

MongoDB is Written In C++ | Self Contained | No Dependencies.
MongoDB is written in C++ , and self contained that runs with one executable file means no need to Virtual Machine or any additional software to be running besides that  no dependencies or extra packages is required.

MongoDB Community Edition is Open Source | Mongodb.org | MongoDB Inc.

You can have MongoDB from mongodb.org as Community Edition and it can be found at the github as well, the MongoDB community edition can has support from Google Groups, stack Overflow, MongoDB Inv.
Mongo DB commercial edition can be found at mongodb.com MongoDB Inc, the commercial edition can be used for mission-critical systems that need support.

you can get MongoDB from mongodb.org and we can download it for those systems Windows,  Linux, Mac and Solaris.


### Basic MongoDB Installation - Linux

Download the Mongod from mongodb.com
```bash

# Download from www.mongodb.com

wget https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-rhel80-5.0.9.tgz

# Unzip mongodb compressed file 

gzip -d mongodb-linux-x86_64-rhel80-5.0.9.tgz
tar -xvf mongodb-linux-x86_64-rhel80-5.0.9.tar

# Export the PATH

export PATH=$PATH:~/Download/mongodb-linux-x86_64-rhel80-5.0.9/bin

# Run Mongod and asign data dir location

mongod --dbpath ./data/

# connect using Mongo shell

mongo --host localhost --port 27017

```

pretty easy and gentle start. 

### MongoDB as a Server - Linux 

To run MongoDB  as a server we can use the package installer such as apt, yum, dnf and so on, and good to mention that if we used the package installer, it will take care of the environment, startup parameters and runtime options 

First thing we need to check the file-system `ext4` and `xfs` are recommended because they are faster in allocating files  and the `ext3` is not. under normal operation MongoDB potentially ask OS to create a large file up to 2 GB sometime, for such operation `ext3` takes time to allocate such file, but for `ext4` and `xfs` will be faster so MongoDB will not have to wait this operation to finish, and this wait will cause block all the operation by MongoDB until OS finish the file allocation and filling.

```bash
# to check the drive file system 
mount | grep " / "
/dev/mapper/ol-root on / type xfs (rw,relatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,noquota)


```

Second thing we need to disable last access time feature on the file-system, to do so you can add `noatime`

```bash
# open fstab

sudo vim /etc/fstab

# add noatime right after defaults and save

/dev/mapper/ol-root  /  xfs     defaults,noatime    0 0

# reboot

reboot

```


Installation steps, follow the [link](https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-red-hat/) to find the same instruction for other distributions:

```bash
# add this to yum repo 
sudo vim /etc/yum.repos.d/mongodb-org-5.0.repo

## add below to file and save the changes
[mongodb-org-5.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/5.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-5.0.asc

# sudo dnf makecache

# install latest
sudo dnf install -y mongodb-org

# Install specific version 
sudo dnf install -y mongodb-org-5.0.9 mongodb-org-database-5.0.9 mongodb-org-server-5.0.9 mongodb-org-shell-5.0.9 mongodb-org-mongos-5.0.9 mongodb-org-tools-5.0.9
```

> To prevent unintended upgrades MongoDB you can hold or pin this package, below shows how we can pin or exclude the package.

```bash
sudo vim /ect/yum.conf
exclude=mongodb-org,mongodb-org-database,mongodb-org-server,mongodb-org-shell,mongodb-org-mongos,mongodb-org-tools
```

below default directories are used by `mongod`
* /var/lib/mongo (the data directory)
* /var/log/mongodb (the log directory

Files used:
* /etc/mongod.conf (the Config File)
* /usr/lib/systemd/system/mongod.service (the Service File)

### Basic MongoDB Installation - Windows

```powershell

# download zip file and unzip

mongodb-windows-x86_64-5.0.9.zip


set PATH=%PATH%;C:\MongoDB\bin


md c:\mongoadmin\data

md c:\mongoadmin\log

md c:\mongoadmin\config


# create yanl file in c:\mongoadmin\config

mongod.conf

storage:
    dbPath: "c:/mongoadmin/data"

systemLog:
    destination: file
    path: "c:/mongoadmin/log/mongod.log"

# grand mongodb user a full access to c:/mongoadmin

icacls c:/mongoadmin /grant mongodb:(OI)(CI)F

# Mongod as windows service 

mongod --install --config c:/mongoadmin/config/mongod.conf --serviceUser mongodb --servicePassword easypassword

# check the mongodb service
sc qc mongodb

# start mongodb service 
net start mongodb


# connect to mongo 
mongo


## Remove mongodb service 

# stop service
net stop mongodb

# remove service unregister serive but data,log config still there  
mongod --remove 

```


## Stop/Start Mongo Safely 

### Linux Side

> Stopping MongoDB have several options 1- service stop  2- from Terminal CTRL+C or db.shutdownServer() using mognosh 3- kill [pid]

First Option safe way to start stop mongod.

```bash
 
sudo systemctl start mongod
sudo systemctl status mongod
sudo systemctl stop mongod

# after stop Mongo service check data Dir
# the size of mongod.lock is 0 that means 
# we have clean shutdown

[root@LNX-MONGODB mongo]# ls -lh  | grep mongod.lock
-rw-------. 1 mongod mongod  0 Jul 17 16:52 mongod.lock

```

Second Option use mongo client, marks as clean shutdown

```bash
# not you need as admin database to execute below func

mongo
> use admin
> db.shutdownServer()

[root@LNX-MONGODB mongo]# ls -lh  | grep mongod.lock
-rw-------. 1 mongod mongod  0 Jul 17 16:52 mongod.lock
```

Third way to send kill signal using linux kill command

```bash
#-------------------------------------------------
# Mongo its respect this kind of shutdown
cat mongod.lock # you will get the mongod process num
231332

#-------------------------------------------------
sudo kill 231332 # don't use kill -9 it will currupt db

#-------------------------------------------------
# check the mongod.lock 
[root@LNX-MONGODB mongo]# ls -lh  | grep mongod.lock
-rw-------. 1 mongod mongod  0 Jul 17 17:11 mongod.lock
# we can see that the mongod.lock doesn't have the 
# process after we killed the server.

#-------------------------------------------------
sudo tail -24  /var/log/mongodb/mongod.log
# you can see there is  clean shutdown sequence 

```

Unclean shutdown don't try this at production environment because you may lose data.

```bash
#-------------------------------------------------
# get mongod process num
cat mongod.lock 
232367

#-------------------------------------------------
# let's kill it with unclean kill
sudo kill -9 232367

#-------------------------------------------------
# check the mongod.lock 
[root@LNX-MONGODB mongo]# ls -lh  | grep mongod.lock
-rw-------. 1 mongod mongod  7 Jul 17 17:11 mongod.lock
# we can see that the mongod.lock still have the 
# process even after we have the server down.

#-------------------------------------------------
sudo tail -24  /var/log/mongodb/mongod.log
# you can see there is no clean shutdown sequence 

# ------------------------------------------------
# startup mongod after unclean shutdown  with new port 
# this will help to recover the databases and block
# application and users from connect to mongod
 
sudo mongod --port 4000 --dbpath /var/lib/mongodb

# ------------------------------------------------
# we need to check the mongod log file for any message
# like currupted rollback 
sudo cat  /var/log/mongodb/mongod.log | grep -i "recovering data"

#-------------------------------------------------
# we can see that mongod try to recover 
"ctx":"initandlisten","msg":"Recovering data from the last clean checkpoint."}

#-------------------------------------------------
# stop the mongod using ctrl + c 

#-------------------------------------------------
# start using service 
systemctl start mongod.service 


```

### Windows 

Stop start service in clean way  

```vbs
net stop mongod

dir data\

net start mongod

```

Force kill mongod process using task kill is not a clean way recovery is required 

>Caution: don't kill the process like this on any production it will cause MongoDB to crash

```bash
# if you did a force kill like below 
taskkill /F /IM mongod.exe

# you need to run mongod.exe as below 
mongod --port 40000 --dbpath .\data

# check the log if the recovery done

#then stop the mongod 
ctrl+c 

# start mongod service 
net start mongod 
```

Using mongo client, Make a clean shutdown

```bash
# not you need as admin database to execute below func

mongo
> use admin
> db.shutdownServer()

```

## Configurations

We installed the MongoDB database with minimal configurations , MongoDB  supports both  `YAML` format and `Key Value pair` syntax .