/*
EXEC adm.Job_CurrentStep_SendEmail
	@job_name = ''
	,@subject_prefix = ''
	,@is_email = 0
	,@recipients = '';
*/

ALTER PROCEDURE [adm].[Job_CurrentStep_SendEmail]
(
	@job_name NVARCHAR(256) = ''
	,@subject_prefix NVARCHAR(256) = ''
	,@is_email tinyint = 1
	,@recipients NVARCHAR(1024) = ''
)
AS
BEGIN

	DECLARE
		@job_id UNIQUEIDENTIFIER = NULL,
		@step_id INT = 0,
		@subject NVARCHAR(256) = '',
		@run_time NVARCHAR(5),
		@step_name NVARCHAR(125);

	-- get job_id
	SELECT @job_id = job_id from msdb.dbo.sysjobs WHERE [name] = @job_name

	--------------------------------------------------------------------------------
	-- get current job info
	--------------------------------------------------------------------------------
	DROP TABLE IF EXISTS #enum_job;

	CREATE TABLE #enum_job
	(
		Job_ID uniqueidentifier,
		Last_Run_Date int,
		Last_Run_Time int,
		Next_Run_Date int,
		Next_Run_Time int,
		Next_Run_Schedule_ID int,
		Requested_To_Run int,
		Request_Source int,
		Request_Source_ID varchar(100),
		Running int,
		Current_Step int,
		Current_Retry_Attempt int,
		[State] int
	)

	INSERT INTO #enum_job
		EXEC master.dbo.xp_sqlagent_enum_jobs 0,sa

	--------------------------------------------------------------------------------
	-- get current step_id
	--------------------------------------------------------------------------------
	SELECT @step_id = ISNULL(current_step, 0) FROM #enum_job WHERE job_id = @job_id;

	--------------------------------------------------------------------------------
	-- get subject body
	--------------------------------------------------------------------------------
	SELECT
	@run_time =
		CONVERT
		(
			VARCHAR(5),
			DATEADD
			(
				MINUTE,
				DATEDIFF
				(
					MINUTE,
					isnull(ja.last_executed_step_date,ja.start_execution_date),
					GETDATE()
				),
				0
			),
			114
		)
		,@step_name = js.step_name
	FROM
		msdb.dbo.sysjobactivity ja
		LEFT JOIN msdb.dbo.sysjobhistory jh
			ON jh.instance_id = ja.job_history_id
		JOIN msdb.dbo.sysjobs j
			ON j.job_id = ja.job_id
		JOIN msdb.dbo.sysjobsteps js
			ON js.job_id = ja.job_id
			AND js.step_id = @step_id
	WHERE
		ja.session_id =
		(
			SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC
		)
		AND start_execution_date is not null
		AND stop_execution_date is null
		AND j.[name] = @job_name;

	--------------------------------------------------------------------------------
	-- set email subject
	--------------------------------------------------------------------------------
	IF @step_id != 0
		SELECT @subject = @subject_prefix + ' | ' + @run_time + ' |' + @step_name;
	ELSE
		SELECT @subject = @subject_prefix + ' | not_running';

	--------------------------------------------------------------------------------
	-- result set action
	--------------------------------------------------------------------------------
	IF @is_email = 1
		EXEC msdb.dbo.sp_send_dbmail
			@profile_name ='Email',
			@recipients = @recipients,
			@subject = @subject,
			@body = @job_name;
	ELSE
		SELECT
			@job_name AS job_name
			,@subject_prefix AS subject_prefix
			,@run_time AS run_time
			,@step_name as step_name;

END;
