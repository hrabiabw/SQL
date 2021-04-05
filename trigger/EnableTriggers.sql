------------------------------------------
-- Enable triggers
------------------------------------------
SELECT 'alter table '+
(
    SELECT SCHEMA_NAME(schema_id)
    FROM sys.objects o
    WHERE o.object_id = parent_id
)+'.'+OBJECT_NAME(parent_id)+' ENABLE TRIGGER '+Name AS EnableScript,
       *
FROM sys.triggers t
WHERE is_disabled = 1;
