-- ============================================================
-- FILE: 07_security_permissions.sql
-- PROJECT: Employee Database Management System
-- DESCRIPTION: SQL Server logins, users, roles, and permissions
--              Demonstrates RBAC (Role-Based Access Control)
-- ============================================================

USE master;
GO

-- ============================================================
-- SECTION 1: CREATE SQL SERVER LOGINS
-- PURPOSE: Server-level authentication accounts
-- ============================================================

-- Drop logins if they exist (for re-runability)
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_dba_admin')
    DROP LOGIN login_dba_admin;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_hr_user')
    DROP LOGIN login_hr_user;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_finance_user')
    DROP LOGIN login_finance_user;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_readonly_user')
    DROP LOGIN login_readonly_user;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_etl_service')
    DROP LOGIN login_etl_service;
GO

-- DBA Admin Login (full DB access, no sysadmin)
CREATE LOGIN login_dba_admin
WITH PASSWORD   = 'DBA@Str0ngP@ss!2024',
     CHECK_POLICY = ON,
     CHECK_EXPIRATION = ON;
GO

-- HR Login (employee and leave access)
CREATE LOGIN login_hr_user
WITH PASSWORD   = 'HR@Str0ngP@ss!2024',
     CHECK_POLICY = ON,
     CHECK_EXPIRATION = ON;
GO

-- Finance Login (salary/payroll access)
CREATE LOGIN login_finance_user
WITH PASSWORD   = 'Fin@Str0ngP@ss!2024',
     CHECK_POLICY = ON,
     CHECK_EXPIRATION = ON;
GO

-- Read-Only Reporting Login
CREATE LOGIN login_readonly_user
WITH PASSWORD   = 'Read@Str0ngP@ss!2024',
     CHECK_POLICY = ON,
     CHECK_EXPIRATION = ON;
GO

-- ETL Service Account (for Python ETL pipeline)
CREATE LOGIN login_etl_service
WITH PASSWORD   = 'ETL@Str0ngP@ss!2024',
     CHECK_POLICY = ON,
     CHECK_EXPIRATION = OFF;   -- Service accounts don't expire
GO

-- ============================================================
-- SECTION 2: CREATE DATABASE USERS
-- PURPOSE: Map server logins to EmployeeDB database users
-- ============================================================

USE EmployeeDB;
GO

CREATE USER user_dba_admin     FOR LOGIN login_dba_admin;
CREATE USER user_hr_user       FOR LOGIN login_hr_user;
CREATE USER user_finance_user  FOR LOGIN login_finance_user;
CREATE USER user_readonly_user FOR LOGIN login_readonly_user;
CREATE USER user_etl_service   FOR LOGIN login_etl_service;
GO

-- ============================================================
-- SECTION 3: CREATE DATABASE ROLES
-- PURPOSE: Group permissions into reusable roles
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'role_dba')
    CREATE ROLE role_dba;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'role_hr')
    CREATE ROLE role_hr;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'role_finance')
    CREATE ROLE role_finance;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'role_reporting')
    CREATE ROLE role_reporting;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'role_etl')
    CREATE ROLE role_etl;
GO

-- ============================================================
-- SECTION 4: ASSIGN USERS TO ROLES
-- ============================================================

ALTER ROLE role_dba       ADD MEMBER user_dba_admin;
ALTER ROLE role_hr        ADD MEMBER user_hr_user;
ALTER ROLE role_finance   ADD MEMBER user_finance_user;
ALTER ROLE role_reporting ADD MEMBER user_readonly_user;
ALTER ROLE role_etl       ADD MEMBER user_etl_service;
GO

-- ============================================================
-- SECTION 5: GRANT PERMISSIONS TO ROLES
-- ============================================================

-- ----- DBA Role: Full data access, no DDL DROP -----
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO role_dba;
GRANT EXECUTE                                        TO role_dba;
GRANT VIEW DATABASE STATE                            TO role_dba;   -- Monitor performance
GRANT ALTER ANY USER                                 TO role_dba;
GO

-- ----- HR Role: Employee, Attendance, Leave access -----
GRANT SELECT, INSERT, UPDATE ON dbo.Employees      TO role_hr;
GRANT SELECT, INSERT, UPDATE ON dbo.Attendance     TO role_hr;
GRANT SELECT, INSERT, UPDATE ON dbo.LeaveRequests  TO role_hr;
GRANT SELECT                 ON dbo.Departments    TO role_hr;
GRANT SELECT                 ON dbo.JobTitles      TO role_hr;
GRANT SELECT                 ON dbo.vw_EmployeeDirectory    TO role_hr;
GRANT SELECT                 ON dbo.vw_PendingLeaveRequests TO role_hr;
GRANT SELECT                 ON dbo.vw_MonthlyAttendanceSummary TO role_hr;
GRANT EXECUTE ON dbo.sp_AddEmployee       TO role_hr;
GRANT EXECUTE ON dbo.sp_ProcessLeaveRequest TO role_hr;
GRANT EXECUTE ON dbo.sp_GetEmployeeProfile  TO role_hr;
-- HR cannot see raw salary amounts
DENY  SELECT                 ON dbo.Salaries       TO role_hr;
GO

