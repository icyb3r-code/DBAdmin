
Use RowLevelSecurity
go

CREATE FUNCTION RowSec.fn_SecretClearance(@ClearanceLevel int)
    RETURNS TABLE
WITH SCHEMABINDING
AS
    RETURN SELECT 1 AS Acess_Result
	from RowSec.Users 
WHERE  LoginName=User_Name() and ClearanceLevelNumber >= @ClearanceLevel;


----create after the function is created

CREATE SECURITY POLICY RowSec.SensitiveData
ADD FILTER PREDICATE RowSec.fn_SecretClearance(ClearanceLevelNumber) ON dbo.ImportantData
WITH (STATE = ON);


---Allows for security policy to be turned off without dropping related objects
Alter SECURITY POLICY RowSec.SensitiveData
WITH (State = OFF)


---Clean up
Drop Security Policy RowSec.SensitiveData
Drop Function RowSec.fn_SecretClearance

