/*Create a Test Database to play around in*/

CREATE DATABASE Test_DB

USE Test_DB
GO

/*Create the Test Sequence Object*/

CREATE SEQUENCE dbo.TestSequence
AS INT

MINVALUE 1
NO MAXVALUE
START WITH 1

/*Create a Test table to test the sequence with*/
/*This first set of test tables has the NEXT value for the Sequence object set to the default value of the ID column.
It will behave like an Identity column but instead, take its next value from the sequence which is value that can be shared across different tables*/

USE Test_DB

CREATE TABLE Test1
(
ID INT DEFAULT (NEXT value for dbo.TestSequence),
RandomText VARCHAR(50)
)

CREATE TABLE Test2
(
ID INT DEFAULT (NEXT value for dbo.TestSequence),
RandomText VARCHAR(50)
)

/*Inserting data into Table1 then Table2*/
INSERT INTO Test1(RandomText) VALUES ('Insert1')
INSERT INTO Test1(RandomText) VALUES ('Insert2')
INSERT INTO Test2(RandomText) VALUES ('Insert3')
INSERT INTO Test2(RandomText) VALUES ('Insert4')

/*Inserting data alternating between Table1 and Table2*/
INSERT INTO Test1(RandomText) VALUES ('Insert5')
INSERT INTO Test2(RandomText) VALUES ('Insert6')
INSERT INTO Test1(RandomText) VALUES ('Insert7')
INSERT INTO Test2(RandomText) VALUES ('Insert8')

/*Check out how the data looks*/

SELECT * FROM Test1
SELECT * FROM Test2

/*Reset Sequence back to 1*/
ALTER SEQUENCE [dbo].[TestSequence]
 RESTART  WITH 1 

GO


/*Inserting data into Table1 then Table2*/
INSERT INTO Test1(RandomText) VALUES ('Insert9')
INSERT INTO Test1(RandomText) VALUES ('Insert10')
INSERT INTO Test2(RandomText) VALUES ('Insert11')
INSERT INTO Test2(RandomText) VALUES ('Insert12')


/*Inserting data alternating between Table1 and Table2*/
INSERT INTO Test1(RandomText) VALUES ('Insert13')
INSERT INTO Test2(RandomText) VALUES ('Insert14')
INSERT INTO Test1(RandomText) VALUES ('Insert15')
INSERT INTO Test2(RandomText) VALUES ('Insert16')

/*Check out how the data looks; sequence number should have reset*/
SELECT * FROM Test1
SELECT * FROM Test2
/*There should be duplicate IDs since the Sequence was reset*/

/*Manually increment sequence*/
SELECT NEXT VALUE FOR TestSequence
INSERT INTO Test1(RandomText) VALUES ('Manually Incremented')

/*Check out how the data looks*/
/*There should be an ID number that was skipped*/
SELECT * FROM Test1
SELECT * FROM Test2

/*Using Sequence in insert without the table being bound by the sequence object*/
CREATE TABLE Test3
(
ID int,
RandomText varchar(50)
)

/*Programmatically insert the next sequence in the insert statement*/
INSERT INTO test3 VALUES (Next Value for TestSequence,'Insert1')
INSERT INTO test3 VALUES (Next Value for TestSequence,'Insert2')
INSERT INTO test3 VALUES (Next Value for TestSequence,'Insert3')
INSERT INTO test3 VALUES (Next Value for TestSequence,'Insert4')

/*Check out how the data looks*/
/*The IDs in this table should continue where they left off for the inserts in Table 1 and 2*/
SELECT * FROM Test3

/*This statement will not work because the Sequence Object is being referenced by two tables as being the
default value*/
DROP SEQUENCE dbo.TestSequence

/*Clean up*/
USE Master
DROP DATABASE Test_DB
