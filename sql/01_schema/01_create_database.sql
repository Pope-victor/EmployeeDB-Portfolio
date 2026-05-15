-- ============================================================
-- FILE: 01_create_database.sql
-- PROJECT: Employee Database Management System
-- AUTHOR: Junior DBA Portfolio Project
-- DATE: 2024
-- DESCRIPTION: Creates the EmployeeDB database and all tables
--              with proper constraints, keys, and relationships
-- ============================================================

USE master;
GO

-- Drop if exists (for dev/testing)
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'EmployeeDB')
BEGIN
    ALTER DATABASE EmployeeDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE EmployeeDB;
END
GO

-- Create the database
CREATE DATABASE EmployeeDB
ON PRIMARY
(
    NAME = 'EmployeeDB_Data',
    FILENAME = 'C:\SQLData\EmployeeDB.mdf',
    SIZE = 100MB,
    MAXSIZE = 1GB,
    FILEGROWTH = 10MB
)
LOG ON
(
    NAME = 'EmployeeDB_Log',
    FILENAME = 'C:\SQLData\EmployeeDB.ldf',
    SIZE = 50MB,
    MAXSIZE = 500MB,
    FILEGROWTH = 5MB
);
GO

USE EmployeeDB;
GO

-- ============================================================
-- TABLE: Departments
-- DESCRIPTION: Stores company departments
-- ============================================================
CREATE TABLE Departments (
    DepartmentID    INT             NOT NULL IDENTITY(1,1),
    DepartmentName  VARCHAR(100)    NOT NULL,
    DepartmentCode  CHAR(5)         NOT NULL,
    ManagerID       INT             NULL,           -- FK added after Employees table
    Location        VARCHAR(150)    NOT NULL,
    Budget          DECIMAL(15,2)   NOT NULL DEFAULT 0.00,
    IsActive        BIT             NOT NULL DEFAULT 1,
    CreatedAt       DATETIME2       NOT NULL DEFAULT GETDATE(),
    UpdatedAt       DATETIME2       NOT NULL DEFAULT GETDATE(),

    -- Primary Key
    CONSTRAINT PK_Departments PRIMARY KEY CLUSTERED (DepartmentID),

    -- Unique Constraints
    CONSTRAINT UQ_Departments_Code UNIQUE (DepartmentCode),
    CONSTRAINT UQ_Departments_Name UNIQUE (DepartmentName),

    -- Check Constraints
    CONSTRAINT CHK_Departments_Budget CHECK (Budget >= 0)
);
GO

-- ============================================================
-- TABLE: JobTitles
-- DESCRIPTION: Lookup table for employee job titles / grades
-- ============================================================
CREATE TABLE JobTitles (
    JobTitleID      INT             NOT NULL IDENTITY(1,1),
    JobTitle        VARCHAR(100)    NOT NULL,
    JobGrade        VARCHAR(10)     NOT NULL,   -- e.g., L1, L2, Senior, Lead
    MinSalary       DECIMAL(12,2)   NOT NULL,
    MaxSalary       DECIMAL(12,2)   NOT NULL,
    Description     VARCHAR(500)    NULL,

    CONSTRAINT PK_JobTitles PRIMARY KEY CLUSTERED (JobTitleID),
    CONSTRAINT UQ_JobTitles_Title UNIQUE (JobTitle),
    CONSTRAINT CHK_JobTitles_Salary CHECK (MaxSalary >= MinSalary AND MinSalary >= 0)
);
GO

