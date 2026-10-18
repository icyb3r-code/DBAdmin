
# SQL Server 2025 Setup \[Best Practices\]


## Introduction

In this video, I'm going to walk you through the complete installation of SQL Server 2025 on Windows Server 2025 — from zero to a fully running database engine.

Whether you're setting up a lab environment, a dev machine, or a production server, this guide will give you everything you need to do it right the first time.

Stick around until the end — because this video tutorial will save you hours of headaches down the road. And if you’re looking for something specific, feel free to skip around using the video chapters and jump directly to any section you want.

Let's get into it.
## System Requirements & SQL Server Editions

Before we touch the installer, let's make sure your server can actually run SQL Server 2025 and that you choose the right edition for your workload. Skipping this step is one of the most common reasons installations fail or perform badly.

SQL Server comes in different editions depending on your needs — from lightweight free versions to full enterprise-grade deployments.


| Edition              | Type            | Summary                                                                                     |
| -------------------- | --------------- | ------------------------------------------------------------------------------------------- |
| Enterprise           | Commercial      | Full-featured tier for mission-critical workloads with maximum resources and HA/DR support. |
| Standard             | Commercial      | Mid-tier option with capped resources (up to 32 cores, 256 GB RAM).                         |
| Express              | Free            | Lightweight free edition with 50 GB limit for small apps.                                   |
| Enterprise Developer | Free (Dev/Test) | Full Enterprise features for non-production use only.                                       |
| Standard developer   | Free (Dev/Test) | Mirrors Standard limits for realistic testing environments.                                 |

Now let’s quickly go over the system requirements so you know whether your environment is ready for installation:

|Component|Minimum Requirement|Recommended|
|---|---|---|
|Processor|x64 processor, 1.4 GHz|2.0 GHz or faster|
|Memory (Express Edition)|512 MB RAM|1 GB RAM|
|Memory (Other Editions)|1 GB RAM|4 GB+ (depending on workload)|
|Storage Space|6 GB available disk space|SSD or NVMe strongly recommended|
For this tutorial, we’ll be using the **Enterprise Developer Edition** installed on **Windows Server 2025**.
## Pre-Installation Best Practices

Most tutorials skip this part — but you shouldn’t. These pre-installation checks eliminate a large portion of the issues DBAs typically face on day one.

**Step 1: Update Windows Server**

Open Windows Update and install all pending updates. Reboot if required. SQL Server setup can fail or behave unexpectedly on  unpatched OS.

```
Start > Settings > Windows Update > Check for Updates
```
**Step 2: Configure Windows Firewall**

By default, SQL Server uses TCP port 1433 for the default instance, while the SQL Server Browser service listens on UDP port 1434. We need to allow both ports through Windows Firewall so remote clients can connect successfully.

```powershell
New-NetFirewallRule -DisplayName "SQLServer default instance" -Direction Inbound -LocalPort 1433 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "SQLServer Browser service" -Direction Inbound -LocalPort 1434 -Protocol UDP -Action Allow
```
In a lab environment, you can temporarily disable the firewall. Never do this in production.

**Step 3: Create a Local User and a Service Account**

Before installing SQL Server, we need to prepare the accounts that will be used for SQL Server services and administrative access. In environments without a Domain Controller, we can use either a Windows virtual account or a dedicated local user account.

Option 1: Virtual Account (Recommended for Beginners)

A virtual account is automatically managed by Windows and requires minimal configuration. By default, SQL Server runs under:

```powersehll
NT SERVICE\MSSQLSERVER
```

You can verify the service account after installation using:
```powershell
Get-Service MSSQLSERVER | Select Name, StartName, Status
```
Option 2: Local Service Account (Recommended for Lab and Small Environments)

