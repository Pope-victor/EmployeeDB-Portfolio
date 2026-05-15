-- ============================================================
-- FILE: 08_performance_optimization.sql
-- PROJECT: Employee Database Management System
-- DESCRIPTION: Index creation, query optimization, execution
--              plan analysis, and performance monitoring.
--              Core DBA performance tuning skills.
-- ============================================================

USE EmployeeDB;
GO

-- ============================================================
-- SECTION 1: INDEX STRATEGY
-- ============================================================

-- -------------------------------------------------------
-- 1A: CLUSTERED INDEXES (already exist via PRIMARY KEY)
--     One per table — defines physical storage order
-- -------------------------------------------------------
-- PK_Employees  → EmployeeID
-- PK_Salaries   → SalaryID
-- PK_Attendance → AttendanceID
-- PK_AuditLog   → AuditID (BIGINT — scales to millions)

-- -------------------------------------------------------
-- 1B: NONCLUSTERED INDEXES — high-frequency query columns
-- -------------------------------------------------------

-- Employees: frequently filtered/joined columns
CREATE NONCLUSTERED INDEX IX_Employees_DepartmentID
    ON Employees (DepartmentID)
    INCLUDE (FirstName, LastName, Email, EmploymentStatus);
GO

CREATE NONCLUSTERED INDEX IX_Employees_ManagerID
    ON Employees (ManagerID)
    INCLUDE (FirstName, LastName, Email);
GO

CREATE NONCLUSTERED INDEX IX_Employees_HireDate
    ON Employees (HireDate)
    INCLUDE (EmployeeID, FirstName, LastName, DepartmentID);
GO

-- Employees: WHERE EmploymentStatus = 'Active' is very common
-- Filtered index — only indexes Active employees (smaller, faster)
CREATE NONCLUSTERED INDEX IX_Employees_Active
    ON Employees (EmploymentStatus, DepartmentID)
    INCLUDE (FirstName, LastName, Email, JobTitleID)
    WHERE EmploymentStatus = 'Active';
GO

-- Salaries: covering index for current salary lookup
CREATE NONCLUSTERED INDEX IX_Salaries_EmployeeID_Current
    ON Salaries (EmployeeID, EndDate)
    INCLUDE (BasicSalary, GrossSalary, EffectiveDate)
    WHERE EndDate IS NULL;   -- Filtered: only current salaries
GO

-- Attendance: date-range queries are common
CREATE NONCLUSTERED INDEX IX_Attendance_EmployeeDate
    ON Attendance (EmployeeID, AttendanceDate)
    INCLUDE (Status, WorkHours, CheckInTime, CheckOutTime);
GO

CREATE NONCLUSTERED INDEX IX_Attendance_Date_Status
    ON Attendance (AttendanceDate, Status)
    INCLUDE (EmployeeID);
GO

-- LeaveRequests: status filtering
CREATE NONCLUSTERED INDEX IX_Leave_Status_Employee
    ON LeaveRequests (Status, EmployeeID)
    INCLUDE (LeaveType, StartDate, EndDate, TotalDays);
GO

-- AuditLog: DBA queries by date range
CREATE NONCLUSTERED INDEX IX_AuditLog_ChangedAt
    ON AuditLog (ChangedAt DESC)
    INCLUDE (TableName, Action, ChangedBy);
GO

-- ============================================================
-- SECTION 2: QUERY OPTIMIZATION EXAMPLES
-- ============================================================

-- -------------------------------------------------------
-- 2A: SLOW QUERY (before optimization)
-- Problem: SELECT *, no sargable WHERE, function on column
-- -------------------------------------------------------
-- BAD — do NOT use in production:
/*
SELECT *
FROM Employees e, Salaries s, Departments d
WHERE e.EmployeeID = s.EmployeeID
AND   e.DepartmentID = d.DepartmentID
AND   YEAR(e.HireDate) = 2023           -- function kills index use
AND   s.EndDate IS NULL;
*/

-- -------------------------------------------------------
-- 2B: OPTIMIZED VERSION of same query
-- -------------------------------------------------------
SELECT
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName  AS FullName,
    e.Email,
    d.DepartmentName,
    s.GrossSalary
