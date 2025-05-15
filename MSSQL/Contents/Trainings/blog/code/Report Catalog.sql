SELECT Name,CreationDate,ModifiedDate,ExecutionTime,
SUBSTRING(path,
1+CHARINDEX('/',path),
CASE WHEN CHARINDEX('/',PATH,2) <> 0 THEN CHARINDEX('/',path,2)-2 ELSE LEN(path) END
) AS FolderPath, 

'http://[YourServerName]/Reports/Pages/Report.aspx?ItemPath=%2f'+ SUBSTRING(PATH,2,LEN(PATH)) as ReportURL

FROM dbo.Catalog 
WHERE type NOT IN (1,5)
AND path NOT IN  ('/Data Sources',' ')
AND name NOT IN  ('Reports Catalog')
