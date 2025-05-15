# Databricks notebook source
#To connect to ADLS G2 Here are the steps
#Create and APP registration in Active Directory
#Create a secret for the APP Registration
#Record the APP ID, the Tenant ID (for Azue Subscription) and Object ID -- these should all be visible when you create the App Registration
#Go to ADLS Gen 2 storage account
#Give that app Storage Blob Data Contributor Role (at the Storage account level not container)
#Use Storage explorer to connect to the ADLS G2 container
#Right click on the container and click manage access
#At the bottom put the APPID in the "Add User or Group" fill in box and make sure you select Read/Write Etc. Press Add
##Should work, if it doesn't... try the object ID. This part can also be coded using Azure CLI

##https://docs.databricks.com/data/data-sources/azure/azure-datalake-gen2.html



# COMMAND ----------

# MAGIC %scala
# MAGIC /*##can get the object ID with this code if needed
# MAGIC PS Azure:\> az ad sp show --id AppID
# MAGIC {
# MAGIC   "accountEnabled": "True",
# MAGIC   "addIns": [],
# MAGIC   "alternativeNames": [],
# MAGIC   "appDisplayName": "AppName",
# MAGIC   "appId": "AppID",
# MAGIC   "appOwnerTenantId": "TenantID",
# MAGIC   "appRoleAssignmentRequired": false,
# MAGIC   "appRoles": [],
# MAGIC   "applicationTemplateId": null,
# MAGIC   "deletionTimestamp": null,
# MAGIC   "displayName": "AppName",
# MAGIC   "errorUrl": null,
# MAGIC   "homepage": null,
# MAGIC   "informationalUrls": {
# MAGIC     "marketing": null,
# MAGIC     "privacy": null,
# MAGIC     "support": null,
# MAGIC     "termsOfService": null
# MAGIC   },
# MAGIC   "keyCredentials": [],
# MAGIC   "logoutUrl": null,
# MAGIC   "notificationEmailAddresses": [],
# MAGIC   "oauth2Permissions": [],
# MAGIC   "objectId": "ObjectID",
# MAGIC   "objectType": "ServicePrincipal",
# MAGIC   "odata.metadata": "https://graph.windows.net/TenantID/$metadata#directoryObjects/@Element",
# MAGIC   "odata.type": "Microsoft.DirectoryServices.ServicePrincipal",
# MAGIC   "passwordCredentials": [],
# MAGIC   "preferredSingleSignOnMode": null,
# MAGIC   "preferredTokenSigningKeyEndDateTime": null,
# MAGIC   "preferredTokenSigningKeyThumbprint": null,
# MAGIC   "publisherName": "Microsoft",
# MAGIC   "replyUrls": [],
# MAGIC   "samlMetadataUrl": null,
# MAGIC   "samlSingleSignOnSettings": null,
# MAGIC   "servicePrincipalNames": [
# MAGIC     "AppID"
# MAGIC   ],
# MAGIC   "servicePrincipalType": "Application",
# MAGIC   "signInAudience": "AzureADMyOrg",
# MAGIC   "tags": [
# MAGIC     "WindowsAzureActiveDirectoryIntegratedApp"
# MAGIC   ],
# MAGIC   "tokenEncryptionKeyId": null
# MAGIC }
# MAGIC */

# COMMAND ----------

# MAGIC %md
# MAGIC Connecting to ADLS Gen2
# MAGIC 
# MAGIC 
# MAGIC https://docs.databricks.com/data/data-sources/azure/azure-datalake-gen2.html

# COMMAND ----------

