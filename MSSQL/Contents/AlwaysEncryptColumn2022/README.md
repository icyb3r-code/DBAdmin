

# Always Encrypted - Column 

## 1 - Encryption Terminology

- Encrypt & Decrypt : Encrypt - Hide the data from plain view, Decrypt - uncoding the data so you can see the hiden data.
- Certificates: digitally signs that security object and it contains public and sometimes private key
- Keys: keys are going to unlock and lock and protect that data. so we have key and key to protect that key.
- Vaults: is a key store that keep you key safe inside.

## 2- Type of Encryption 

Type |  Usage | Things to Note 
--------- | -------- | ------------ |
Transparent Data Encryption (TDE) | Database Level | Data at rest, Decrypted While in motion from memory to storage Processor|
Column Level Encryption | Column Level | DBA can Get to Data, SQL knows the keys|
Dynamic Data Masking | Column Level | Not Really Encryption|
Always Encrypted | Column Level | Encrypted Everywhere from Anyone Encrypted at rest in motion and in use |

## 3- What is AE and how it works?

AE (Always Encrypted) was created and brought to us in sql server 2016 and its available to you in **Standard Edition**  and there is no code changes required in order to use it which is fantastic , it can block DBA's from reading crucial data.

How that works, it's encrypted when it's sent to the application and it's decrypted using those keys and brought back to the application layer to decipher it using the .Net Dirvers or any other Always Encrypted dirvers available out there. 

## 4- Type of AE.

There are two types of Always Encrypted options available:

### 4.1- Deterministic 

- Predictable patterns: same value have same encrypted format, which allow the other to predict the value of that rows.
- Where, Group by and Join clauses are supported by using this type
- Indexes are supported, beacuse the pattern matching which is still less secure but encrypted.

### 4.2- Randomize

- Not Predictable pattern: no pattern matching 
- More Secure: cant predicte the value using pattern matching.
-  Non-Searchable data

Summarize: the usage of Randomize type when you want to encypte small data such as gender (M,F), but in case of the Deterministic can be used with larg amount of data


## 5- AE Gotchas

limitation of the AE if it's implemented on SQL Server

- Distributed Queries 
- No Default or check Constratints 
- No Partition Columns 
- Columns Reference computed Columns
- No Transactional/Merge Replication
- Aggregations 
- Columns with the Identity property
- No Triggers 

## 6- Type Of Keys

### 6.1- Column Encryption Key 

- Content Encryption Keys 
- 1 or more columns 
- Encrypted by Column Master Key 
- Column Encryption Key metadata Strored in Databsae.

### 6.2- Column Master Key

- Protects CEK 
- Must be stored in Trusted Key Store.
- Database only contains metadata of CMK keystore and location only.
- sys.column_master_keys

## 7- Storing Keys

### 7.1- Windows Certificate Store 

- Current Account
- Local Computer 
- Service 

### 7.2- Azure Key Vault

You can Store the CMK on azure vault, you need azure subscribtion  and reliable internet connection.






