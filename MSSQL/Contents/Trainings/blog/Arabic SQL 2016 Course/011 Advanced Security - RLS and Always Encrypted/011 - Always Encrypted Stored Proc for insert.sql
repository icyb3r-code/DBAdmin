USE [AdventureWorksDW2014]
GO

/****** Object:  StoredProcedure [dbo].[pr_InsertCustomersEncryptedSSRS]    Script Date: 3/14/2016 8:18:09 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure [dbo].[pr_InsertCustomersEncryptedSSRS]
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


GO