# MAGIC %scala
# MAGIC //This is how you comment in Scala
# MAGIC //"Long way" to connect to storage account and more proper
# MAGIC /* comment multiple lines
# MAGIC AppName
# MAGIC Application (client) ID
# MAGIC YOUR APPLICATIONID
# MAGIC (need to use Storage Explorer to give access to this objectID)
# MAGIC Directory (tenant) ID
# MAGIC YOUR TENANTID
# MAGIC Object ID
# MAGIC YOUR OBCJETID
# MAGIC key from blob storage
# MAGIC YOUR KEY FROM BLOB Storage
# MAGIC 
# MAGIC //object ID via power shell command 
# MAGIC //ecba365c-6f24-4f23-b507-88bbf0eac6c8
# MAGIC az ad sp show --id AppID
# MAGIC */
# MAGIC 
# MAGIC val storageAccountName = "StorageAccountName"
# MAGIC val appID = "AppID"
# MAGIC val password = "From Secret within your App Registration"
# MAGIC val fileSystemName = "ContainerName"
# MAGIC val tenantID = "TenantID"
# MAGIC //AD Subscription ID - This is the TenantID
# MAGIC 
# MAGIC spark.conf.set("fs.azure.account.auth.type." + storageAccountName + ".dfs.core.windows.net", "OAuth")
# MAGIC spark.conf.set("fs.azure.account.oauth.provider.type." + storageAccountName + ".dfs.core.windows.net", "org.apache.hadoop.fs.azurebfs.oauth2.ClientCredsTokenProvider")
# MAGIC spark.conf.set("fs.azure.account.oauth2.client.id." + storageAccountName + ".dfs.core.windows.net", "" + appID + "")
# MAGIC spark.conf.set("fs.azure.account.oauth2.client.secret." + storageAccountName + ".dfs.core.windows.net", "" + password + "")
# MAGIC spark.conf.set("fs.azure.account.oauth2.client.endpoint." + storageAccountName + ".dfs.core.windows.net", "https://login.microsoftonline.com/" + tenantID + "/oauth2/token")
# MAGIC spark.conf.set("fs.azure.createRemoteFileSystemDuringInitialization", "true")
# MAGIC dbutils.fs.ls("abfss://" + fileSystemName  + "@" + storageAccountName + ".dfs.core.windows.net/")
# MAGIC spark.conf.set("fs.azure.createRemoteFileSystemDuringInitialization", "false")

# COMMAND ----------

# MAGIC %md
# MAGIC Verifying that I can read files in ADLS Gen2 by putting data into a Dataframe

# COMMAND ----------

# MAGIC %scala
# MAGIC 
# MAGIC val df1 = spark
# MAGIC   .read
# MAGIC   .option ("header","True")
# MAGIC .option("charset", "UTF-8")
# MAGIC   .option ("inferschema","True")
# MAGIC   .csv("abfss://ContainerName@StorageAccountName.dfs.core.windows.net/Demo/Sales/dboAddresses_sales.txt")
# MAGIC 
# MAGIC display(df1)

# COMMAND ----------

##Same code in Python
##Shift + enter to execute

dfpy1 = (
  spark
  .read
  .option ("header",True)
  .option ("inferschema",True)
  .csv("abfss://ContainerName@StorageAccountName.dfs.core.windows.net/Demo/Sales/dboAddresses_sales.txt")
      )

##need to redefine df1 in python... not sure why?
df1=dfpy1

## can use this command: display(df1) or
dfpy1.show()

# COMMAND ----------

# MAGIC %md
# MAGIC Filtering and other queries with the data using Python

# COMMAND ----------

##Column names are case sensitive and so are dataframes and so are commands
##But Dataframe names are not
filteredDF = df1.filter(df1.City == "Washington").sort(df1.ZipCode)

display(filteredDF)

##Display(filteredDF) will not work
##display(FilteredDF) will not work
##filteredDF = df1.filter(df1.city == "Washington").sort(df1.zipCode)

# COMMAND ----------

##Aggregation
##from pyspark.sql.functions import countDistinct
from pyspark.sql.functions import *


CityStateCount = df1.select("City","State","CustomerID")\
  .groupBy("City","State")\
  .agg(countDistinct("CustomerID").alias("Count_of_DistinctCustomers_CitiesState"))\
  .orderBy(countDistinct("CustomerID"), ascending=False)
  
#.orderBy(df1.State,ascending=False)
#.sort(countDistinct("CustomerID"))

display(CityStateCount)

# COMMAND ----------

# MAGIC %md
# MAGIC Printing Schema

# COMMAND ----------

CityStateCount.printSchema()

# COMMAND ----------

# MAGIC %md
# MAGIC Importing all of my data files into Dataframes

# COMMAND ----------

#Python Code

import pyspark

SalesOutputPath = "abfss://ContainerName@StorageAccountName.dfs.core.windows.net/Demo/output/dboOrders_sales.parquet"

