-- 
-- Create Master Key
-- 

USE [AdventureWorksDW2014]
CREATE COLUMN MASTER KEY [ADWCMK]
WITH
(
	KEY_STORE_PROVIDER_NAME = N'MSSQL_CERTIFICATE_STORE',
	KEY_PATH = N'LocalMachine/My/FF5FBC30EE5794D65FCCE6C2E59CEA49563D8614'
)

GO

/*Previously created it under current user instead of local machine, caused some interesting issues

CREATE COLUMN MASTER KEY [ADWCMK]
WITH
(
	KEY_STORE_PROVIDER_NAME = N'MSSQL_CERTIFICATE_STORE',
	KEY_PATH = N'CurrentUser/My/5F7308764CABA887F143FC2CB8A231D5FC1B62A2'
)

GO
*/
-- 
-- Create Column Encryption Key
-- 

USE [AdventureWorksDW2014]
GO
CREATE COLUMN ENCRYPTION KEY [ADWCEK]
WITH VALUES
(
	COLUMN_MASTER_KEY = [ADWCMK],
	ALGORITHM = 'RSA_OAEP',
	ENCRYPTED_VALUE = 0x016E000001630075007200720065006E00740075007300650072002F006D0079002F00350066003700330030003800370036003400630061006200610038003800370066003100340033006600630032006300620038006100320033003100640035006600630031006200360032006100320033E8DD23A7D7BB7DE21C7595F45D71C7782A0A78ABC6ADEC69D0B10600121275B1DA24158982F9788CD08CD853CFA1E7D44D5B5C0C8794AF12DE187F368C0B64C04E06BDB3C4DB300D2A106F3FE08A49202B47134133C250D389CA157E254A1163E94C865AEBD745250BB6E65E47962CE70BFFEE7CFE0EE4D78C1925502A3F3D47C9CE2EC863EE7E064D592A998DEEDC61E8A2649D4628551F2A77F978E900BB21E758B514F007EC0C714F806A1CA7AD62E30844B4E3FAA29C82E87DA49324E64F1BBCE55CA418CC1DAD8175E3EBFA217681BDAB5C45759DE54881327B909F8EDB3AA22C511509A8AA48400C345C1792564512655CEEDBA7CDB50A8178BFE601000CCB011AAD54E3920747BC50C0E8B862E1D4D8A6BAAB1649DB712059CF702A80314E6F87FA032A5DCC102E861B521292B451F2FA8BC3D84D23130894F32147EB673D80800E80355B7C6168BC276BDA4913A511ED41C4AC1237B3054A833E22DEFB08C8D6CBC43A25F971309C92C913D268B9F7FC2A6A371072BFF9083EE5E21C045F3B4ECFDBEBA30CB33E200F2D8FD57908F7E6EDCB00A183E240A242040AAEC39565800C738C0D02CAC17B8A563428529BEC3EEAFE6C9B09EDB3143C2C81F5F24859A951D2D904B167BA26CA33A28599C9CBEF8BFCAB65902BBE3FC2F54A1633977D01DB7FEAD74682E63CB561A5AF911B69ECAFB87F8BB5C4F4486CC3EF
)

GO


---Copy Customer Table and create encrypted Column for SSN
SELECT * into dbo.CustomersEncrypted
FROM dbo.DimCustomer

--
-- Add Column to the table that we want to encrypt
--

ALTER TABLE CustomersEncrypted ADD [SSN] [nvarchar](11) COLLATE Latin1_General_BIN2 

--Update CustomersEncrypted
--SET SSN = CustomerKey+'123'

Update CustomersEncrypted
SET SSN = CustomerKey*10000


--Update CustomersEncrypted
--SET SSN = '123-45-6789'

Select *
from CustomersEncrypted