FROM   Employees   e
INNER JOIN Salaries    s ON e.EmployeeID   = s.EmployeeID AND s.EndDate IS NULL
INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID
WHERE  e.HireDate >= '2023-01-01'       -- Sargable: uses IX_Employees_HireDate
  AND  e.HireDate <  '2024-01-01'
  AND  e.EmploymentStatus = 'Active';   -- Uses IX_Employees_Active
GO

-- -------------------------------------------------------
-- 2C: Use INCLUDE columns to avoid key lookups
-- Check: does this plan show "Index Seek" with no lookup?
-- -------------------------------------------------------
SELECT e.FirstName, e.LastName, e.Email, e.EmploymentStatus
FROM   Employees e
WHERE  e.DepartmentID = 1               -- Covered by IX_Employees_DepartmentID
  AND  e.EmploymentStatus = 'Active';
GO

-- ============================================================
-- SECTION 3: STATISTICS UPDATE
-- PURPOSE: Keep query optimizer statistics current
-- ============================================================

-- Update stats on specific tables (run after bulk loads)
UPDATE STATISTICS Employees   WITH FULLSCAN;
UPDATE STATISTICS Salaries    WITH FULLSCAN;
UPDATE STATISTICS Attendance  WITH FULLSCAN;
GO

-- Update all stats in the database (run weekly, e.g., Sunday night)
EXEC sp_updatestats;
GO

-- ============================================================
-- SECTION 4: INDEX MAINTENANCE
-- PURPOSE: Rebuild or reorganize fragmented indexes
-- ============================================================

-- Check index fragmentation
SELECT
    OBJECT_NAME(ips.object_id)          AS TableName,
    i.name                              AS IndexName,
    ips.index_type_desc,
    ROUND(ips.avg_fragmentation_in_percent, 2) AS FragmentationPct,
    ips.page_count,
    CASE
        WHEN ips.avg_fragmentation_in_percent > 30 THEN 'REBUILD'
        WHEN ips.avg_fragmentation_in_percent > 10 THEN 'REORGANIZE'
        ELSE 'OK'
    END AS Recommendation
FROM   sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
WHERE  ips.page_count > 1000            -- Only significant indexes
ORDER BY ips.avg_fragmentation_in_percent DESC;
GO

-- Reorganize mildly fragmented (10-30%) — online, no lock
ALTER INDEX IX_Attendance_EmployeeDate ON Attendance REORGANIZE;
GO

-- Rebuild heavily fragmented (>30%) — rebuilds completely
ALTER INDEX IX_Employees_DepartmentID ON Employees REBUILD
WITH (ONLINE = ON, FILLFACTOR = 85);   -- ONLINE=ON keeps table accessible
GO

-- Rebuild ALL indexes on a table
ALTER INDEX ALL ON Attendance REBUILD
WITH (ONLINE = ON, SORT_IN_TEMPDB = ON, FILLFACTOR = 85);
GO

-- ============================================================
-- SECTION 5: PERFORMANCE MONITORING QUERIES
-- ============================================================

-- 5A: Find TOP 10 most expensive queries by CPU
SELECT TOP 10
    SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(qt.text)
            ELSE qs.statement_end_offset
          END - qs.statement_start_offset)/2)+1)   AS QueryText,
    qs.execution_count,
    qs.total_worker_time / 1000                    AS TotalCPU_ms,
    qs.total_worker_time / qs.execution_count / 1000 AS AvgCPU_ms,
    qs.total_elapsed_time / qs.execution_count / 1000 AS AvgDuration_ms,
    qs.total_logical_reads / qs.execution_count    AS AvgLogicalReads,
    qs.total_physical_reads / qs.execution_count   AS AvgPhysicalReads,
    qs.last_execution_time
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY qs.total_worker_time DESC;
GO

-- 5B: Find queries causing most I/O (physical reads = missing indexes)
SELECT TOP 10
    SUBSTRING(qt.text, 1, 200)                              AS QueryText,
    qs.total_physical_reads,
    qs.total_logical_reads,
    qs.execution_count,
    qs.total_physical_reads / qs.execution_count            AS AvgPhysReads
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY total_physical_reads DESC;
GO