#From Sales Database
addressdata_Sales = spark.read.format('csv').options(header='true', inferschema='true').load("abfss://ContainerName@StorageAccountName.dfs.core.windows.net/Demo/Sales/dboAddresses_sales.txt")

customerdata_Sales = spark.read.format('csv').options(header='true', inferschema='true').load("abfss://ContainerName@StorageAccountName.dfs.core.windows.net/Demo/Sales/dboCustomers_sales.txt")

orderdata_Sales = spark.read.format('csv').options(header='true', inferschema='true').load("abfss://ContainerName@StorageAccountName.dfs.core.windows.net/Demo/Sales/dboOrders_sales.txt")

orderdetailsdata_Sales = spark.read.format('csv').options(header='true', inferschema='true').load("abfss://ContainerName@StorageAccountName.dfs.core.windows.net/Demo/Sales/dboOrderDetails_sales.txt")

#Marketing Data
customerdata_Marketing = spark.read.format('csv').options(header='true', inferschema='true').load("abfss://ContainerName@StorageAccountName.dfs.core.windows.net/Demo/Marketing/Customers.csv")

#Streaming Database
addressdata_Streaming= spark.read.format('csv').options(header='true', inferschema='true').load("abfss://ContainerName@StorageAccountName.dfs.core.windows.net/Demo/Streaming/dboAddresses_streaming.txt")

customerdata_Streaming= spark.read.format('csv').options(header='true', inferschema='true').load("abfss://ContainerName@StorageAccountName.dfs.core.windows.net/Demo/Streaming/dboCustomers_streaming.txt")

#import org.apache.spark.sql.types.StructType
from pyspark.sql.types import *
from pyspark.sql.functions import *
#Retail data
Retailschema = StructType([
    StructField("CustomerID", StringType(), True),
    StructField("FirstName", StringType(), True),
    StructField("LastName", StringType(), True),
    StructField("AddressLine1", StringType(), True),
    StructField("AddressLine2", StringType(), True),
    StructField("City", StringType(), True),
    StructField("State", StringType(), True),
    StructField("ZipCode", IntegerType(), True),
    StructField("PhoneNumber", LongType(), True),
    StructField("CreatedDate", TimestampType(), True),
    StructField("UpdatedDate", TimestampType(), True)],
)
##This file does not have proper headers, so I created a schema to load the Dataframe onto with proper column names
customerdata_Retail= spark.read.format('csv').schema(Retailschema).load("abfss://ContainerName@StorageAccountName.dfs.core.windows.net/Demo/Retail/dboCustomers.txt")
##note schema=MySchemaName

addressdata_Sales.printSchema()
customerdata_Sales.printSchema()
orderdata_Sales.printSchema()
orderdetailsdata_Sales.printSchema()
customerdata_Marketing.printSchema()
addressdata_Streaming.printSchema()
customerdata_Streaming.printSchema()
customerdata_Retail.printSchema()



# COMMAND ----------

# MAGIC %md
# MAGIC Creating Temporary Views so I can query that data with SQL

# COMMAND ----------

##SQL Conversion time
#Create Temp views from Python

addressdata_Sales.createOrReplaceTempView("View_addressdata_Sales")
customerdata_Sales.createOrReplaceTempView("View_customerdata_Sales")

customerdata_Marketing.createOrReplaceTempView("View_customerdata_Marketing")
addressdata_Streaming.createOrReplaceTempView("View_addressdata_Streamings")
customerdata_Streaming.createOrReplaceTempView("View_customerdata_Streaming")
customerdata_Retail.createOrReplaceTempView("View_customerdata_Retail")

orderdata_Sales.createOrReplaceTempView("View_orderdata_Sales")
orderdetailsdata_Sales.createOrReplaceTempView("View_orderdetailsdata_Sales")

# COMMAND ----------