-- ============================================================
-- TABLE: Employees
-- DESCRIPTION: Core employee table — normalised (3NF)
-- ============================================================
CREATE TABLE Employees (
    EmployeeID      INT             NOT NULL IDENTITY(1000,1),
    FirstName       VARCHAR(50)     NOT NULL,
    LastName        VARCHAR(50)     NOT NULL,
    Email           VARCHAR(150)    NOT NULL,
    Phone           VARCHAR(20)     NULL,
    DateOfBirth     DATE            NOT NULL,
    Gender          CHAR(1)         NOT NULL,       -- M / F / O
    NationalID      VARCHAR(20)     NOT NULL,
    HireDate        DATE            NOT NULL,
    TerminationDate DATE            NULL,
    EmploymentStatus VARCHAR(20)    NOT NULL DEFAULT 'Active',  -- Active, Inactive, On Leave
    DepartmentID    INT             NOT NULL,
    JobTitleID      INT             NOT NULL,
    ManagerID       INT             NULL,            -- Self-referencing FK
    Address         VARCHAR(255)    NULL,
    City            VARCHAR(100)    NULL,
    Country         VARCHAR(100)    NOT NULL DEFAULT 'Nigeria',
    CreatedAt       DATETIME2       NOT NULL DEFAULT GETDATE(),
    UpdatedAt       DATETIME2       NOT NULL DEFAULT GETDATE(),

    -- Primary Key
    CONSTRAINT PK_Employees PRIMARY KEY CLUSTERED (EmployeeID),

    -- Foreign Keys
    CONSTRAINT FK_Employees_Department FOREIGN KEY (DepartmentID)
        REFERENCES Departments(DepartmentID),
    CONSTRAINT FK_Employees_JobTitle FOREIGN KEY (JobTitleID)
        REFERENCES JobTitles(JobTitleID),
    CONSTRAINT FK_Employees_Manager FOREIGN KEY (ManagerID)
        REFERENCES Employees(EmployeeID),

    -- Unique Constraints
    CONSTRAINT UQ_Employees_Email UNIQUE (Email),
    CONSTRAINT UQ_Employees_NationalID UNIQUE (NationalID),

    -- Check Constraints
    CONSTRAINT CHK_Employees_Gender CHECK (Gender IN ('M', 'F', 'O')),
    CONSTRAINT CHK_Employees_Status CHECK (EmploymentStatus IN ('Active', 'Inactive', 'On Leave', 'Terminated')),
    CONSTRAINT CHK_Employees_TermDate CHECK (TerminationDate IS NULL OR TerminationDate >= HireDate),
    CONSTRAINT CHK_Employees_DOB CHECK (DateOfBirth < HireDate)
);
GO

-- ============================================================
-- TABLE: Salaries
-- DESCRIPTION: Salary history — one row per salary change
-- ============================================================
CREATE TABLE Salaries (
    SalaryID        INT             NOT NULL IDENTITY(1,1),
    EmployeeID      INT             NOT NULL,
    BasicSalary     DECIMAL(12,2)   NOT NULL,
    HousingAllowance DECIMAL(12,2)  NOT NULL DEFAULT 0.00,
    TransportAllowance DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    MedicalAllowance DECIMAL(12,2)  NOT NULL DEFAULT 0.00,
    GrossSalary     AS (BasicSalary + HousingAllowance + TransportAllowance + MedicalAllowance) PERSISTED,
    EffectiveDate   DATE            NOT NULL,
    EndDate         DATE            NULL,
    SalaryType      VARCHAR(20)     NOT NULL DEFAULT 'Monthly',  -- Monthly, Annual
    Currency        CHAR(3)         NOT NULL DEFAULT 'NGN',
    CreatedBy       INT             NULL,
    CreatedAt       DATETIME2       NOT NULL DEFAULT GETDATE(),

    -- Primary Key
    CONSTRAINT PK_Salaries PRIMARY KEY CLUSTERED (SalaryID),

    -- Foreign Keys
    CONSTRAINT FK_Salaries_Employee FOREIGN KEY (EmployeeID)
        REFERENCES Employees(EmployeeID),

    -- Check Constraints
    CONSTRAINT CHK_Salaries_Basic CHECK (BasicSalary > 0),
    CONSTRAINT CHK_Salaries_EndDate CHECK (EndDate IS NULL OR EndDate >= EffectiveDate),
    CONSTRAINT CHK_Salaries_Type CHECK (SalaryType IN ('Monthly', 'Annual'))
);
GO

