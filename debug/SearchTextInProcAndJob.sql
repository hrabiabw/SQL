SELECT DISTINCT
  OBJECT_SCHEMA_NAME(a.[object_id]) as [schema_name],
  A.NAME AS [object_name],
  A.TYPE_DESC
FROM
	SYS.SQL_MODULES M
	INNER JOIN SYS.OBJECTS A ON M.OBJECT_ID = A.OBJECT_ID
WHERE
	M.DEFINITION LIKE '%FACT_REFUND%'
	AND OBJECT_SCHEMA_NAME(a.[object_id]) = 'MARTS'
	AND A.NAME NOT LIKE '%test%'
	AND A.NAME NOT LIKE '%backup%';

SELECT s.step_id,
       j.[name],
       s.database_name,
       s.command
FROM   msdb.dbo.sysjobsteps AS s
INNER JOIN msdb.dbo.sysjobs AS j ON  s.job_id = j.job_id
WHERE  s.command LIKE '%usp_Installments_Operational_Monthly_Send_Mail%'