# MAGIC %sql
# MAGIC --Let's use SQL to see our data using those temp views
# MAGIC 
# MAGIC select cs.CustomerID,cs.FirstName, cs.LastName, cs.PhoneNumber,sa.AddressLine1,sa.AddressLine2,sa.City,sa.State,sa.ZipCode 
# MAGIC from View_addressdata_Sales sa
# MAGIC inner join View_customerdata_Sales cs on sa.CustomerID=cs.CustomerID
# MAGIC Union All
# MAGIC select customerID,FirstName, LastName, PhoneNumber,AddressLine1,AddressLine2,City,State,ZipCode
# MAGIC from View_customerdata_Marketing
# MAGIC Union ALL
# MAGIC select cs.CustomerID,cs.FirstName, cs.LastName, cs.PhoneNumber,ads.AddressLine1,ads.AddressLine2,ads.City,ads.State,ads.ZipCode
# MAGIC from View_customerdata_Streaming cs inner join
# MAGIC View_addressdata_Streamings ads on cs.CustomerID=ads.CustomerID
# MAGIC union All
# MAGIC select CustomerID,FirstName, LastName, PhoneNumber,AddressLine1,AddressLine2,City,State,ZipCode
# MAGIC from View_customerdata_Retail
# MAGIC 
# MAGIC 
# MAGIC /**/

# COMMAND ----------

# MAGIC 
# MAGIC %sql
# MAGIC --create a temp view of the result set above
# MAGIC 
# MAGIC Create or Replace Temporary View CustomerData
# MAGIC as
# MAGIC select cs.customerID,cs.FirstName, cs.LastName, cs.PhoneNumber,sa.AddressLine1,sa.AddressLine2,sa.City,sa.State,sa.ZipCode , 'SalesDBSource' as SourceSystem
# MAGIC from View_addressdata_Sales sa
# MAGIC inner join View_customerdata_Sales cs on sa.customerid=cs.customerid
# MAGIC Union All
# MAGIC select customerID,FirstName, LastName, PhoneNumber,AddressLine1,AddressLine2,City,State,ZipCode, 'Marketing' as SourceSystem
# MAGIC from View_customerdata_Marketing
# MAGIC Union ALL
# MAGIC select cs.customerID,cs.FirstName, cs.LastName, cs.PhoneNumber,ads.AddressLine1,ads.AddressLine2,ads.City,ads.State,ads.ZipCode, 'Streaming' as SourceSystem
# MAGIC from View_customerdata_Streaming cs inner join
# MAGIC View_addressdata_Streamings ads on cs.customerid=ads.customerid
# MAGIC union All
# MAGIC select customerID,FirstName, LastName, PhoneNumber,AddressLine1,AddressLine2,City,State,ZipCode, 'Retail' as SourceSystem
# MAGIC from View_customerdata_Retail

# COMMAND ----------

# MAGIC %sql
# MAGIC select * from CustomerData

# COMMAND ----------

# MAGIC %sql
# MAGIC 
# MAGIC Create or Replace Temporary View SalesData
# MAGIC as
# MAGIC select os.orderID,CustomerID,date(OrderDate) as OrderDate,date(ShipDate) as ShipDate,TotalCost,MovieID,Quantity, UnitCost, LineNumber
# MAGIC from View_orderdata_Sales os inner join 
# MAGIC View_orderdetailsdata_Sales ods on os.orderid=ods.orderid

# COMMAND ----------

# MAGIC %sql
# MAGIC --Now, let's use SQL to see the combined number of customers from multiple data sets and how many live in each city/state Combination
# MAGIC -- and we will write it as a CTE!
# MAGIC WITH CityData
# MAGIC as
# MAGIC (
# MAGIC select City, State, Count(*) as CountOfCustomers
# MAGIC from CustomerData
# MAGIC Group by City, State
# MAGIC )
# MAGIC Select *
# MAGIC from CityData
# MAGIC Order by CountOfCustomers desc

# COMMAND ----------

# MAGIC %sql
# MAGIC --Map it by state
# MAGIC select State, Count(*) as CountOfCustomers
# MAGIC from CustomerData
# MAGIC Group by State
# MAGIC --

# COMMAND ----------

# MAGIC %md
# MAGIC Inserting Summarized data into my ADLS Gen2 Data Lake

# COMMAND ----------

###insert summarized data back into datalake

CustomerDataPath = "abfss://ContainerName@StorageAccountName.dfs.core.windows.net/Demo/Output/CustomerData.parquet"
SalesDataPath = "abfss://ContainerName@StorageAccountName.dfs.core.windows.net/Demo/Output/SalesData.parquet"

#this is great code below - works the same as the one above but does not need to have a dataframe created first