For better isolation and management, you can create a dedicated local service account for SQL Server.
```powershell
$Password = ConvertTo-SecureString "Password123!" -AsPlainText -Force

New-LocalUser `
  -Name "svc_sqlserver" `
  -Password $Password `
  -FullName "SQL Server Service Account" `
  -PasswordNeverExpires

# add to "log on as a service"
secedit /export /cfg C:\secpol.cfg
# Local Security Policy  
# → Local Policies  
# → User Rights Assignment  
# → Log on as a service
# Add this account svc_sqlserver
```
Create a Local Windows User for SQL Server Authentication

If you plan to use Windows Authentication for SQL Server administration in a non-domain environment, you can also create a dedicated local administrative user instead of using the built-in Administrator account.

```powershell
$Password = ConvertTo-SecureString "Password123!" -AsPlainText -Force

New-LocalUser -Name "sqladmin" -Password $Password -FullName "SQL Server Administrator" -PasswordNeverExpires
```
Add the user to the local Administrators group:

```bash
Add-LocalGroupMember -Group "Administrators" -Member "sqladmin"
```
This account can later be added during SQL Server installation as a Windows administrator for SQL Server access.

**Step 4: Verify .NET Framework**

SQL Server 2025 requires .NET Framework 4.7.2 or later. On Windows Server 2025 this is already included, but verify it quickly:

```powershell
Get-WindowsFeature NET-Framework-45-Core
```

**Step 5: Check Disk Configuration**

SQL Server best practices recommend separating your data files (.mdf), log files (.ldf), and TempDB across different drives. Even in a lab, create separate folders to build the habit:

Testing Env:
```bash
D:\SQLData     — Data files

D:\SQLLogs     — Log files

D:\SQLBackup   — Backups

D:\SQLTempDB   — TempDB
```
Production Env:
```bash
D:\SQLData     — Data files

L:\SQLLogs     — Log files

B:\SQLBackup   — Backups

T:\SQLTempDB   — TempDB
```
**Step 6: Check Hostname & Network**

```powershell
hostname

Rename-Computer -NewName "SQL-SRV01" -Force -Restart

Get-NetIPInterface -AddressFamily IPv4 | Select-Object InterfaceAlias, Dhcp
```
## Download SQL Server 2025

Always download SQL Server directly from Microsoft. Never use third-party sites — this is critical for security.

