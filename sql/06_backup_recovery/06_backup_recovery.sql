-- ============================================================
-- FILE: 06_backup_recovery.sql
-- PROJECT: Employee Database Management System
-- DESCRIPTION: Full backup, differential backup, transaction log
--              backup, and restore procedures. Core DBA skill.
-- ============================================================

USE master;
GO

-- ============================================================
-- SECTION 1: BACKUP CONFIGURATION
-- ============================================================

-- Step 1: Verify the database is in FULL recovery model
--         (required for transaction log backups)
ALTER DATABASE EmployeeDB SET RECOVERY FULL;
GO

-- Confirm recovery model
SELECT name, recovery_model_desc
FROM   sys.databases
WHERE  name = 'EmployeeDB';
GO

-- ============================================================
-- SECTION 2: FULL DATABASE BACKUP
-- PURPOSE: Complete copy of the database — run weekly (Sunday)
-- ============================================================

-- Full backup with compression and checksum
BACKUP DATABASE EmployeeDB
TO DISK = 'C:\SQLBackups\EmployeeDB_Full_' +
           REPLACE(REPLACE(CONVERT(VARCHAR(20), GETDATE(), 120), ':', ''), ' ', '_') + '.bak'
WITH
    FORMAT,                     -- Overwrites existing media set
    COMPRESSION,                -- Reduces backup file size ~60%
    CHECKSUM,                   -- Verifies backup integrity
    STATS = 10,                 -- Show progress every 10%
    NAME = 'EmployeeDB Full Backup',
    DESCRIPTION = 'Weekly full backup for EmployeeDB';
GO

-- ============================================================
-- SECTION 3: DIFFERENTIAL BACKUP
-- PURPOSE: Only pages changed since last FULL backup — run nightly
-- ============================================================

BACKUP DATABASE EmployeeDB
TO DISK = 'C:\SQLBackups\EmployeeDB_Diff_' +
           REPLACE(REPLACE(CONVERT(VARCHAR(20), GETDATE(), 120), ':', ''), ' ', '_') + '.bak'
WITH
    DIFFERENTIAL,
    COMPRESSION,
    CHECKSUM,
    STATS = 10,
    NAME = 'EmployeeDB Differential Backup',
    DESCRIPTION = 'Nightly differential backup for EmployeeDB';
GO

-- ============================================================
-- SECTION 4: TRANSACTION LOG BACKUP
-- PURPOSE: Captures all transactions — run every hour
--          Enables point-in-time recovery
-- ============================================================

BACKUP LOG EmployeeDB
TO DISK = 'C:\SQLBackups\EmployeeDB_Log_' +
           REPLACE(REPLACE(CONVERT(VARCHAR(20), GETDATE(), 120), ':', ''), ' ', '_') + '.trn'
WITH
    COMPRESSION,
    CHECKSUM,
    STATS = 10,
    NAME = 'EmployeeDB Transaction Log Backup';
GO

-- ============================================================
-- SECTION 5: VERIFY BACKUP INTEGRITY
-- PURPOSE: Always verify backups are readable after creation
-- ============================================================

-- List recent backups from msdb history
SELECT TOP 10
    bs.database_name,
    bs.backup_start_date,
    bs.backup_finish_date,
    CASE bs.type
        WHEN 'D' THEN 'Full'
        WHEN 'I' THEN 'Differential'
        WHEN 'L' THEN 'Transaction Log'
    END                                     AS BackupType,
    CAST(bs.backup_size / 1048576.0 AS DECIMAL(10,2)) AS BackupSizeMB,
    CAST(bs.compressed_backup_size / 1048576.0 AS DECIMAL(10,2)) AS CompressedSizeMB,
    bmf.physical_device_name               AS BackupFilePath,
    bs.has_backup_checksums                 AS HasChecksum
FROM msdb.dbo.backupset         bs
JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = 'EmployeeDB'
ORDER BY bs.backup_start_date DESC;
GO

-- Verify a specific backup file is readable
RESTORE VERIFYONLY
FROM DISK = 'C:\SQLBackups\EmployeeDB_Full_2024-01-07_020000.bak'
WITH CHECKSUM;
GO

-- ============================================================
-- SECTION 6: RESTORE PROCEDURES
-- ============================================================

-- -------------------------------------------------------
-- 6A: RESTORE FROM FULL BACKUP (complete restore)
-- -------------------------------------------------------
-- NOTE: Replace database first before restoring
USE master;
GO