spark.sql("select * from CustomerData").write.option("compression","snappy").mode("overwrite").parquet(CustomerDataPath)
spark.sql("select * from SalesData").write.option("compression","snappy").mode("overwrite").parquet(SalesDataPath)


##similar functionality, different coding preference
#dfcustomerdata = spark.sql("select cs.FirstName, cs.LastName, cs.PhoneNumber,sa.AddressLine1,sa.AddressLine2,sa.City,sa.State,sa.ZipCode from View_addressdata_Sales sa inner join View_customerdata_Sales cs on sa.customerid=cs.customerid")

#.write

#(dfcustomerdata.write 
#    .option("compression","snappy")
#    .parquet(SalesOutputPath)
#)

# COMMAND ----------

# MAGIC %md
# MAGIC Writing my Data to Azure SQL Database/Azure SQL Managed Instance
# MAGIC 
# MAGIC 
# MAGIC 
# MAGIC https://docs.microsoft.com/en-us/azure/sql-database/sql-database-spark-connector   

# COMMAND ----------

# MAGIC %scala
# MAGIC 
# MAGIC /*
# MAGIC For documentation purposes only
# MAGIC These are the objects I created in my SQL Database
# MAGIC 
# MAGIC CREATE LOGIN databricks
# MAGIC 	WITH PASSWORD = 'password!' 
# MAGIC GO
# MAGIC 
# MAGIC Create Database Databrickslanding
# MAGIC Go
# MAGIC 
# MAGIC Use Databrickslanding
# MAGIC GO
# MAGIC 
# MAGIC CREATE USER databricks
# MAGIC 	FOR LOGIN databricks
# MAGIC GO
# MAGIC 
# MAGIC -- Add user to the database owner role
# MAGIC EXEC sp_addrolemember N'db_datareader', N'databricks'
# MAGIC GO
# MAGIC 
# MAGIC EXEC sp_addrolemember N'db_datawriter', N'databricks'
# MAGIC GO
# MAGIC 
# MAGIC Create Table CustomerDataSum
# MAGIC (
# MAGIC City varchar(100),
# MAGIC State varchar(3),
# MAGIC CountOfCustomers int
# MAGIC )
# MAGIC 
# MAGIC 
# MAGIC Create Table CustomerData
# MAGIC (
# MAGIC customerID varchar(100),
# MAGIC FirstName varchar(100),
# MAGIC LastName varchar(100),
# MAGIC PhoneNumber varchar(15),
# MAGIC AddressLine1 varchar(100),
# MAGIC AddressLine2 varchar(100),
# MAGIC City varchar(100),
# MAGIC State varchar(3),
# MAGIC ZipCode varchar(9),
# MAGIC SourceSystem varchar (100)
# MAGIC )
# MAGIC 
# MAGIC Create Table SalesData
# MAGIC (
# MAGIC orderID varchar(100),
# MAGIC customerID varchar(100),
# MAGIC OrderDate datetime,
# MAGIC ShiptDate datetime,
# MAGIC TotalCost Float,
# MAGIC MovieID varchar(100),
# MAGIC Quantity int,
# MAGIC UnitCost Float,
# MAGIC LineNumber int
# MAGIC )
# MAGIC 
# MAGIC create procedure [dbo].[usp_truncateData]
# MAGIC as
# MAGIC 
# MAGIC truncate table dbo.CustomerDataSum
# MAGIC Truncate Table CustomerData
# MAGIC Truncate Table SalesData
# MAGIC 
# MAGIC GO
# MAGIC 
# MAGIC GRANT EXECUTE on [dbo].[usp_truncateData] to Databricks
# MAGIC GRANT ALTER ON [dbo].[CustomerData] TO [databricks]
# MAGIC GRANT ALTER ON [dbo].[CustomerDataSum] TO [databricks]
# MAGIC GRANT ALTER ON [dbo].[SalesData] TO [databricks]
# MAGIC */

# COMMAND ----------

