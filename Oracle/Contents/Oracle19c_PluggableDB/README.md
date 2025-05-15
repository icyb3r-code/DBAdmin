
# Pluggable Databases (PDBs)

## Create PDB

```bash
SQL> CREATE PLUGGABLE DATABASE orapdb1 
ADMIN USER pdb_admin IDENTIFIED BY password 
ROLES = (dba) 
DEFAULT TABLESPACE pdb1_tbs DATAFILE '/u02/oradata/ORCL/orapdb  
1/pdb1_tbs.dbf' SIZE 50M AUTOEXTEND ON 
FILE_NAME_CONVERT=('/u02/oradata/ORCL/pdbseed/','/u02/oradata/ORCL/orapdb1/');                          
  
Pluggable database created.  
  
SQL>
```