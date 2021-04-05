--------------------------------------------------------
-- Show message about running queries - grouped 
--------------------------------------------------------
USE master;
GO

SET NOCOUNT ON;

DECLARE @Counter AS INT= -1
	, @Counter10 AS INT= 0
	, @Counter20 AS INT= 0
	, @Counter30 AS INT= 0
	, @Suffix AS VARCHAR(100)
	, @Message AS VARCHAR(1000);
	
WHILE @Counter <> 0
BEGIN
    
        IF OBJECT_ID('tempdb..#TMP') IS NOT NULL
            DROP TABLE #TMP;
        
	SELECT ses.session_id AS SessionId,
             CONVERT( VARCHAR, req.start_time, 120) AS StartTime,
             req.cpu_time AS CpuTime,
             DATEDIFF(MINUTE, req.start_time, GETDATE()) AS RunningMinutes,
             sqltext.text
        INTO #TMP
        FROM sys.dm_exec_requests req
           INNER JOIN sys.dm_exec_sessions ses ON ses.session_id = req.session_id
                AND ses.session_id >= 50
           CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS sqltext
        WHERE 1 = 1
             AND DB_NAME(req.database_id) = 'DATABASE NAME'
             AND (sqltext.text LIKE '%SELECT%dbo_V_%'
                 OR sqltext.text LIKE '%SELECT%V_%');
				   
        SELECT @Counter = COUNT(*) FROM #TMP;       
	SELECT @Counter10 = COUNT(*) FROM #TMP WHERE RunningMinutes BETWEEN 10 AND 19;      
	SELECT @Counter20 = COUNT(*) FROM #TMP WHERE RunningMinutes BETWEEN 20 AND 29;
        SELECT @Counter30 = COUNT(*) FROM #TMP WHERE RunningMinutes >= 30;
        
	SET @Suffix = '';
        
	IF @Counter10 > 0 SET @Suffix = '!';
        IF @Counter20 > 0 SET @Suffix = '!!';
        IF @Counter30 > 0 SET @Suffix = '!!!';
        
	SET NOCOUNT OFF;
        
	SET @Message = 
		CONVERT(VARCHAR, GETDATE(), 120)+') '+'   
		All = '+CAST(@Counter AS VARCHAR(255))+',   
		10-19 minutes = '+CAST(@Counter10 AS VARCHAR(255))+',   
		20-29 minutes = '+CAST(@Counter20 AS VARCHAR(255))+',   
		30+ minutes = '+CAST(@Counter30 AS VARCHAR(255))+'   '
		+@Suffix;
			
        RAISERROR(@Message, 0, 1) WITH NOWAIT;
        
	SET NOCOUNT ON;
        
	WAITFOR DELAY '00:01:00';
    
END;
	
SET NOCOUNT OFF;