-- 5C: Missing index suggestions (SQL Server recommends these)
SELECT TOP 10
    DB_NAME(mid.database_id)                                        AS DatabaseName,
    OBJECT_NAME(mid.object_id, mid.database_id)                     AS TableName,
    migs.avg_user_impact                                            AS EstimatedImprovementPct,
    migs.user_seeks + migs.user_scans                               AS UsageCount,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    'CREATE INDEX IX_' + OBJECT_NAME(mid.object_id) + '_Missing
     ON ' + mid.statement + ' (' +
     ISNULL(mid.equality_columns,'') +
     CASE WHEN mid.inequality_columns IS NOT NULL
          THEN ',' + mid.inequality_columns ELSE '' END + ')
     INCLUDE (' + ISNULL(mid.included_columns,'') + ');'            AS SuggestedIndex
FROM sys.dm_db_missing_index_groups   mig
JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
JOIN sys.dm_db_missing_index_details   mid  ON mig.index_handle         = mid.index_handle
WHERE mid.database_id = DB_ID()
ORDER BY migs.avg_user_impact DESC;
GO

-- 5D: Current active sessions and waits (real-time monitoring)
SELECT
    r.session_id,
    r.status,
    r.command,
    r.wait_type,
    r.wait_time / 1000              AS WaitSeconds,
    r.cpu_time / 1000               AS CPU_ms,
    r.reads,
    r.writes,
    r.logical_reads,
    DB_NAME(r.database_id)          AS DatabaseName,
    SUBSTRING(qt.text, 1, 200)      AS QueryText,
    s.login_name,
    s.host_name,
    s.program_name
FROM sys.dm_exec_requests  r
JOIN sys.dm_exec_sessions   s  ON r.session_id  = s.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) qt
WHERE r.session_id > 50             -- Skip system sessions
ORDER BY r.cpu_time DESC;
GO

-- 5E: Database size and file usage
SELECT
    name                            AS FileName,
    physical_name,
    type_desc,
    CAST(size * 8.0 / 1024 AS DECIMAL(10,2)) AS AllocatedMB,
    CAST(FILEPROPERTY(name, 'SpaceUsed') * 8.0 / 1024 AS DECIMAL(10,2)) AS UsedMB,
    CAST((size - FILEPROPERTY(name, 'SpaceUsed')) * 8.0 / 1024 AS DECIMAL(10,2)) AS FreeMB
FROM sys.database_files;
GO

-- ============================================================
-- SECTION 6: DATABASE MAINTENANCE PLAN (SP)
-- Run via SQL Agent Job: Daily at 2 AM
-- ============================================================
CREATE OR ALTER PROCEDURE sp_DatabaseMaintenance
AS
BEGIN
    SET NOCOUNT ON;
    PRINT '=== EmployeeDB Maintenance Started: ' + CONVERT(VARCHAR, GETDATE(), 120) + ' ===';

    -- 1. Update statistics
    PRINT 'Step 1: Updating statistics...';
    EXEC sp_updatestats;

    -- 2. Reorganize mildly fragmented indexes
    PRINT 'Step 2: Reorganizing indexes...';
    DECLARE @sql NVARCHAR(MAX) = '';
    SELECT @sql += 'ALTER INDEX ' + QUOTENAME(i.name) + ' ON ' + QUOTENAME(OBJECT_NAME(i.object_id)) + ' REORGANIZE;' + CHAR(13)
    FROM   sys.indexes i
    JOIN   sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
        ON i.object_id = ips.object_id AND i.index_id = ips.index_id
    WHERE  ips.avg_fragmentation_in_percent BETWEEN 10 AND 30
      AND  ips.page_count > 100
      AND  i.name IS NOT NULL;
    IF LEN(@sql) > 0 EXEC sp_executesql @sql;

    -- 3. Shrink log file (ONLY acceptable in non-critical period)
    PRINT 'Step 3: Truncating inactive log...';
    DBCC SHRINKFILE (EmployeeDB_Log, 50);    -- Shrink log to 50MB minimum

    -- 4. Check DB integrity
    PRINT 'Step 4: Running DBCC CHECKDB...';
    DBCC CHECKDB ('EmployeeDB') WITH NO_INFOMSGS;

    -- 5. Backup transaction log
    PRINT 'Step 5: Backing up transaction log...';
    EXEC sp_DatabaseBackup 'LOG';

    PRINT '=== Maintenance Completed: ' + CONVERT(VARCHAR, GETDATE(), 120) + ' ===';
END;
GO

PRINT 'Performance optimization scripts applied successfully.';
GO
