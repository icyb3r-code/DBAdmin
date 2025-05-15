# MSSQL  Server 2019 Stand-Alone Installation Guide 


## Agenda

* Disk Volumes and partitions
* SQL Server 2019 installation
* Enable TCP/IP Network 
* Change Default Port
* SQL Server management Studio (SSMS).

## Disk Volumes and Partitions

The SQL Server Data Disk should be on separate volume Disk from Windows Operating System Volume disk not a partition disk of it check below screenshot: 

![](attachments/Pasted%20image%2020230821232804.png)

Bring the Disk online and initialize the Disk:

![](attachments/Pasted%20image%2020230821233150.png)

Format the disk and name it as shown below in screenshot:

![](attachments/Pasted%20image%2020230821234057.png)

The Final Disk Creation should be like below screenshot:

![](attachments/Pasted%20image%2020230821234547.png)


## SQL Server 2019 installation

Mount the ISO file media and click on **setup**

![](attachments/Pasted%20image%2020230821235711.png)

Select **Installation** and click on **New SQL Server Stand-alone Installation**


![](attachments/Pasted%20image%2020230822000253.png)

Since we are installing the SQL server for Development we can Keep this free edition **Developer**

![](attachments/Pasted%20image%2020230822000418.png)

**Accept** the License Terms

![](attachments/Pasted%20image%2020230822000456.png)

If there is an internet connection during the installation you can Check for update, then Click **Next**: 

![](attachments/Pasted%20image%2020230822000533.png)

Warning regarding the Windows firewall, reminds you, that you need to open a Firewall role to accept the inbound traffic, Click **Next**:

![](attachments/Pasted%20image%2020230822000816.png)

Select the Features you need to install, if you need only database, Pick only **Database Engine Service**, and click **Next**:

![](attachments/Pasted%20image%2020230822000907.png)

Keep the Default instance name, and click **Next**:

![](attachments/Pasted%20image%2020230822000956.png)

Check the Box **Grant Perform Volume Maintenance Task Privilege**:

![](attachments/Pasted%20image%2020230822001059.png)

Check the collation, and click **Next**:

![](attachments/Pasted%20image%2020230822001225.png)

Select **Mixed Mode** fill the password, and click on **Add Current User**:

![](attachments/Pasted%20image%2020230822024655.png)

Create a Directory to Empty **Data Disk** called **MSSQLData**:

![](attachments/Pasted%20image%2020230822001605.png)


![](attachments/Pasted%20image%2020230822001653.png)

Check the Temp DB datafiles location: 

![](attachments/Pasted%20image%2020230822001754.png)

Summary of all selection that you made, you can verify and continue to installation by click **Install** 

![](attachments/Pasted%20image%2020230822001850.png)

The installation Process will start as shown below: 

![](attachments/Pasted%20image%2020230822002111.png)

Once the installation completed successfully you should have similar to below screenshot: 

![](attachments/Pasted%20image%2020230822002616.png)

## Enable TCP/IP Network

By default SQL Server remote TCP connection is **disabled** to enable it you need to use **SQL Server 2019 Configuration Manager** :

![](attachments/Pasted%20image%2020230822002759.png)

Select **Protocols for MSSQLSERVER** then enable **TCP/IP** as shown in the screenshot

![](attachments/Pasted%20image%2020230822002913.png)

## Change Default Port Number

The default port for SQL Server instance is **1433**, but sometime for security reasons we need to change the port number something else, in our case we need to change it to **21433** 

![](attachments/Pasted%20image%2020230822002955.png)

After all the changes we made, the restart of **MSSQLSERVER** instance is must, follow the screenshot to accomplish that: 

![](attachments/Pasted%20image%2020230822003053.png)

Verify the listening port, by using `netstat` command, as shown in screenshot: 

![](attachments/Pasted%20image%2020230822003218.png)


## SQL Server management Studio (SSMS)

To manage SQL Server you need a tool to do that, SSMS is GUI tool, that helps you to manage the users, backup, creating objects and more, below steps to install this tool. To download [SSMS](https://learn.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms?view=sql-server-ver16)

![](attachments/Pasted%20image%2020230822005325.png)

Select the default location to install the SSMS tool, otherwise you can keep the default location and click install: 

![](attachments/Pasted%20image%2020230822003707.png)

The installation progress: 

![](attachments/Pasted%20image%2020230822003726.png)

Once the Installation completed, a success message should appear, sometime may required a restart for the OS: 

![](attachments/Pasted%20image%2020230822004518.png)

Done, now you have a stand-alone SQL server 2019 with SSMS installed and ready to function. 