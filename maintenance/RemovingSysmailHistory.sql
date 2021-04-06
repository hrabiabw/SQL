USE MSDB
GO
DECLARE @varDate DATETIME
SET @varDate = DATEADD(month,-2,GETDATE());

DELETE FROM dbo.sysmail_attachments
WHERE Last_mod_date < @varDate;

DELETE FROM dbo.sysmail_send_retries
WHERE Last_send_attempt_date < @varDate;

EXEC Sysmail_delete_mailitems_sp
@Sent_before = @varDate;

EXEC Sysmail_delete_log_sp
@Logged_before = @varDate;
GO