-- ============================================================
-- TABLE: Attendance
-- DESCRIPTION: Daily employee attendance records
-- ============================================================
CREATE TABLE Attendance (
    AttendanceID    INT             NOT NULL IDENTITY(1,1),
    EmployeeID      INT             NOT NULL,
    AttendanceDate  DATE            NOT NULL,
    CheckInTime     TIME            NULL,
    CheckOutTime    TIME            NULL,
    Status          VARCHAR(20)     NOT NULL DEFAULT 'Present',  -- Present, Absent, Late, Half Day, Leave
    WorkHours       AS (
                        CASE
                            WHEN CheckInTime IS NOT NULL AND CheckOutTime IS NOT NULL
                            THEN CAST(DATEDIFF(MINUTE, CheckInTime, CheckOutTime) / 60.0 AS DECIMAL(5,2))
                            ELSE 0
                        END
                    ) PERSISTED,
    Notes           VARCHAR(255)    NULL,
    RecordedBy      INT             NULL,
    CreatedAt       DATETIME2       NOT NULL DEFAULT GETDATE(),

    -- Primary Key
    CONSTRAINT PK_Attendance PRIMARY KEY CLUSTERED (AttendanceID),

    -- Foreign Keys
    CONSTRAINT FK_Attendance_Employee FOREIGN KEY (EmployeeID)
        REFERENCES Employees(EmployeeID),

    -- Unique: One record per employee per day
    CONSTRAINT UQ_Attendance_EmployeeDate UNIQUE (EmployeeID, AttendanceDate),

    -- Check Constraints
    CONSTRAINT CHK_Attendance_Status CHECK (Status IN ('Present', 'Absent', 'Late', 'Half Day', 'Leave', 'Holiday')),
    CONSTRAINT CHK_Attendance_CheckOut CHECK (CheckOutTime IS NULL OR CheckOutTime > CheckInTime)
);
GO

-- ============================================================
-- TABLE: LeaveRequests
-- DESCRIPTION: Employee leave application and approval tracking
-- ============================================================
CREATE TABLE LeaveRequests (
    LeaveID         INT             NOT NULL IDENTITY(1,1),
    EmployeeID      INT             NOT NULL,
    LeaveType       VARCHAR(30)     NOT NULL,   -- Annual, Sick, Maternity, Paternity, Unpaid
    StartDate       DATE            NOT NULL,
    EndDate         DATE            NOT NULL,
    TotalDays       AS (DATEDIFF(DAY, StartDate, EndDate) + 1) PERSISTED,
    Reason          VARCHAR(500)    NULL,
    Status          VARCHAR(20)     NOT NULL DEFAULT 'Pending',  -- Pending, Approved, Rejected
    ApprovedBy      INT             NULL,
    ApprovedAt      DATETIME2       NULL,
    CreatedAt       DATETIME2       NOT NULL DEFAULT GETDATE(),

    -- Primary Key
    CONSTRAINT PK_LeaveRequests PRIMARY KEY CLUSTERED (LeaveID),

    -- Foreign Keys
    CONSTRAINT FK_Leave_Employee FOREIGN KEY (EmployeeID)
        REFERENCES Employees(EmployeeID),
    CONSTRAINT FK_Leave_Approver FOREIGN KEY (ApprovedBy)
        REFERENCES Employees(EmployeeID),

    -- Check Constraints
    CONSTRAINT CHK_Leave_Type CHECK (LeaveType IN ('Annual', 'Sick', 'Maternity', 'Paternity', 'Unpaid', 'Compassionate')),
    CONSTRAINT CHK_Leave_Status CHECK (Status IN ('Pending', 'Approved', 'Rejected', 'Cancelled')),
    CONSTRAINT CHK_Leave_Dates CHECK (EndDate >= StartDate)
);
GO