# MAGIC %scala
# MAGIC 
# MAGIC Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver")
# MAGIC 
# MAGIC //Regular Azure SQL
# MAGIC //val jdbcHostname = "AzureSQLServerName.database.windows.net"
# MAGIC //val jdbcPort = 1433
# MAGIC //val jdbcDatabase = "databrickslanding"
# MAGIC 
# MAGIC //Azure SQL MI
# MAGIC val jdbcHostname = "SQLMIServerName.public.UNIQUEADDRESS.database.windows.net"
# MAGIC val jdbcPort = 3342
# MAGIC val jdbcDatabase = "databrickslanding"
# MAGIC 
# MAGIC 
# MAGIC 
# MAGIC // Create the JDBC URL without passing in the user and password parameters.
# MAGIC val jdbcUrl = s"jdbc:sqlserver://${jdbcHostname}:${jdbcPort};database=${jdbcDatabase}"
# MAGIC 
# MAGIC // Create a Properties() object to hold the parameters.
# MAGIC import java.util.Properties
# MAGIC val connectionProperties = new Properties()
# MAGIC 
# MAGIC connectionProperties.put("user", s"databricks")
# MAGIC connectionProperties.put("password", s"password!")
# MAGIC 
# MAGIC val driverClass = "com.microsoft.sqlserver.jdbc.SQLServerDriver"
# MAGIC connectionProperties.setProperty("Driver", driverClass)
# MAGIC 
# MAGIC val dfCustomerDataSumSQL = spark.read.jdbc(jdbcUrl, "CustomerDataSum", connectionProperties)
# MAGIC //Spark automatically reads the schema from the database table and maps its types back to Spark SQL types.
# MAGIC 
# MAGIC 
# MAGIC dfCustomerDataSumSQL.printSchema
# MAGIC 
# MAGIC display(dfCustomerDataSumSQL)

# COMMAND ----------

# MAGIC %sql
# MAGIC 
# MAGIC Create or Replace Temporary View CustomerSumDataTemp
# MAGIC as
# MAGIC select City,State, Count(*) as CountOfCustomers
# MAGIC from CustomerData
# MAGIC Group by City,State

# COMMAND ----------

# MAGIC %scala
# MAGIC 
# MAGIC spark.table("CustomerSumDataTemp")
# MAGIC      .write
# MAGIC      .mode(SaveMode.Append) // <--- Overwrite the existing table neds special permissions (Create Table - because it drops and recreates)
# MAGIC      .jdbc(jdbcUrl, "CustomerDataSum", connectionProperties)

# COMMAND ----------

# MAGIC %scala
# MAGIC display(dfCustomerDataSumSQL)

# COMMAND ----------

# MAGIC %md
# MAGIC Another way to do it with Delta Lake and a Databricks "Database"

# COMMAND ----------

# MAGIC %md
# MAGIC Some cleanup first

# COMMAND ----------

# MAGIC %sql 
# MAGIC Create Database if NOT Exists AymanDB

# COMMAND ----------

# MAGIC %sql
# MAGIC drop table if exists aymanDB.customerdata_Streaming;
# MAGIC drop table if exists aymanDB.addressdata_Streaming;
# MAGIC 
# MAGIC drop table if exists aymanDB.customerdata_Sales;
# MAGIC drop table if exists aymanDB.addressdata_Sales;
# MAGIC 
# MAGIC drop table if exists aymanDB.customerdata_Marketing;
# MAGIC 
# MAGIC drop table if exists aymanDB.customerdata_Retail;
# MAGIC 
# MAGIC drop table if exists aymanDB.customers_Final;

# COMMAND ----------

# MAGIC %md
# MAGIC Creating a path in DBFS (Databricks File System)

# COMMAND ----------

dbutils.fs.rm('/DeltaTest/',True)

# COMMAND ----------

dbutils.fs.mkdirs('/DeltaTest/')

# COMMAND ----------

# MAGIC %md
# MAGIC Using the same Dataframes created above, we can write the same data to DELTA tables

# COMMAND ----------

##Insert data into Delta Lake Tables
customerdata_Sales.write.format("delta").save("dbfs:/DeltaTest/silver/customerdata_Sales")
spark.sql("CREATE TABLE aymanDB.customerdata_Sales USING DELTA LOCATION 'dbfs:/DeltaTest/silver/customerdata_Sales'")

addressdata_Sales.write.format("delta").save("dbfs:/DeltaTest/silver/addressdata_Sales")
spark.sql("CREATE TABLE aymanDB.addressdata_Sales USING DELTA LOCATION 'dbfs:/DeltaTest/silver/addressdata_Sales'")

