


# AlwaysOn Availability Groups - SQL 2019

## 1- Installation Requirements


## 2- Prerequisites

Before implementing your AlwaysOn Availability Group (AG), make sure you have everything in your environment ready to go.  There are several prerequisites that need to be addressed to ensure a successful deployment.

**Windows**

-   Do not install AlwaysOn on a domain controller
-   The operating system must be Windows 2012 or later
-   Install all available Windows hotfixes on every server (replica)
-   Windows Server Failover Cluster (WSFC) must be installed on every replica

**SQL Server**

-   Each server (replica) must be a node in the WSFC
-   No replica can run Active Directory services
-   Each replica must run on comparable hardware that can handle identical workloads
-   Each instance must run the same version of SQL Server, and have the same SQL Server collation
-   The account that runs SQL Services should be a domain account

**Network**

-   It is recommended to use the same network links for communication between WSFC nodes and AlwaysOn replicas

**Databases in the AG**

-   user databases (no system databases)
-   read/write
-   multi-user
-   AUTO_CLOSE disabled
-   full recovery mode
-   not configured for database mirroring

For a complete and detailed explanation of prerequisites:  [ go here](https://docs.microsoft.com/en-us/sql/database-engine/availability-groups/windows/prereqs-restrictions-recommendations-always-on-availability?view=sql-server-ver15)


## 3- Create Windows Server Failover Cluster (WSFC) 

Open Failover Cluster Manager and click on create Cluster:


![](attachments/Pasted%20image%2020221112163853.png)

Click on Next 

![](attachments/Pasted%20image%2020221112163946.png)


Add the nodes to that you want join them for cluster configuration then click next 

![](attachments/Pasted%20image%2020221112164120.png)

Add a Cluster Name and add unused IP address then click next 

![](attachments/Pasted%20image%2020221112164241.png)

Below window will show up and you can click next

![](attachments/Pasted%20image%2020221112164403.png)

Create New Cluster process should start 

![](attachments/Pasted%20image%2020221112164515.png)

Once the creation porcess finished, you can check the summary, view report if the installation finished successfully you can click on Finish:

![](attachments/Pasted%20image%2020221112164650.png)

Check Nodes status by click on Nodes:

![](attachments/Pasted%20image%2020221112164839.png)


Now we have WSFC installed and ready for SQL Server Always on Availability Group configuration



## 4- Install Windows SQL Server

We have two nodes we need to install Windows OS 2019 Standard Edition on top of them.

Download sql server 2019 Developer Edition as ISO file  from Microsoft  website:

You can mount the ISO and click on setup to start the installation as shown below in screenshot:


![](attachments/Pasted%20image%2020221112165317.png)

The **SQL Server Installation Center** Window will show up click on **Installation**:

![](attachments/Pasted%20image%2020221112165551.png)



![](attachments/Pasted%20image%2020221112165633.png)


![](attachments/Pasted%20image%2020221112165720.png)




![](attachments/Pasted%20image%2020221112165750.png)


![](attachments/Pasted%20image%2020221112165820.png)

![](attachments/Pasted%20image%2020221112165932.png)

![](attachments/Pasted%20image%2020221112170031.png)

![](attachments/Pasted%20image%2020221112170126.png)


![](attachments/Pasted%20image%2020221112170256.png)


![](attachments/Pasted%20image%2020221112170330.png)


![](attachments/Pasted%20image%2020221112170405.png)

![](attachments/Pasted%20image%2020221112170437.png)


![](attachments/Pasted%20image%2020221112170502.png)

![](attachments/Pasted%20image%2020221112170529.png)


![](attachments/Pasted%20image%2020221112170558.png)

![](attachments/Pasted%20image%2020221112170639.png)

![](attachments/Pasted%20image%2020221115093842.png)


## 5- Configure SQL Server 


Enable TCP/IP Connection

![](attachments/Pasted%20image%2020221115102400.png)

Select yes as shown below and click apply

![](attachments/Pasted%20image%2020221115102440.png)

The change will not take any effect until you restart the sql server service.

Check TCP port that sql server listening on by default should be 1433 :


![](attachments/Pasted%20image%2020221115102752.png)


Create Organization unit called **DBMS**. under this **(OU)** create user called **sqladmin** below show how to create this user

![](attachments/Pasted%20image%2020221115103240.png)


set a complex password and remove the password expires because this will be used as sql server service account.

![](attachments/Pasted%20image%2020221115103346.png)

Click on finish 

![](attachments/Pasted%20image%2020221115103636.png)

Go to sql server configuration manager and change SQL Server Properties use the user sqladmin as account as shown below:


![](attachments/Pasted%20image%2020221115110646.png)

Enable the always on availability groups 

![](attachments/Pasted%20image%2020221115110800.png)

Apply the changes will cause the service to be restarted 



![](attachments/Pasted%20image%2020221115110942.png)


Change the SQL Server Agent properties as shown below:

![](attachments/Pasted%20image%2020221115111132.png)


Restart both services 

![](attachments/Pasted%20image%2020221115111414.png)


Do the same steps for second node 


## 6- Install SSMS Management Studio


Download the SSMS software from Microsoft website and move the binary to both nodes. 

Start the SSMS installation as shown below

> Note that you can change the installation location to different location best practice to install it on different drive


![](attachments/Pasted%20image%2020221115114932.png)

then the installation will start as shown below in screenshot 

![](attachments/Pasted%20image%2020221115115123.png)

Close the windows once the setup completed 

![](attachments/Pasted%20image%2020221115115326.png)


From first node start the SSMS, and you should have window shows up as shown below:

Press connecto to connect to sql server database.

![](attachments/Pasted%20image%2020221115115600.png)

After you connect, you can see the **Object Explorer** : 

![](attachments/Pasted%20image%2020221115123650.png)

Create Database 

![](attachments/Pasted%20image%2020221115123753.png)

Enter Database name

![](attachments/Pasted%20image%2020221115123852.png)

you can see the new database in Object Explorer

![](attachments/Pasted%20image%2020221115123931.png)

take full backup for this database.

![](attachments/Pasted%20image%2020221115124042.png)


Click Ok as shown in below screenshot 

![](attachments/Pasted%20image%2020221115124148.png)

Message box shows that the backup finish successfully 

![](attachments/Pasted%20image%2020221115124239.png)


Database should be in full recovery mode you can check this by select database and right click and select properties as shown below in screenshot:


![](attachments/Pasted%20image%2020221115124432.png)



![](attachments/Pasted%20image%2020221115142146.png)



![](attachments/Pasted%20image%2020221115142246.png)


![](attachments/Pasted%20image%2020221115142341.png)

![](attachments/Pasted%20image%2020221115142417.png)



![](attachments/Pasted%20image%2020221115142618.png)




![](attachments/Pasted%20image%2020221115142750.png)


![](attachments/Pasted%20image%2020221115143045.png)


![](attachments/Pasted%20image%2020221115143129.png)

![](attachments/Pasted%20image%2020221115143202.png)


![](attachments/Pasted%20image%2020221115143224.png)


![](attachments/Pasted%20image%2020221115143837.png)

Once the availability groups finish you can expand the group and check the configuration 

![](attachments/Pasted%20image%2020221115144035.png)


## 7- Monitor The AG Databases 

===> TODO 