-- ============================================================
-- TABLE: SystemRoles
-- DESCRIPTION: Application roles for RBAC (Role-Based Access Control)
-- ============================================================
CREATE TABLE SystemRoles (
    RoleID          INT             NOT NULL IDENTITY(1,1),
    RoleName        VARCHAR(50)     NOT NULL,
    RoleDescription VARCHAR(255)    NULL,
    IsActive        BIT             NOT NULL DEFAULT 1,

    CONSTRAINT PK_SystemRoles PRIMARY KEY CLUSTERED (RoleID),
    CONSTRAINT UQ_SystemRoles_Name UNIQUE (RoleName)
);
GO

-- ============================================================
-- TABLE: SystemUsers
-- DESCRIPTION: Application users linked to employees
-- ============================================================
CREATE TABLE SystemUsers (
    UserID          INT             NOT NULL IDENTITY(1,1),
    EmployeeID      INT             NULL,
    Username        VARCHAR(50)     NOT NULL,
    PasswordHash    VARBINARY(256)  NOT NULL,
    Email           VARCHAR(150)    NOT NULL,
    RoleID          INT             NOT NULL,
    IsActive        BIT             NOT NULL DEFAULT 1,
    LastLoginAt     DATETIME2       NULL,
    FailedLoginCount INT            NOT NULL DEFAULT 0,
    IsLocked        BIT             NOT NULL DEFAULT 0,
    CreatedAt       DATETIME2       NOT NULL DEFAULT GETDATE(),

    -- Primary Key
    CONSTRAINT PK_SystemUsers PRIMARY KEY CLUSTERED (UserID),

    -- Foreign Keys
    CONSTRAINT FK_SystemUsers_Employee FOREIGN KEY (EmployeeID)
        REFERENCES Employees(EmployeeID),
    CONSTRAINT FK_SystemUsers_Role FOREIGN KEY (RoleID)
        REFERENCES SystemRoles(RoleID),

    -- Unique Constraints
    CONSTRAINT UQ_SystemUsers_Username UNIQUE (Username),
    CONSTRAINT UQ_SystemUsers_Email UNIQUE (Email),

    -- Check Constraints
    CONSTRAINT CHK_SystemUsers_FailedLogin CHECK (FailedLoginCount >= 0)
);
GO

-- ============================================================
-- TABLE: AuditLog
-- DESCRIPTION: Tracks all changes to critical tables (DBA requirement)
-- ============================================================
CREATE TABLE AuditLog (
    AuditID         BIGINT          NOT NULL IDENTITY(1,1),
    TableName       VARCHAR(100)    NOT NULL,
    RecordID        INT             NOT NULL,
    Action          VARCHAR(10)     NOT NULL,   -- INSERT, UPDATE, DELETE
    OldValues       NVARCHAR(MAX)   NULL,
    NewValues       NVARCHAR(MAX)   NULL,
    ChangedBy       VARCHAR(100)    NOT NULL DEFAULT SYSTEM_USER,
    ChangedAt       DATETIME2       NOT NULL DEFAULT GETDATE(),
    IPAddress       VARCHAR(50)     NULL,

    CONSTRAINT PK_AuditLog PRIMARY KEY CLUSTERED (AuditID),
    CONSTRAINT CHK_AuditLog_Action CHECK (Action IN ('INSERT', 'UPDATE', 'DELETE'))
);
GO

-- ============================================================
-- ADD DEFERRED FOREIGN KEY: Departments.ManagerID -> Employees
-- (Added after Employees table exists)
-- ============================================================
ALTER TABLE Departments
ADD CONSTRAINT FK_Departments_Manager FOREIGN KEY (ManagerID)
    REFERENCES Employees(EmployeeID);
GO

PRINT 'EmployeeDB schema created successfully.';
GO
