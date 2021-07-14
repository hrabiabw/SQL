USE [DWH]
GO
/****** Object:  StoredProcedure [dbo].[usp_Load_TABLE_NAME]    Script Date: 7/14/2021 2:59:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[usp_Load_TABLE_NAME]
AS
BEGIN

	------------------------------------------------------------------------------
	-- variables
	------------------------------------------------------------------------------
	DECLARE
		@EmailSubject NVARCHAR(1024) = '[DWH].[dbo].[TABLE_NAME]',
		@IsError BIT = 0,
		@IsAttachment BIT = 0,
		@Today DATETIME = CONVERT(DATETIME, CONVERT(DATE, GETDATE())),
		@Yesterday DATETIME = '1900-01-01',
		@MaxDate DATETIME = '9999-12-31',
		@CurrentDateStr VARCHAR(16) = FORMAT(GETDATE(),'yyyyMMdd_HHmm'),
		@ParamsForCmdExecStr varchar(8000) = '#Query #fileName #fileSaveFolder',
		@FileSaveFolder	NVARCHAR(1024) = 'K:\xxx_Import_xlsx\Pricelist\Error\',
		@Query NVARCHAR(1024) = '',
		@FileName NVARCHAR(64) = '',
		@Attachment NVARCHAR(1024) = '!NO_ATTCH';

	SELECT
		@Yesterday = DATEADD(DAY, -1, @Today);

	------------------------------------------------------------------------------
	-- load csv into table
	------------------------------------------------------------------------------
	TRUNCATE TABLE Staging.excel.TABLE_NAME;

	BEGIN TRY

		BULK INSERT Staging.excel.TABLE_NAME
			FROM 'K:\xxx_Import_xlsx\Pricelist\TABLE_NAME.csv'
			WITH
			(
			FIRSTROW = 1,
			DATAFILETYPE = 'char',
			FIELDTERMINATOR = ';',
			ROWTERMINATOR = '\n',
			ERRORFILE = 'K:\xxx_Import_xlsx\Pricelist\Error\ErrorRows.log',
			KEEPNULLS
			);

	END TRY
	BEGIN CATCH

		SELECT @EmailSubject = '[Staging].[excel].[TABLE_NAME] - BULK INSERT ERR', @IsError = 1;
		RAISERROR(@EmailSubject, 16, 1);
		GOTO _SENDMAIL;

	END CATCH;

	-- clear empty rows
	DELETE FROM Staging.excel.TABLE_NAME
	WHERE
		id IS NULL
		AND [Store ID] IS NULL
		AND payment_category IS NULL
		AND payment_method IS NULL
		AND payment_method_category IS NULL
		AND tpt IS NULL
		AND tpv_rate IS NULL
		AND date_from IS NULL
		AND date_to IS NULL;

	-- check data exists
	IF (SELECT COUNT(1) FROM Staging.excel.TABLE_NAME) = 0
	BEGIN

		SELECT @EmailSubject = '[Staging].[excel].[TABLE_NAME] - NO DATA', @IsError = 1;
		RAISERROR(@EmailSubject, 16, 1);
		GOTO _SENDMAIL;

	END;

	------------------------------------------------------------------------------
	-- source data conversion
	------------------------------------------------------------------------------
	DROP TABLE IF EXISTS #TABLE_NAME;

	SELECT
		ROW_NUMBER() OVER(ORDER BY (SELECT 0)) AS ID,
		TAB.Store_id, TAB.PAYMENT_CATEGORY, TAB.PAYMENT_METHOD, TAB.PAYMENT_METHOD_CATEGORY, TAB.TPT, TAB.TPV_rate, TAB.Date_from, TAB.Date_to
	INTO #TABLE_NAME
	FROM
	(
		SELECT DISTINCT
			[Store ID] AS Store_id
			,payment_category AS PAYMENT_CATEGORY
			,payment_method AS PAYMENT_METHOD
			,payment_method_category AS PAYMENT_METHOD_CATEGORY
			,CONVERT(float, tpt) AS TPT
			,CONVERT(float, tpv_rate) AS TPV_rate
			,CONVERT(datetime, date_from) AS Date_from
			,CONVERT(datetime, (ISNULL(date_to,'12/31/9999'))) AS Date_to
		FROM
			Staging.excel.TABLE_NAME
	) TAB;

	------------------------------------------------------------------------------
	-- check for doubles - SOURCE
	------------------------------------------------------------------------------
	IF EXISTS
	(
		SELECT TOP 1 t1.Store_id
		FROM
			#TABLE_NAME t1
			INNER JOIN #TABLE_NAME t2
				ON t1.Store_ID = t2.Store_ID
				AND t1.PAYMENT_METHOD_CATEGORY = t2.PAYMENT_METHOD_CATEGORY
				AND t1.ID != t2.ID
				AND
				(
					t1.Date_from BETWEEN t2.Date_from AND t2.Date_to
					OR t1.Date_to BETWEEN t2.Date_from AND t2.Date_to

				)
	)
	BEGIN

		-- check table
		DROP TABLE IF EXISTS ##TABLE_NAME_SRC;

		-- get doubles into table
		SELECT
			t1.Store_id,
			t1.PAYMENT_CATEGORY,
			t1.PAYMENT_METHOD,
			t1.PAYMENT_METHOD_CATEGORY,
			t1.TPT,
			t1.TPV_rate,
			CONVERT(VARCHAR(10), t1.Date_from, 120) AS Date_from,
			CONVERT(VARCHAR(10), t1.Date_to, 120) AS Date_to
		INTO ##TABLE_NAME_SRC
		FROM
			#TABLE_NAME t1
			INNER JOIN #TABLE_NAME t2
				ON t1.Store_ID = t2.Store_ID
				AND t1.PAYMENT_METHOD_CATEGORY = t2.PAYMENT_METHOD_CATEGORY
				AND t1.ID != t2.ID
				AND
				(
					t1.Date_from BETWEEN t2.Date_from AND t2.Date_to
					OR t1.Date_to BETWEEN t2.Date_from AND t2.Date_to

				);

		-- generate file
		SELECT
			@ParamsForCmdExecStr = '#Query #fileName #fileSaveFolder',
			@Query = '"SELECT * FROM ##TABLE_NAME_SRC ORDER BY Store_id, PAYMENT_METHOD_CATEGORY"',
			@FileName = 'TABLE_NAME_src_dbl_' + @CurrentDateStr;

		SET @ParamsForCmdExecStr = REPLACE(@ParamsForCmdExecStr, '#Query', @Query);
		SET @ParamsForCmdExecStr = REPLACE(@ParamsForCmdExecStr, '#fileName', @FileName);
		SET @ParamsForCmdExecStr = REPLACE(@ParamsForCmdExecStr, '#fileSaveFolder', @FileSaveFolder);

		EXEC [Reporting].[dbo].[usp_Report_CreateXlsxViaPowerShell_V5]  @ParamsForCmdExecStr;

		-- remove doubles
		DELETE sdp1
		FROM
			#TABLE_NAME sdp1
			INNER JOIN ##TABLE_NAME_SRC sdp2
				ON sdp2.Store_id = sdp2.Store_id
				AND sdp2.PAYMENT_METHOD_CATEGORY = sdp2.PAYMENT_METHOD_CATEGORY;

		-- clear table
		DROP TABLE IF EXISTS ##TABLE_NAME_SRC;

		-- set variables
		SELECT
			@EmailSubject = @EmailSubject + ' - !SRC DOUBLES',
			@IsError = 0,
			@IsAttachment = 1,
			@Attachment = @FileSaveFolder + @FileName + '.xlsx',
			@ParamsForCmdExecStr = '',
			@Query = '',
			@FileName = '';

	END;

	------------------------------------------------------------------------------
	-- merge
	------------------------------------------------------------------------------
	BEGIN TRY

		-- Outer insert - the updated records are added to the SCD2 table
		INSERT INTO dbo.TABLE_NAME (Store_ID, PAYMENT_CATEGORY, PAYMENT_METHOD, PAYMENT_METHOD_CATEGORY, TPT, TPV_rate, Date_from, Date_to, IsCurrent)
		SELECT Store_ID, PAYMENT_CATEGORY, PAYMENT_METHOD, PAYMENT_METHOD_CATEGORY, TPT, TPV_rate, @Today, @MaxDate, 1
		FROM
		(
			-- Merge statement
			MERGE INTO dbo.TABLE_NAME AS DST
			USING #TABLE_NAME AS SRC
				ON
				(
					SRC.Store_ID = DST.Store_ID
					AND SRC.PAYMENT_METHOD_CATEGORY = DST.PAYMENT_METHOD_CATEGORY
				)
			-- New records inserted
			WHEN NOT MATCHED THEN
				INSERT (Store_ID, PAYMENT_CATEGORY, PAYMENT_METHOD, PAYMENT_METHOD_CATEGORY, TPT, TPV_rate, Date_from, Date_to, IsCurrent)
				VALUES (SRC.Store_ID, SRC.PAYMENT_CATEGORY, SRC.PAYMENT_METHOD, SRC.PAYMENT_METHOD_CATEGORY, SRC.TPT, SRC.TPV_rate, @Today, @MaxDate, 1)
			-- Existing records updated if data changes
			WHEN MATCHED
				AND IsCurrent = 1
				AND
				(
					ISNULL(DST.PAYMENT_CATEGORY, '!UNDEF') <> ISNULL(SRC.PAYMENT_CATEGORY, '!UNDEF')
					OR ISNULL(DST.PAYMENT_METHOD, '!UNDEF') <> ISNULL(SRC.PAYMENT_METHOD, '!UNDEF')
					OR ISNULL(DST.TPT,-1) <> ISNULL(SRC.TPT,-1)
					OR ISNULL(DST.TPV_rate,-1) <> ISNULL(SRC.TPV_rate,-1)
				)
			-- Update statement for a changed dimension record, to flag as no longer active
			THEN UPDATE
				SET DST.IsCurrent = 0, DST.Date_to = @Yesterday, DST.DateModified = GETDATE()
				OUTPUT SRC.Store_ID, SRC.PAYMENT_CATEGORY, SRC.PAYMENT_METHOD, SRC.PAYMENT_METHOD_CATEGORY, SRC.TPT, SRC.TPV_rate, $Action AS MergeAction
		) AS MRG
		WHERE MRG.MergeAction = 'UPDATE';

	END TRY
	BEGIN CATCH

		SELECT @EmailSubject = @EmailSubject + ' - MERGE ERR', @IsError = 1;
		RAISERROR(@EmailSubject, 16, 1);
		GOTO _SENDMAIL;

	END CATCH;

	------------------------------------------------------------------------------
	-- check for doubles
	------------------------------------------------------------------------------
	IF EXISTS
	(
		SELECT TOP 1 t1.Store_ID
		FROM
			dbo.TABLE_NAME t1
			INNER JOIN dbo.TABLE_NAME t2
				ON t1.Store_ID = t2.Store_ID
				AND t1.PAYMENT_METHOD_CATEGORY = t2.PAYMENT_METHOD_CATEGORY
				AND t1.ID != t2.ID
				AND
				(
					t1.Date_from BETWEEN t2.Date_from AND t2.Date_to
					OR t1.Date_to BETWEEN t2.Date_from AND t2.Date_to

				)
	)
	BEGIN

		-- check table
		DROP TABLE IF EXISTS ##TABLE_NAME_DST;

		-- get doubles into table
		SELECT
			t1.ID,
			t1.Store_id,
			t1.PAYMENT_CATEGORY,
			t1.PAYMENT_METHOD,
			t1.PAYMENT_METHOD_CATEGORY,
			t1.TPT,
			t1.TPV_rate,
			CONVERT(VARCHAR(10), t1.Date_from, 120) AS Date_from,
			CONVERT(VARCHAR(10), t1.Date_to, 120) AS Date_to,
			CONVERT(INT, t1.IsCurrent) AS IsCurrent,
			CONVERT(VARCHAR(16), t1.DateModified, 121) AS DateModified
		INTO ##TABLE_NAME_DST
		FROM
			dbo.TABLE_NAME t1
			INNER JOIN dbo.TABLE_NAME t2
				ON t1.Store_ID = t2.Store_ID
				AND t1.PAYMENT_METHOD_CATEGORY = t2.PAYMENT_METHOD_CATEGORY
				AND t1.ID != t2.ID
				AND
				(
					t1.Date_from BETWEEN t2.Date_from AND t2.Date_to
					OR t1.Date_to BETWEEN t2.Date_from AND t2.Date_to

				);

		-- generate file
		SELECT
			@ParamsForCmdExecStr = '#Query #fileName #fileSaveFolder',
			@Query = '"SELECT * FROM ##TABLE_NAME_DST ORDER BY Store_id, PAYMENT_METHOD_CATEGORY"',
			@FileName = 'TABLE_NAME_dst_dbl_' + @CurrentDateStr;

		SET @ParamsForCmdExecStr = REPLACE(@ParamsForCmdExecStr, '#Query', @Query);
		SET @ParamsForCmdExecStr = REPLACE(@ParamsForCmdExecStr, '#fileName', @FileName);
		SET @ParamsForCmdExecStr = REPLACE(@ParamsForCmdExecStr, '#fileSaveFolder', @FileSaveFolder);

		EXEC [Reporting].[dbo].[usp_Report_CreateXlsxViaPowerShell_V5]  @ParamsForCmdExecStr;

		-- clear table
		DROP TABLE IF EXISTS ##TABLE_NAME_DST;

		-- set variables
		SELECT
			@EmailSubject = @EmailSubject + ' - !DST DOUBLES',
			@IsError = 0,
			@IsAttachment = 1,
			@Attachment =
				CASE
					WHEN @Attachment = '!NO_ATTCH'
					THEN @FileSaveFolder + @FileName + '.xlsx'
					ELSE @Attachment + ';' + @FileSaveFolder + @FileName + '.xlsx'
				END,
			@ParamsForCmdExecStr = '',
			@Query = '',
			@FileName = '';

	END;

	------------------------------------------------------------------------------
	-- SENDMAIL block
	------------------------------------------------------------------------------
	_SENDMAIL:

	BEGIN

		IF @IsAttachment = 0

			EXEC msdb.dbo.sp_send_dbmail
			@profile_name ='Email',
			@recipients =  'bartlomiej.weglinski@xxxagination.com;marcin.tomalak@payu.pl',
			@subject = @EmailSubject;

		ELSE

			EXEC msdb.dbo.sp_send_dbmail
			@profile_name ='Email',
			@recipients =  'bartlomiej.weglinski@xxxagination.com;marcin.tomalak@payu.pl',
			@subject = @EmailSubject,
			@file_attachments = @Attachment;

	END;

	------------------------------------------------------------------------------
	-- move file
	------------------------------------------------------------------------------
	DECLARE
		@CmdDel NVARCHAR(4000) = '',
		@CmdRename NVARCHAR(4000) = '',
		@CmdMoveOK NVARCHAR(4000) = '',
		@CmdMoveErr NVARCHAR(4000) = '';

	SELECT
		@CmdDel = N'del /F /Q K:\xxx_Import_xlsx\Pricelist\TABLE_NAME.csv',
		@CmdRename = N'rename "K:\xxx_Import_xlsx\Pricelist\TABLE_NAME.xlsx" "TABLE_NAME_' + @CurrentDateStr + '.xlsx"',
		@CmdMoveOK = N'move "K:\xxx_Import_xlsx\Pricelist\*" "K:\xxx_Import_xlsx\Pricelist\Done\"',
		@CmdMoveErr = N'move "K:\xxx_Import_xlsx\Pricelist\*" "K:\xxx_Import_xlsx\Pricelist\Error\"'

	EXEC MASTER..XP_CMDSHELL @CmdDel;
	EXEC MASTER..XP_CMDSHELL @CmdRename;

	IF @IsError = 0
		EXEC MASTER..XP_CMDSHELL @CmdMoveOK;
	ELSE
		EXEC MASTER..XP_CMDSHELL @CmdMoveErr;


END;
