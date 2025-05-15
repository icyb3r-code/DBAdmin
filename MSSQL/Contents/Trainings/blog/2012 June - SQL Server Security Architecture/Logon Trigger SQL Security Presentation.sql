USE Master
go
CREATE TRIGGER trg_track_logons
ON ALL SERVER --Database, table, etc
WITH EXECUTE AS 'securitysuper' ---IMPORTANT or it won't write to the audit table
FOR LOGON
AS
BEGIN

	IF ORIGINAL_LOGIN() = 'weaksecurityuser' 
	and
	DATEPART (hh,GETDATE()) between 1 and 23
	BEGIN
		ROLLBACK
		INSERT SecurityTest.dbo.RestrictedLogons
		(Login, TimeStamp)
		VALUES (ORIGINAL_LOGIN(),GETDATE())
	END
END

DROP TRIGGER trg_track_logons ON ALL SERVER

SELECT *
FROM SecurityTest.dbo.RestrictedLogons

TRUNCATE TABLE SecurityTest.dbo.RestrictedLogons