-- ----- Finance Role: Salary and payroll access -----
GRANT SELECT                 ON dbo.Salaries       TO role_finance;
GRANT SELECT, INSERT, UPDATE ON dbo.Salaries       TO role_finance;
GRANT SELECT                 ON dbo.Employees      TO role_finance;
GRANT SELECT                 ON dbo.Departments    TO role_finance;
GRANT SELECT                 ON dbo.vw_CurrentSalaries   TO role_finance;
GRANT SELECT                 ON dbo.vw_DepartmentSummary  TO role_finance;
GRANT SELECT                 ON dbo.vw_HeadcountByJobGrade TO role_finance;
GRANT EXECUTE ON dbo.sp_UpdateSalary TO role_finance;
GO

-- ----- Reporting Role: Read-only views -----
GRANT SELECT ON dbo.vw_EmployeeDirectory        TO role_reporting;
GRANT SELECT ON dbo.vw_DepartmentSummary        TO role_reporting;
GRANT SELECT ON dbo.vw_MonthlyAttendanceSummary TO role_reporting;
GRANT SELECT ON dbo.vw_HeadcountByJobGrade      TO role_reporting;
-- No access to sensitive salary or raw tables
DENY  SELECT ON dbo.Salaries    TO role_reporting;
DENY  SELECT ON dbo.SystemUsers TO role_reporting;
GO

-- ----- ETL Role: Bulk insert and staging table access -----
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Employees   TO role_etl;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Salaries    TO role_etl;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Departments TO role_etl;
GRANT INSERT                         ON dbo.AuditLog    TO role_etl;
GRANT ADMINISTER BULK OPERATIONS     TO role_etl;   -- Needed for BULK INSERT
GO

-- ============================================================
-- SECTION 6: ROW-LEVEL SECURITY (Advanced DBA)
-- PURPOSE: Department managers can only see their own department
-- ============================================================

-- Security predicate function
CREATE OR ALTER FUNCTION dbo.fn_DeptSecurityFilter(@DepartmentID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS Result
    WHERE
        -- HR and DBA roles see all
        IS_MEMBER('role_hr')  = 1
     OR IS_MEMBER('role_dba') = 1
        -- Managers see only their department (via SystemUsers -> Employees)
     OR EXISTS (
            SELECT 1
            FROM dbo.Employees e
            JOIN dbo.SystemUsers su ON su.EmployeeID = e.EmployeeID
            WHERE su.Username    = USER_NAME()
              AND e.DepartmentID = @DepartmentID
        );
GO

-- Apply security policy
CREATE SECURITY POLICY DeptFilterPolicy
ADD FILTER PREDICATE dbo.fn_DeptSecurityFilter(DepartmentID)
ON dbo.Employees
WITH (STATE = ON);
GO

-- ============================================================
-- SECTION 7: TRANSPARENT DATA ENCRYPTION (TDE)
-- PURPOSE: Encrypts the entire database file at rest
-- ============================================================

-- Create master key
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'MasterKey@Str0ng!2024';
GO

-- Create certificate
CREATE CERTIFICATE EmployeeDB_TDE_Cert
WITH SUBJECT = 'EmployeeDB TDE Certificate',
     EXPIRY_DATE = '2027-12-31';
GO

-- Create database encryption key (AES 256)
USE EmployeeDB;
GO
CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_256
ENCRYPTION BY SERVER CERTIFICATE EmployeeDB_TDE_Cert;
GO

-- Enable TDE on the database
ALTER DATABASE EmployeeDB SET ENCRYPTION ON;
GO

-- Verify TDE is active
SELECT db_name(database_id)    AS DatabaseName,
       encryption_state_desc,
       percent_complete,
       key_algorithm,
       key_length
FROM   sys.dm_database_encryption_keys
WHERE  database_id = DB_ID('EmployeeDB');
GO

-- ============================================================
-- SECTION 8: BACKUP THE TDE CERTIFICATE (CRITICAL DBA TASK)
-- WARNING: Without this backup, you CANNOT restore the database!
-- ============================================================
BACKUP CERTIFICATE EmployeeDB_TDE_Cert
TO FILE = 'C:\SQLBackups\Certificates\EmployeeDB_TDE_Cert.cer'
WITH PRIVATE KEY (
    FILE     = 'C:\SQLBackups\Certificates\EmployeeDB_TDE_Cert.pvk',
    ENCRYPTION BY PASSWORD = 'CertBackup@Str0ng!2024'
);
GO

-- ============================================================
-- SECTION 9: AUDIT — WHO HAS ACCESS? (DBA Health Check)
-- ============================================================

-- Check all database users and their roles
SELECT
    dp.name                 AS UserName,
    dp.type_desc            AS UserType,
    r.name                  AS RoleName,
    dp.create_date,
    dp.is_disabled
FROM sys.database_principals dp
LEFT JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
LEFT JOIN sys.database_principals    r   ON drm.role_principal_id = r.principal_id
WHERE dp.type IN ('S', 'U', 'G')   -- SQL, Windows, Group users
ORDER BY dp.name;
GO

-- Check object-level permissions
SELECT
    USER_NAME(p.grantee_principal_id)   AS Grantee,
    p.permission_name,
    p.state_desc,
    OBJECT_NAME(p.major_id)             AS ObjectName,
    o.type_desc                         AS ObjectType
FROM sys.database_permissions p
JOIN sys.objects o ON p.major_id = o.object_id
WHERE p.grantee_principal_id > 4        -- Skip system principals
ORDER BY Grantee, ObjectName;
GO

PRINT 'Security configuration applied successfully.';
GO