-- Kill active connections before restore
ALTER DATABASE EmployeeDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

RESTORE DATABASE EmployeeDB
FROM DISK = 'C:\SQLBackups\EmployeeDB_Full_2024-01-07_020000.bak'
WITH
    MOVE 'EmployeeDB_Data' TO 'C:\SQLData\EmployeeDB.mdf',
    MOVE 'EmployeeDB_Log'  TO 'C:\SQLData\EmployeeDB.ldf',
    NORECOVERY,             -- Leave DB in restoring state for log/diff restore
    REPLACE,                -- Overwrite existing database
    STATS = 10;
GO

-- -------------------------------------------------------
-- 6B: APPLY DIFFERENTIAL BACKUP (after full restore)
-- -------------------------------------------------------
RESTORE DATABASE EmployeeDB
FROM DISK = 'C:\SQLBackups\EmployeeDB_Diff_2024-01-07_220000.bak'
WITH
    NORECOVERY,             -- Still leave open for log restore
    STATS = 10;
GO

-- -------------------------------------------------------
-- 6C: APPLY TRANSACTION LOG (point-in-time recovery)
-- -------------------------------------------------------
RESTORE LOG EmployeeDB
FROM DISK = 'C:\SQLBackups\EmployeeDB_Log_2024-01-07_230000.trn'
WITH
    RECOVERY,               -- Final step: bring DB online
    STOPAT = '2024-01-07 23:45:00',  -- Recover to exact point in time
    STATS = 10;
GO

-- Bring back to multi-user
ALTER DATABASE EmployeeDB SET MULTI_USER;
GO

-- ============================================================
-- SECTION 7: AUTOMATED BACKUP STORED PROCEDURE
-- PURPOSE: DBA runs this manually or via SQL Agent Job
-- ============================================================
CREATE OR ALTER PROCEDURE sp_DatabaseBackup
    @BackupType    VARCHAR(4),          -- FULL, DIFF, LOG
    @BackupPath    VARCHAR(500)         = 'C:\SQLBackups\'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FileName   VARCHAR(600);
    DECLARE @Timestamp  VARCHAR(30) = REPLACE(REPLACE(CONVERT(VARCHAR(20), GETDATE(), 120), ':', ''), ' ', '_');
    DECLARE @SQL        NVARCHAR(MAX);

    SET @FileName = @BackupPath + 'EmployeeDB_' + @BackupType + '_' + @Timestamp +
                    CASE WHEN @BackupType = 'LOG' THEN '.trn' ELSE '.bak' END;

    SET @SQL = CASE @BackupType
        WHEN 'FULL' THEN
            'BACKUP DATABASE EmployeeDB TO DISK = ''' + @FileName + '''
             WITH FORMAT, COMPRESSION, CHECKSUM, STATS = 10,
             NAME = ''EmployeeDB Full - ' + @Timestamp + ''';'
        WHEN 'DIFF' THEN
            'BACKUP DATABASE EmployeeDB TO DISK = ''' + @FileName + '''
             WITH DIFFERENTIAL, COMPRESSION, CHECKSUM, STATS = 10,
             NAME = ''EmployeeDB Diff - ' + @Timestamp + ''';'
        WHEN 'LOG' THEN
            'BACKUP LOG EmployeeDB TO DISK = ''' + @FileName + '''
             WITH COMPRESSION, CHECKSUM, STATS = 10,
             NAME = ''EmployeeDB Log - ' + @Timestamp + ''';'
        ELSE NULL
    END;

    IF @SQL IS NULL
        THROW 50100, 'Invalid backup type. Use FULL, DIFF, or LOG.', 1;

    PRINT 'Executing: ' + @SQL;
    EXEC sp_executesql @SQL;

    -- Log to audit table
    INSERT INTO EmployeeDB.dbo.AuditLog (TableName, RecordID, Action, NewValues)
    VALUES ('DATABASE_BACKUP', 0, 'INSERT',
            CONCAT('{"Type":"', @BackupType, '","File":"', @FileName, '","Date":"', GETDATE(), '"}'));

    PRINT 'Backup completed: ' + @FileName;
END;
GO

-- Usage:
-- EXEC sp_DatabaseBackup 'FULL';
-- EXEC sp_DatabaseBackup 'DIFF';
-- EXEC sp_DatabaseBackup 'LOG';

PRINT 'Backup and recovery scripts ready.';
GO