customerdata_Streaming.write.format("delta").save("dbfs:/DeltaTest/silver/customerdata_Streaming")
spark.sql("CREATE TABLE aymanDB.customerdata_Streaming USING DELTA LOCATION 'dbfs:/DeltaTest/silver/customerdata_Streaming'")

addressdata_Streaming.write.format("delta").save("dbfs:/DeltaTest/silver/addressdata_Streaming")
spark.sql("CREATE TABLE aymanDB.addressdata_Streaming USING DELTA LOCATION 'dbfs:/DeltaTest/silver/addressdata_Streaming'")

customerdata_Marketing.write.format("delta").save("dbfs:/DeltaTest/silver/customerdata_Marketing")
spark.sql("CREATE TABLE aymanDB.customerdata_Marketing USING DELTA LOCATION 'dbfs:/DeltaTest/silver/customerdata_Marketing'")

customerdata_Retail.write.format("delta").save("dbfs:/DeltaTest/silver/customerdata_Retail")
spark.sql("CREATE TABLE aymanDB.customerdata_Retail USING DELTA LOCATION 'dbfs:/DeltaTest/silver/customerdata_Retail'")



# COMMAND ----------

# MAGIC %md
# MAGIC Create Gold Delta Lake Table

# COMMAND ----------

# MAGIC %sql
# MAGIC create table if not exists aymandb.customers_Final
# MAGIC (
# MAGIC CustomerID string,
# MAGIC FirstName string,
# MAGIC LastName string,
# MAGIC AddressLine1 string,
# MAGIC AddressLine2 string,
# MAGIC City string,
# MAGIC State String,
# MAGIC Zipcode String,
# MAGIC PhoneNumber String,
# MAGIC UpdatedDate timestamp,
# MAGIC SourceSystem string
# MAGIC ) 
# MAGIC using delta
# MAGIC OPTIONS (path 'dbfs:/DeltaTest/gold/customers_Final')
# MAGIC partitioned by (CustomerID)

# COMMAND ----------

# MAGIC %sql
# MAGIC select *
# MAGIC from aymandb.customers_Final
# MAGIC limit 20

# COMMAND ----------

# MAGIC %md
# MAGIC Take all the data and put it in the Gold table

# COMMAND ----------

# MAGIC %sql
# MAGIC Insert into aymanDB.customers_Final
# MAGIC select customerID,FirstName, LastName, AddressLine1,AddressLine2,City,State,ZipCode,PhoneNumber, current_date() as UpdatedDate, 'Marketing' as Source
# MAGIC from aymanDB.customerdata_Marketing
# MAGIC union All
# MAGIC select CustomerID,FirstName, LastName, AddressLine1,AddressLine2,City,State,ZipCode, PhoneNumber,current_date() as UpdatedDate, 'Retail' as Source
# MAGIC from aymanDB.customerdata_Retail
# MAGIC UNION ALL
# MAGIC select cs.CustomerID,cs.FirstName, cs.LastName, cs.PhoneNumber,sa.AddressLine1,sa.AddressLine2,sa.City,sa.State,sa.ZipCode,current_date() as UpdatedDate, 'Sales' as Source
# MAGIC from aymanDB.addressdata_Sales sa
# MAGIC inner join aymanDB.customerdata_Sales cs on sa.CustomerID=cs.CustomerID
# MAGIC Union ALL
# MAGIC select cs.CustomerID,cs.FirstName, cs.LastName, cs.PhoneNumber,ads.AddressLine1,ads.AddressLine2,ads.City,ads.State,ads.ZipCode,current_date() as UpdatedDate, 'Streaming' as Source
# MAGIC from aymanDB.customerdata_Streaming cs inner join
# MAGIC aymanDB.addressdata_Streaming ads on cs.CustomerID=ads.CustomerID

# COMMAND ----------

# MAGIC %sql
# MAGIC select *
# MAGIC from aymandb.customers_Final
# MAGIC limit 20

# COMMAND ----------

# MAGIC %sql
# MAGIC select SourceSystem, count(SourceSystem) as CountBySourceSystem
# MAGIC from aymandb.customers_Final
# MAGIC group by SourceSystem
