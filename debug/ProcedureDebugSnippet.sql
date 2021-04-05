----------------------------------------------------
-- debug procedure snippet
-- shows time when control point is reached
----------------------------------------------------
-- variable declaration  
DECLARE @logMessage AS VARCHAR(MAX)= '';

-- snippet
SET NOCOUNT OFF;
SET @logMessage = '00) '+CONVERT(VARCHAR, GETDATE(), 120);
RAISERROR(@logMessage, 0, 1) WITH NOWAIT;
SET NOCOUNT ON;
