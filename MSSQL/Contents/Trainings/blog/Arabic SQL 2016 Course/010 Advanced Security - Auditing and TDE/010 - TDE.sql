Use Master
    go
    
    --Step 1
    Create Master Key
    Encryption By Password =  'Pa$$w0rd'
    
    --Step 2
    Create Certificate SQL_Cert
    with Subject = 'DEK Certificate'
    
    --Step 3
    Use TDE_Test
    Create Database Encryption Key
    With Algorithm = AES_128
    Encryption by Server Certificate SQL_Cert


    --Step 4
    Alter Database TDE_Test
    Set Encryption ON
    
    Use Master
    --Step 5
    Backup Certificate SQL_Cert
    To File = 'Z:\Security\SQL_Cert'
    With Private Key (file= 'Z:\Security\SQLKey',
    Encryption by password='Pa$$w0rd')

select db.name, dek.*
from sys.dm_database_encryption_keys dek
inner join sys.databases db on dek.database_id=db.database_id

backup database TDE_Test to disk = 'z:\sqldata\backups\tde.bak'
