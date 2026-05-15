-- ============================================================
-- FILE: 05_views.sql
-- PROJECT: Employee Database Management System
-- DESCRIPTION: Database views for reporting and simplified access
-- ============================================================

USE EmployeeDB;
GO

-- ============================================================
-- VIEW 1: vw_EmployeeDirectory
-- PURPOSE: Full employee details for HR and management reporting
-- ============================================================
CREATE OR ALTER VIEW vw_EmployeeDirectory AS
SELECT
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    e.FirstName + ' ' + e.LastName   AS FullName,
    e.Email,
    e.Phone,
    e.Gender,
    e.DateOfBirth,
    DATEDIFF(YEAR, e.DateOfBirth, GETDATE())  AS Age,
    e.HireDate,
    DATEDIFF(YEAR, e.HireDate, GETDATE())     AS YearsOfService,
    e.EmploymentStatus,
    e.City,
    e.Country,
    d.DepartmentID,
    d.DepartmentName,
    d.DepartmentCode,
    j.JobTitle,
    j.JobGrade,
    m.FirstName + ' ' + m.LastName            AS ManagerName,
    m.Email                                   AS ManagerEmail
FROM Employees e
INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID
INNER JOIN JobTitles   j ON e.JobTitleID   = j.JobTitleID
LEFT  JOIN Employees   m ON e.ManagerID    = m.EmployeeID;
GO

-- ============================================================
-- VIEW 2: vw_CurrentSalaries
-- PURPOSE: Current (active) salary for every employee.
--          Hides sensitive raw tables from non-DBA users.
-- ============================================================
CREATE OR ALTER VIEW vw_CurrentSalaries AS
SELECT
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName  AS FullName,
    d.DepartmentName,
    j.JobTitle,
    s.BasicSalary,
    s.HousingAllowance,
    s.TransportAllowance,
    s.MedicalAllowance,
    s.GrossSalary,
    s.Currency,
    s.EffectiveDate                 AS SalaryEffectiveDate
FROM Employees e
INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID
INNER JOIN JobTitles   j ON e.JobTitleID   = j.JobTitleID
INNER JOIN Salaries    s ON e.EmployeeID   = s.EmployeeID
                         AND s.EndDate IS NULL      -- Current salary only
WHERE e.EmploymentStatus = 'Active';
GO

-- ============================================================
-- VIEW 3: vw_DepartmentSummary
-- PURPOSE: Headcount and payroll summary per department
-- ============================================================
CREATE OR ALTER VIEW vw_DepartmentSummary AS
SELECT
    d.DepartmentID,
    d.DepartmentName,
    d.DepartmentCode,
    d.Location,
    d.Budget,
    mgr.FirstName + ' ' + mgr.LastName  AS DepartmentManager,
    COUNT(e.EmployeeID)                 AS TotalEmployees,
    SUM(CASE WHEN e.Gender = 'M' THEN 1 ELSE 0 END) AS MaleCount,
    SUM(CASE WHEN e.Gender = 'F' THEN 1 ELSE 0 END) AS FemaleCount,
    SUM(s.GrossSalary)                  AS MonthlyPayroll,
    SUM(s.GrossSalary) * 12             AS AnnualPayroll,
    AVG(s.GrossSalary)                  AS AvgSalary,
    d.Budget - SUM(s.GrossSalary) * 12  AS BudgetVariance
FROM Departments d
LEFT JOIN Employees   e   ON d.DepartmentID = e.DepartmentID AND e.EmploymentStatus = 'Active'
LEFT JOIN Employees   mgr ON d.ManagerID    = mgr.EmployeeID
LEFT JOIN Salaries    s   ON e.EmployeeID   = s.EmployeeID AND s.EndDate IS NULL
GROUP BY
    d.DepartmentID, d.DepartmentName, d.DepartmentCode,
    d.Location, d.Budget,
    mgr.FirstName, mgr.LastName;
GO

-- ============================================================
-- VIEW 4: vw_MonthlyAttendanceSummary
-- PURPOSE: Current-month attendance KPIs for all employees
-- ============================================================
CREATE OR ALTER VIEW vw_MonthlyAttendanceSummary AS
SELECT
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName   AS FullName,
    d.DepartmentName,
    MONTH(a.AttendanceDate)           AS AttMonth,
    YEAR(a.AttendanceDate)            AS AttYear,
    COUNT(a.AttendanceID)             AS TotalRecorded,
    SUM(CASE WHEN a.Status = 'Present'  THEN 1 ELSE 0 END) AS Present,
    SUM(CASE WHEN a.Status = 'Absent'   THEN 1 ELSE 0 END) AS Absent,
    SUM(CASE WHEN a.Status = 'Late'     THEN 1 ELSE 0 END) AS Late,
    SUM(CASE WHEN a.Status = 'Leave'    THEN 1 ELSE 0 END) AS OnLeave,
    ROUND(AVG(a.WorkHours), 2)        AS AvgDailyHours,
    CAST(
        SUM(CASE WHEN a.Status = 'Present' THEN 1.0 ELSE 0 END)
        / NULLIF(COUNT(a.AttendanceID), 0) * 100
    AS DECIMAL(5,1))                  AS AttendancePct
FROM Employees e
INNER JOIN Departments d ON e.DepartmentID  = d.DepartmentID
INNER JOIN Attendance  a ON e.EmployeeID    = a.EmployeeID
GROUP BY e.EmployeeID, e.FirstName, e.LastName, d.DepartmentName,
         MONTH(a.AttendanceDate), YEAR(a.AttendanceDate);
GO

-- ============================================================
-- VIEW 5: vw_PendingLeaveRequests
-- PURPOSE: All pending leave requests with approver info
-- ============================================================
CREATE OR ALTER VIEW vw_PendingLeaveRequests AS
SELECT
    lr.LeaveID,
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName  AS EmployeeName,
    d.DepartmentName,
    lr.LeaveType,
    lr.StartDate,
    lr.EndDate,
    lr.TotalDays,
    lr.Reason,
    lr.CreatedAt                    AS RequestedOn,
    DATEDIFF(DAY, GETDATE(), lr.StartDate) AS DaysToLeaveStart,
    m.FirstName + ' ' + m.LastName  AS ReportingManager,
    m.Email                         AS ManagerEmail
FROM LeaveRequests lr
INNER JOIN Employees   e ON lr.EmployeeID  = e.EmployeeID
INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID
LEFT  JOIN Employees   m ON e.ManagerID    = m.EmployeeID
WHERE lr.Status = 'Pending';
GO

-- ============================================================
-- VIEW 6: vw_HeadcountByJobGrade
-- PURPOSE: Salary band / grade distribution report
-- ============================================================
CREATE OR ALTER VIEW vw_HeadcountByJobGrade AS
SELECT
    j.JobGrade,
    j.JobTitle,
    COUNT(e.EmployeeID)      AS Headcount,
    MIN(s.GrossSalary)       AS MinGross,
    MAX(s.GrossSalary)       AS MaxGross,
    AVG(s.GrossSalary)       AS AvgGross,
    j.MinSalary              AS BandMin,
    j.MaxSalary              AS BandMax
FROM Employees e
INNER JOIN JobTitles j ON e.JobTitleID = j.JobTitleID
INNER JOIN Salaries  s ON e.EmployeeID = s.EmployeeID AND s.EndDate IS NULL
WHERE e.EmploymentStatus = 'Active'
GROUP BY j.JobGrade, j.JobTitle, j.MinSalary, j.MaxSalary;
GO

PRINT 'All views created successfully.';
GO