[SQL Server 2025 Download Link](https://www.microsoft.com/en-us/sql-server/sql-server-downloads)

On the download page, scroll to the Enterprise Developer Edition and click Download Now. The installer is a small bootstrapper — it will download the full package during setup.

Once the download is complete, you'll have a file called SQLServer2025-x64-ENU-Dev.exe — the exact name may vary slightly by release.


## Installing SQL Server 2025

This is the main event. Follow along carefully — I'll explain not just what to click, but why each setting matters.

**Step 1 — SQL Server Installation Center**

The installer opens the SQL Server Installation Center. On the left menu, click Installation, then select New SQL Server stand-alone installation or add features to an existing installation.

![](attachments/Pasted%20image%2020260527155349.png)

**Step 2 — Product Key**

Select Developer Edition from the dropdown. No license key is required. Click Next.

![](attachments/Pasted%20image%2020260527155510.png)

**Step 3 — License Terms**

Accept the license terms and check Send feature usage data if you want to help Microsoft improve the product — this is optional. Click Next.

![](attachments/Pasted%20image%2020260527155555.png)

**Step 4 — Microsoft Update**

Check Use Microsoft Update to check for updates. This ensures SQL Server patches are included in your regular Windows Update cycle. Click Next.

![](attachments/Pasted%20image%2020260527155659.png)

**Step 5 — Install Rules**

Setup runs a quick health check on your system. Any warnings will show here. Pay attention to warnings about firewall rules and pending reboots. Click Next to continue.

![](attachments/Pasted%20image%2020260527160005.png)

**Step 6 — Feature Selection**

This is one of the most important screens. For a beginner DBA setup, select:

- Database Engine Services — the core SQL Server engine (required)
- SQL Server Replication — useful to install even if not used immediately
- Full-Text and Semantic Extractions for Search — optional, install if needed

![](attachments/Pasted%20image%2020260527160302.png)


Leave Analysis Services, Reporting Services, and Integration Services unchecked for now — those are separate tools we can add later.

**Step 7 — Instance Configuration**

You have two options here:

- Default Instance — SQL Server listens as MSSQLSERVER. You connect using just the server name or IP.
    
- Named Instance — SQL Server listens under a custom name like SQLSERVER2025. You connect using ServerName\InstanceName.
    
For beginners and single-server setups, choose Default Instance. Click Next.

![](attachments/Pasted%20image%2020260527160451.png)

**Step 8 — Server Configuration (Service Accounts)**

This is where we assign our service accounts. For the SQL Server Database Engine, set the account to:

- Virtual Account: NT SERVICE\MSSQLSERVER (recommended)
- Or your local svc_sqlserver account if you created one
    
Set Startup Type to Automatic for the Database Engine and SQL Server Agent.

Check Perform volume maintenance tasks for the SQL Server Database Engine service account — this enables Instant File Initialization and significantly speeds up data file creation.

![](attachments/Pasted%20image%2020260527160730.png)


**Step 9 — Database Engine Configuration**

This screen has three tabs — pay close attention.

Server Configuration tab:

- Authentication Mode: Choose Mixed Mode (SQL Server and Windows Authentication)
- Set a strong SA password — at least 12 characters with mixed case, numbers, and symbols
- Click Add Current User to add your Windows account as a SQL Server administrator

![](attachments/Pasted%20image%2020260527162835.png)
    
Data Directories tab:

- Data root directory: `D:\MSSQL17.MSSQLSERVER\MSSQL\Data`
- Log directory: `L:\MSSQL17.MSSQLSERVER\MSSQL\Log`
- Backup directory: `B:\MSSQL17.MSSQLSERVER\MSSQL\Backup`

![](attachments/Pasted%20image%2020260527162936.png)

TempDB tab:

- Set the number of TempDB data files to match your CPU core count (up to 8) 
- On Powershell run this to create dir `md T:\MSSQL17.MSSQLSERVER\MSSQL\Temp`
- TempDB directory: `T:\MSSQL17.MSSQLSERVER\MSSQL\Temp`

![](attachments/Pasted%20image%2020260527163047.png)

**Step 10 — Ready to Install**

Review the configuration summary. Everything look right? Click Install.

![](attachments/Pasted%20image%2020260527163142.png)

The installation will take between 5 and 15 minutes depending on your hardware. You'll see a progress bar for each component being installed.

When all items show a green checkmark, the installation is complete. Click Close.

![](attachments/Pasted%20image%2020260527180217.png)
## Install SQL Server Management Studio (SSMS)

Now that SQL Server is installed, we need a way to interact with it. That’s where SQL Server Management Studio, or SSMS, comes in. SSMS is Microsoft’s free graphical management tool that allows us to connect to SQL Server, run queries, manage databases, monitor performance, and administer the entire SQL Server environment.

[Download SSMS from Microsoft](https://learn.microsoft.com/en-us/ssms/install/install)

![](attachments/Pasted%20image%2020260527182403.png)

A server restart may be required after the SSMS installation is completed.

Now let’s connect to SQL Server 2025 using SSMS.

![](attachments/Pasted%20image%2020260527183104.png)

After all of that the SSMS connect to your local SQL Server:

![](attachments/Pasted%20image%2020260527183302.png)

## Post-Installation Configuration

The installation is complete — but a freshly installed SQL Server is like a brand-new car that still needs proper configuration before it’s ready for production. These post-installation steps help ensure your server is secure, stable, and optimized from the beginning.

**1. Enable the TCP/IP Protocol**

By default, the TCP/IP protocol may be disabled. To allow remote connections, open:

```
Start → SQL Server 2025 Configuration Manager
```

Then navigate to:

```
SQL Server Network Configuration→ Protocols for MSSQLSERVER
```

Right-click **TCP/IP** and select **Enable**.

After enabling the protocol, restart the SQL Server service for the changes to take effect.

**2. Configure SQL Server Agent**

SQL Server Agent is responsible for scheduled jobs, maintenance tasks, and alerts.

In SQL Server Management Studio, locate **SQL Server Agent** in Object Explorer, then right-click and select:

```
Start
```

It’s also recommended to configure the service to start automatically with Windows.

**3. Configure Maximum Server Memory**

By default, SQL Server can consume almost all available system memory. To maintain server stability, always reserve memory for the operating system and other processes.

Example:

```
EXEC sp_configure 'max server memory (MB)', 12288;RECONFIGURE;
```

In this example, SQL Server is limited to 12 GB of RAM on a server with 16 GB total memory.

A common best practice is to reserve approximately 10–20% of total RAM for the operating system.

**4. Create Your First User Database**

Avoid storing application data inside system databases. Instead, create a dedicated user database with separate data and log files.

```
CREATE DATABASE TestDB;
```

This structure provides better organization, easier maintenance, and improved performance management.

## Testing the SQL Server

Before we call this server production-ready — or even lab-ready — let's run through a quick checklist to verify everything is working correctly.

**Test 1 — Verify SQL Server Version**

```
SELECT @@VERSION;
```

You should see Microsoft SQL Server 2025 with the build number. Screenshot this — it's useful for support tickets.

**Test 2 — Check All Services Are Running**

```
SELECT servicename, status_desc, startup_type_desc FROM sys.dm_server_services;
```

**Test 3 — Verify Databases Are Online**

```
SELECT name, state_desc, recovery_model_desc FROM sys.databases;
```

All system databases (master, model, msdb, tempdb) should show ONLINE.

**Test 4 — Test a Basic Query**

```
USE TestDB;

CREATE TABLE dbo.TestTable (ID INT IDENTITY(1,1), Name NVARCHAR(50), CreatedDate DATETIME DEFAULT GETDATE());

INSERT INTO dbo.TestTable (Name) VALUES ('SQL Server 2025 Test');

SELECT * FROM dbo.TestTable;
```

**Test 5 — Verify Max Memory Setting**

```
EXEC sp_configure 'max server memory (MB)';
```

**Test 6 — Check Error Log for Issues**

```
EXEC xp_readerrorlog 0, 1, NULL, NULL, NULL, NULL, 'DESC';
```

Look for any ERROR or WARNING entries. Informational messages about SQL Server starting are normal.

## Troubleshooting

Let's cover the most common issues you'll hit during or after installation.

**Error: SQL Server service fails to start**

Check the Windows Event Log and SQL Server Error Log:

```
Event Viewer > Windows Logs > Application > Filter by Source: MSSQLSERVER
```

Common causes: incorrect service account permissions, corrupt installation media, or a port conflict. Verify TCP port 1433 is not in use by another application:

```
netstat -ano | findstr :1433
```

**Error: Cannot connect to SQL Server from SSMS**

Follow this diagnostic sequence:

- Verify SQL Server is running: Services.msc > SQL Server (MSSQLSERVER)
- Verify TCP/IP is enabled in SQL Server Configuration Manager
- Verify port 1433 is open in Windows Firewall
- Try connecting with localhost\MSSQLSERVER or 127.0.0.1,1433
    

**Error: Login failed for user (Error 18456)**

This is the most common SQL Server error. The cause depends on the State number in the error log:

- State 5: Invalid username
- State 8: Wrong password
- State 11 or 12: Valid login, but blocked at server or database level
    

```
EXEC xp_readerrorlog 0, 1, N'Login failed';
```

**Error: Setup failed during installation**

Review the SQL Server setup log files located at:

```
C:\Program Files\Microsoft SQL Server\160\Setup Bootstrap\Log\
```

The Summary.txt file will point you to the exact failure. Search for 'error' in the most recent Detail.txt file.

**Error: TempDB won't start**

If TempDB is on a drive that doesn't exist or has insufficient space, SQL Server won't start at all. Boot in minimal configuration mode and fix the path:
```
sqlservr.exe -f -T3608
```

