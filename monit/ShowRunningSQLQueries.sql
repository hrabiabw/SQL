-----------------------------------
-- Show running SQL queries on DB
-----------------------------------
SELECT 
	db_name(req.database_id) AS DatabaseName
	,ses.session_id AS SessionId
	,req.command AS CommandType
	,convert(VARCHAR, req.start_time, 120) AS StartTime
	,datediff(minute, req.start_time, getdate()) AS RunningMinutes
	,req.cpu_time AS CpuTime
	,req.percent_complete AS PercentComplete
	,sqltext.TEXT AS SqlCommand_SqlCommand_SqlCommand_SqlCommand_SqlCommand
	,ses.login_name AS LoginName
	,ses.host_name AS HostName
	,ses.program_name AS ProgramName
FROM 
	sys.dm_exec_requests req
	INNER JOIN sys.dm_exec_sessions ses ON ses.session_id = req.session_id
		AND ses.session_id >= 50
	CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS sqltext
WHERE 1 = 1
	-- and req.command = 'BACKUP DATABASE'
	-- and req.command = 'RESTORE DATABASE'
	-- and req.command = 'DbccFilesCompact'
ORDER BY datediff(minute, req.start_time, getdate()) DESC;
