

Use RowLevelSecurity
go
---Create new schema for tables/functions related to rowlevel security  **recommended**
Create Schema RowSec
go
--Create a table with sensative data
Create Table ImportantData
(
UserID  Int Identity(10000,1),
FirstName  varchar(50),
LastName  varchar(50),
SSN  varchar(9),
ClearanceLevelNumber int
)
go


---Insertion of random data

Insert into ImportantData values ('FName'+cast(scope_identity() as varchar(5)),'LName'+cast(SCOPE_IDENTITY() as varchar(5)),CAST(RAND()*1000000000 as int),3)
go 20


---updating sensative data to have different levels of clearance
Update ImportantData
set ClearanceLevelNumber = 2
where UserID < 10005

Update ImportantData
set ClearanceLevelNumber = 1
where UserID = 10007

Update ImportantData
set ClearanceLevelNumber = 0
where UserID > 10013


--Check data
Select *
from ImportantData


---Create a table with user and user clearance information.
---Login name represents the database user id
Create Table RowSec.Users
(
LoginName varchar(50),
ClearanceLevel varchar(50),
ClearanceLevelNumber int
)

---Inserting user information and clearance levels
Insert into RowSec.Users Values('User1','Top Secret',3),('User2','Secret',2),('User3','Confidential',1), ('User4','None',0)


---verify that the user name matches the username in the security table
Select *,USER_NAME(),SUSER_NAME()
from RowSec.Users

select *,User_name()
from ImportantData

---Run these scripts before and after creating the security policy

--Results: before security policy is applied this should bring back ALL data
--Results: after security policy is applied this should bring back NO data
--**** Even DBO does not have access to the data since row-level security is based on the users in the security table****
Execute as USER = 'dbo'
select *,user_name()
from ImportantData
revert;

--Results: before security policy is applied this should bring back ALL data
--Results: after security policy is applied this should bring back data that the user has clearance for. 
--Since this user has Secret clearance, only data that is Secret level or below should be returned.
Execute as USER = 'User1'
select *,user_name()
from ImportantData
revert;

--Results: before security policy is applied this should bring back ALL data
--Results: after security policy is applied this should bring back data that the user has clearance for. 
--Since this user has Confidential clearance, only data that is Confidential level or below should be returned.
Execute as USER = 'User2'
select *,user_name()
from ImportantData
revert;

--Results: before security policy is applied this should bring back ALL data
--Results: after security policy is applied this should bring back data that the user has clearance for. 
--Since this user has NO clearance, only data that is Not Sensative should be returned.
Execute as USER = 'User3'
select *,user_name()
from ImportantData
revert;

--Results: before security policy is applied this should bring back ALL data
--Results: after security policy is applied this should bring back NO data
Execute as USER = 'User4'
select *,user_name()
from ImportantData
revert;


---clean up
Drop table dbo.ImportantData
Drop table RowSec.Users