--Now Encrypt it with the CEK
--Doesn't work currently
--Can copy it to another table
ALTER Table CustomersEncrypted ADD
[SSN] [nvarchar](11) COLLATE Latin1_General_BIN2  
ENCRYPTED WITH (COLUMN_ENCRYPTION_KEY = [ADWCEK], ENCRYPTION_TYPE = Deterministic, ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256') NULL;

---Random is the other option

Select *
from CustomersEncrypted
where SSN = '123-45-6789'

---
Declare @ssn varchar(11)
Set @ssn = '111-22-3333'

Select *
from CustomersEncrypted
where SSN = @ssn

--Won't work, must be run by an application
USE [AdventureWorksDW2014]
GO

Declare @ssn varchar(11)
Set @ssn = '111-22-3333'

INSERT INTO [dbo].[CustomersEncrypted]
           ([GeographyKey],[CustomerAlternateKey],[FirstName],[LastName],[SSN])
     VALUES
           (26,'AW00091000','Test','Encrypted',@ssn)


--To allow @ssn parameter in report
GRANT VIEW ANY COLUMN MASTER KEY DEFINITION to SQLUser
GRANT VIEW ANY COLUMN ENCRYPTION KEY DEFINITION to SQLUser


USE [master]
GO
CREATE LOGIN [SQLUser] WITH PASSWORD=N'password', 
DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
GO

Use AdventureWorksDW2014
GO
CREATE USER SQLUser
	FOR LOGIN SQLUser
	WITH DEFAULT_SCHEMA = dbo
GO

-- Add user to the database owner role
EXEC sp_addrolemember N'db_datareader', N'SQLUser'
GO

GRANT EXECUTE ON [dbo].[pr_InsertCustomersEncryptedSSRS] to SQLUSER


---Data Masking Demo
---
---

ALTER Table dbo.CustomersEncrypted
ALTER COLUMN EmailAddress [varchar](50) MASKED WITH (FUNCTION = 'email()') NULL


Execute as User = 'dbo'
select *
from dbo.CustomersEncrypted
Revert;


Execute as User = 'SQLUser'
select *
from dbo.CustomersEncrypted
Revert;

--Add masking programatically


GRANT UNMASK TO SQLUser;

EXECUTE AS USER = 'SQLUser'
SELECT * FROM dbo.CustomersEncrypted
REVERT; 

-- Removing the UNMASK permission
REVOKE UNMASK TO SQLUser;

REVOKE UNMASK TO dbo;

---Trace Flags 209 and 219 are Required
--Trace flags 209 and 219 are required to use the Dynamic Data Masking feature in SQL 2016 CTP 2:  DBCC TRACEON(209, 219, -1);


---Clean Up
USE [AdventureWorksDW2014]
/****** Object:  ColumnMasterKey [ADWCMK]    Script Date: 1/25/2016 7:24:18 AM ******/
DROP COLUMN MASTER KEY [ADWCMK]
GO

DROP COLUMN ENCRYPTION KEY [ADWCEK]
GO

Drop Table [dbo].[CustomersEncrypted]


/*notes

Column Encryption Setting=enabled;

GRANT VIEW ANY COLUMN MASTER KEY DEFINITION TO database_user;
GRANT VIEW ANY COLUMN ENCRYPTION KEY DEFINITION TO database_user;
*/


/* SP for insertion through SSRS????

Procedure pr_InsertCustomersEncryptedSSRS
@ssn nvarchar(11)
as

--Declare @ssn varchar(11)
--Set @ssn = '111-22-3333'

INSERT INTO [dbo].[CustomersEncrypted]
          ([GeographyKey],[CustomerAlternateKey],[FirstName],[LastName],EmailAddress,[SSN])
    VALUES
         (26,'AW00091000','Test','Encrypted','Test@Encrypted.com',@ssn)

Select *
from dbo.CustomersEncrypted
where SSN= @ssn

Go


Grant Execute on pr_InsertCustomersEncryptedSSRS to SQLUser

12345678910
12345678911
12345678912


exec pr_InsertCustomersEncryptedSSRS '12345678913'

***Works!!

*/