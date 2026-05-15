-- ============================================================
-- FILE: 03_queries.sql
-- PROJECT: Employee Database Management System
-- DESCRIPTION: Complex SELECT queries, JOINs, aggregates,
--              CTEs, and window functions for reporting
-- ============================================================

USE EmployeeDB;
GO

-- ============================================================
-- QUERY 1: Full Employee Directory with Department & Title
-- Demonstrates: INNER JOIN, multiple tables
-- ============================================================
SELECT
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName   AS FullName,
    e.Email,
    e.Phone,
    e.Gender,
    e.EmploymentStatus,
    e.HireDate,
    d.DepartmentName,
    j.JobTitle,
    j.JobGrade,
    m.FirstName + ' ' + m.LastName   AS ManagerName
FROM Employees e
INNER JOIN Departments d    ON e.DepartmentID = d.DepartmentID
INNER JOIN JobTitles j      ON e.JobTitleID   = j.JobTitleID
LEFT  JOIN Employees m      ON e.ManagerID    = m.EmployeeID
WHERE e.EmploymentStatus = 'Active'
ORDER BY d.DepartmentName, e.LastName;
GO

-- ============================================================
-- QUERY 2: Salary Summary per Department
-- Demonstrates: GROUP BY, aggregate functions, HAVING
-- ============================================================
SELECT
    d.DepartmentName,
    COUNT(e.EmployeeID)              AS TotalEmployees,
    MIN(s.GrossSalary)               AS MinSalary,
    MAX(s.GrossSalary)               AS MaxSalary,
    AVG(s.GrossSalary)               AS AvgSalary,
    SUM(s.GrossSalary)               AS TotalMonthlyPayroll,
    SUM(s.GrossSalary) * 12          AS AnnualPayroll
FROM Employees e
INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID
INNER JOIN Salaries    s ON e.EmployeeID   = s.EmployeeID
WHERE e.EmploymentStatus = 'Active'
  AND s.EndDate IS NULL           -- Current salary only
GROUP BY d.DepartmentName
HAVING COUNT(e.EmployeeID) > 0
ORDER BY TotalMonthlyPayroll DESC;
GO

-- ============================================================
-- QUERY 3: Employee Attendance Summary (Last 30 Days)
-- Demonstrates: Date functions, CASE expression, aggregates
-- ============================================================
SELECT
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName AS FullName,
    d.DepartmentName,
    COUNT(a.AttendanceID)           AS TotalDaysRecorded,
    SUM(CASE WHEN a.Status = 'Present'  THEN 1 ELSE 0 END) AS DaysPresent,
    SUM(CASE WHEN a.Status = 'Absent'   THEN 1 ELSE 0 END) AS DaysAbsent,
    SUM(CASE WHEN a.Status = 'Late'     THEN 1 ELSE 0 END) AS DaysLate,
    SUM(CASE WHEN a.Status = 'Leave'    THEN 1 ELSE 0 END) AS DaysOnLeave,
    ROUND(AVG(a.WorkHours), 2)     AS AvgWorkHoursPerDay,
    CAST(
        SUM(CASE WHEN a.Status = 'Present' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(a.AttendanceID), 0)
    AS DECIMAL(5,2))               AS AttendancePct
FROM Employees e
INNER JOIN Departments d ON e.DepartmentID  = d.DepartmentID
INNER JOIN Attendance  a ON e.EmployeeID    = a.EmployeeID
WHERE a.AttendanceDate >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY e.EmployeeID, e.FirstName, e.LastName, d.DepartmentName
ORDER BY AttendancePct DESC;
GO

-- ============================================================
-- QUERY 4: Top Earners per Department using Window Function
-- Demonstrates: ROW_NUMBER(), PARTITION BY, CTE
-- ============================================================
WITH RankedSalaries AS (
    SELECT
        e.EmployeeID,
        e.FirstName + ' ' + e.LastName AS FullName,
        d.DepartmentName,
        j.JobTitle,
        s.GrossSalary,
        ROW_NUMBER() OVER (
            PARTITION BY d.DepartmentID
            ORDER BY s.GrossSalary DESC
        ) AS SalaryRankInDept,
        RANK() OVER (ORDER BY s.GrossSalary DESC) AS OverallRank
    FROM Employees e
    INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID
    INNER JOIN JobTitles   j ON e.JobTitleID   = j.JobTitleID
    INNER JOIN Salaries    s ON e.EmployeeID   = s.EmployeeID
    WHERE s.EndDate IS NULL AND e.EmploymentStatus = 'Active'
)
SELECT *
FROM RankedSalaries
WHERE SalaryRankInDept <= 3       -- Top 3 earners per department
ORDER BY DepartmentName, SalaryRankInDept;
GO

