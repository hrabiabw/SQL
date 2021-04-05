----------------------------------------------------------------
-- don't show count
----------------------------------------------------------------
SET NOCOUNT ON;

----------------------------------------------------------------
-- variables
----------------------------------------------------------------
DECLARE
    @i INT = 1,
    @j INT = 1,
    @TABLE_NAME NVARCHAR(256),
    @COLUMN_NAME NVARCHAR(256);

----------------------------------------------------------------
-- temporary table with table names
----------------------------------------------------------------
IF OBJECT_ID('tempdb..#Table') IS NOT NULL
    DROP TABLE #Table;

CREATE TABLE #Table
(
    TableKey INT IDENTITY,
    TABLE_NAME NVARCHAR(255)
)

INSERT INTO #Table (TABLE_NAME)
SELECT 
	TABLE_NAME  
FROM 
	INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE '%';

----------------------------------------------------------------
-- temporary table with column names
----------------------------------------------------------------
IF OBJECT_ID('tempdb..#Column') IS NOT NULL
    DROP TABLE #Column
CREATE TABLE #Column
(
    ColumnKey INT IDENTITY,
    TABLE_NAME NVARCHAR(255),
    COLUMN_NAME NVARCHAR(255)
);

INSERT INTO #Column (TABLE_NAME, COLUMN_NAME)
SELECT 
	TABLE_NAME, COLUMN_NAME 
FROM 
	INFORMATION_SCHEMA.COLUMNS 
WHERE 
	TABLE_NAME IN (SELECT TABLE_NAME FROM #Table)
ORDER BY 
	TABLE_NAME, ORDINAL_POSITION;


----------------------------------------------------------------
--  go through table entries
----------------------------------------------------------------
WHILE @i <= ( SELECT COUNT(1) FROM  #Table)
BEGIN

SELECT @TABLE_NAME = TABLE_NAME FROM #Table WHERE TableKey = @i

PRINT '';
PRINT 'CREATE VIEW mds.V_' + @TABLE_NAME + ' AS SELECT ';

----------------------------------------------------------------
--  go through column entries
----------------------------------------------------------------
SELECT @j = MIN(ColumnKey) FROM #Column WHERE TABLE_NAME = @TABLE_NAME

    WHILE @j <= (SELECT MAX(ColumnKey) FROM #Column WHERE TABLE_NAME = @TABLE_NAME )
    BEGIN

    SELECT @COLUMN_NAME = COLUMN_NAME FROM #Column WHERE ColumnKey = @j
    PRINT ',' + @COLUMN_NAME	   

    SELECT @j = @j + 1;

    END;

PRINT 'FROM mds.' + @TABLE_NAME;
PRINT 'GO';

SELECT @i = @i + 1;

END;