-- ============================================================
-- QUERY 5: Employees with No Attendance Record This Week
-- Demonstrates: LEFT JOIN with NULL check, date logic
-- ============================================================
SELECT
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName  AS FullName,
    e.Email,
    d.DepartmentName,
    m.FirstName + ' ' + m.LastName  AS ManagerName,
    m.Email                          AS ManagerEmail
FROM Employees e
INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID
LEFT  JOIN Employees   m ON e.ManagerID    = m.EmployeeID
LEFT  JOIN Attendance  a ON e.EmployeeID   = a.EmployeeID
                         AND a.AttendanceDate >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE))
WHERE e.EmploymentStatus = 'Active'
  AND a.AttendanceID IS NULL        -- No attendance record found
ORDER BY d.DepartmentName, e.LastName;
GO

-- ============================================================
-- QUERY 6: Pending Leave Requests with Employee & Manager Info
-- Demonstrates: Multi-table JOIN, filtered query
-- ============================================================
SELECT
    lr.LeaveID,
    e.FirstName + ' ' + e.LastName  AS EmployeeName,
    d.DepartmentName,
    lr.LeaveType,
    lr.StartDate,
    lr.EndDate,
    lr.TotalDays,
    lr.Reason,
    lr.Status,
    m.FirstName + ' ' + m.LastName  AS ReportingManager,
    m.Email                          AS ManagerEmail,
    DATEDIFF(DAY, GETDATE(), lr.StartDate) AS DaysUntilLeaveStarts
FROM LeaveRequests lr
INNER JOIN Employees   e ON lr.EmployeeID  = e.EmployeeID
INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID
LEFT  JOIN Employees   m ON e.ManagerID    = m.EmployeeID
WHERE lr.Status = 'Pending'
ORDER BY lr.StartDate;
GO

-- ============================================================
-- QUERY 7: Headcount and Tenure Analysis
-- Demonstrates: DATEDIFF, CASE expression for grouping
-- ============================================================
SELECT
    d.DepartmentName,
    e.FirstName + ' ' + e.LastName     AS FullName,
    e.HireDate,
    DATEDIFF(YEAR, e.HireDate, GETDATE()) AS YearsOfService,
    CASE
        WHEN DATEDIFF(YEAR, e.HireDate, GETDATE()) < 2  THEN '0-2 Years'
        WHEN DATEDIFF(YEAR, e.HireDate, GETDATE()) < 5  THEN '2-5 Years'
        WHEN DATEDIFF(YEAR, e.HireDate, GETDATE()) < 10 THEN '5-10 Years'
        ELSE '10+ Years'
    END AS TenureBucket,
    DATEDIFF(YEAR, e.DateOfBirth, GETDATE()) AS Age
FROM Employees e
INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID
WHERE e.EmploymentStatus = 'Active'
ORDER BY YearsOfService DESC;
GO

-- ============================================================
-- QUERY 8: Gender Diversity Report per Department
-- Demonstrates: PIVOT-style aggregation
-- ============================================================
SELECT
    d.DepartmentName,
    COUNT(e.EmployeeID)                                          AS TotalEmployees,
    SUM(CASE WHEN e.Gender = 'M' THEN 1 ELSE 0 END)             AS MaleCount,
    SUM(CASE WHEN e.Gender = 'F' THEN 1 ELSE 0 END)             AS FemaleCount,
    CAST(
        SUM(CASE WHEN e.Gender = 'F' THEN 1.0 ELSE 0 END)
        / NULLIF(COUNT(e.EmployeeID), 0) * 100
    AS DECIMAL(5,1))                                             AS FemalePercent
FROM Employees e
INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID
WHERE e.EmploymentStatus = 'Active'
GROUP BY d.DepartmentName
ORDER BY FemalePercent DESC;
GO

-- ============================================================
-- QUERY 9: Year-on-Year Hiring Trend
-- Demonstrates: GROUP BY with date functions
-- ============================================================
SELECT
    YEAR(HireDate)    AS HireYear,
    MONTH(HireDate)   AS HireMonth,
    DATENAME(MONTH, HireDate) AS MonthName,
    COUNT(EmployeeID) AS NewHires
FROM Employees
GROUP BY YEAR(HireDate), MONTH(HireDate), DATENAME(MONTH, HireDate)
ORDER BY HireYear, HireMonth;
GO

-- ============================================================
-- QUERY 10: DBA Diagnostic — Find Salary Gaps (No Current Salary)
-- Demonstrates: NOT EXISTS / NOT IN for data quality check
-- ============================================================
SELECT
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName AS FullName,
    e.EmploymentStatus,
    e.HireDate
FROM Employees e
WHERE e.EmploymentStatus = 'Active'
  AND NOT EXISTS (
        SELECT 1
        FROM Salaries s
        WHERE s.EmployeeID = e.EmployeeID
          AND s.EndDate IS NULL       -- No current active salary
  );
GO

PRINT 'All queries executed successfully.';
GO
