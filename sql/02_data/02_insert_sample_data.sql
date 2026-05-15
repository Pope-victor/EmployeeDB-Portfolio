-- ============================================================
-- FILE: 02_insert_sample_data.sql
-- PROJECT: Employee Database Management System
-- DESCRIPTION: Inserts realistic sample data for all tables
-- ============================================================

USE EmployeeDB;
GO

-- ============================================================
-- 1. JOB TITLES
-- ============================================================
INSERT INTO JobTitles (JobTitle, JobGrade, MinSalary, MaxSalary, Description)
VALUES
    ('Junior Database Administrator',  'L1', 150000,  350000,  'Entry-level DBA responsible for routine maintenance and monitoring'),
    ('Database Administrator',         'L2', 350000,  600000,  'Mid-level DBA handling backups, performance tuning, and security'),
    ('Senior Database Administrator',  'L3', 600000,  950000,  'Senior DBA responsible for architecture decisions and mentoring'),
    ('Data Engineer',                  'L2', 400000,  700000,  'Designs and maintains data pipelines and ETL processes'),
    ('Senior Data Engineer',           'L3', 700000,  1100000, 'Leads data engineering projects and defines data strategy'),
    ('Software Developer',             'L2', 350000,  650000,  'Develops and maintains business applications'),
    ('Senior Software Developer',      'L3', 650000,  1000000, 'Leads software development projects and reviews code'),
    ('IT Manager',                     'L4', 900000,  1500000, 'Manages IT department teams and strategy'),
    ('HR Officer',                     'L2', 300000,  500000,  'Handles recruitment, onboarding, and employee relations'),
    ('HR Manager',                     'L4', 700000,  1200000, 'Leads human resources strategy and team'),
    ('Finance Analyst',                'L2', 350000,  600000,  'Analyses financial data and prepares reports'),
    ('Finance Manager',                'L4', 800000,  1400000, 'Manages finance team and financial planning'),
    ('Operations Officer',             'L2', 280000,  480000,  'Coordinates day-to-day operational activities'),
    ('CEO',                            'L6', 2000000, 5000000, 'Chief Executive Officer'),
    ('CTO',                            'L5', 1500000, 3000000, 'Chief Technology Officer');
GO

-- ============================================================
-- 2. DEPARTMENTS (without ManagerID first — circular dependency)
-- ============================================================
INSERT INTO Departments (DepartmentName, DepartmentCode, Location, Budget)
VALUES
    ('Information Technology',  'IT001', 'Lagos HQ - Floor 3',    45000000.00),
    ('Human Resources',         'HR001', 'Lagos HQ - Floor 1',    15000000.00),
    ('Finance & Accounts',      'FIN01', 'Lagos HQ - Floor 2',    20000000.00),
    ('Operations',              'OPS01', 'Lagos HQ - Floor 1',    30000000.00),
    ('Executive',               'EXEC1', 'Lagos HQ - Floor 5',    10000000.00),
    ('Data & Analytics',        'DAT01', 'Lagos HQ - Floor 4',    25000000.00);
GO

-- ============================================================
-- 3. EMPLOYEES
-- ============================================================
INSERT INTO Employees (FirstName, LastName, Email, Phone, DateOfBirth, Gender, NationalID,
                       HireDate, EmploymentStatus, DepartmentID, JobTitleID, ManagerID, Address, City, Country)
VALUES
-- Executive
('Chijioke',    'Okafor',   'c.okafor@company.com',    '08012345678',  '1975-03-12', 'M', 'NGA-001-1975', '2010-01-15', 'Active', 5, 14, NULL, '12 Bourdillon Road',       'Lagos', 'Nigeria'),
('Adaeze',      'Nwosu',    'a.nwosu@company.com',     '08023456789',  '1978-07-22', 'F', 'NGA-002-1978', '2010-02-01', 'Active', 5, 15, 1000, '5 Victoria Island',        'Lagos', 'Nigeria'),

-- IT Department
('Emeka',       'Eze',      'e.eze@company.com',       '08034567890',  '1985-11-08', 'M', 'NGA-003-1985', '2015-06-01', 'Active', 1, 8,  1000, '23 Ikeja GRA',             'Lagos', 'Nigeria'),
('Ngozi',       'Obi',      'n.obi@company.com',       '08045678901',  '1990-04-15', 'F', 'NGA-004-1990', '2018-03-01', 'Active', 1, 3,  1002, '7 Allen Avenue',           'Lagos', 'Nigeria'),
('Tunde',       'Adeleke',  't.adeleke@company.com',   '08056789012',  '1993-09-25', 'M', 'NGA-005-1993', '2020-01-10', 'Active', 1, 2,  1003, '15 Oregun Road',           'Lagos', 'Nigeria'),
('Fatima',      'Suleiman', 'f.suleiman@company.com',  '08067890123',  '1995-02-18', 'F', 'NGA-006-1995', '2021-05-01', 'Active', 1, 1,  1003, '9 Kano Street',            'Abuja', 'Nigeria'),
('Olumide',     'Balogun',  'o.balogun@company.com',   '08078901234',  '1992-12-30', 'M', 'NGA-007-1992', '2019-08-15', 'Active', 1, 6,  1002, '42 Lekki Phase 1',         'Lagos', 'Nigeria'),
('Amina',       'Garba',    'a.garba@company.com',     '08089012345',  '1994-06-11', 'F', 'NGA-008-1994', '2022-02-01', 'Active', 1, 6,  1006, '18 Gwarinpa Estate',       'Abuja', 'Nigeria'),

-- Data & Analytics Department
('Chukwuemeka', 'Anyanwu',  'c.anyanwu@company.com',   '08090123456',  '1988-01-20', 'M', 'NGA-009-1988', '2017-04-01', 'Active', 6, 5,  1001, '3 Ademola Adetokunbo',     'Lagos', 'Nigeria'),
('Kemi',        'Adeyemi',  'k.adeyemi@company.com',   '08001234567',  '1991-08-14', 'F', 'NGA-010-1991', '2019-11-01', 'Active', 6, 4,  1008, '21 Herbert Macaulay',      'Lagos', 'Nigeria'),
('Yakubu',      'Ibrahim',  'y.ibrahim@company.com',   '07012345678',  '1996-03-07', 'M', 'NGA-011-1996', '2022-09-01', 'Active', 6, 4,  1008, '6 Maitama District',       'Abuja', 'Nigeria'),

-- HR Department
('Blessing',    'Nkemdirim','b.nkemdirim@company.com', '07023456789',  '1983-10-02', 'F', 'NGA-012-1983', '2014-07-01', 'Active', 2, 10, 1000, '11 Broad Street',          'Lagos', 'Nigeria'),
('Seun',        'Ogundimu', 's.ogundimu@company.com',  '07034567890',  '1989-05-28', 'M', 'NGA-013-1989', '2018-09-01', 'Active', 2, 9,  1011, '34 Ikorodu Road',          'Lagos', 'Nigeria'),
('Patience',    'Okeke',    'p.okeke@company.com',     '07045678901',  '1997-11-16', 'F', 'NGA-014-1997', '2023-01-01', 'Active', 2, 9,  1011, '8 Enugu Close',            'Enugu', 'Nigeria'),

-- Finance Department
('Obinna',      'Okonkwo',  'o.okonkwo@company.com',   '07056789012',  '1982-04-23', 'M', 'NGA-015-1982', '2013-03-01', 'Active', 3, 12, 1000, '2 Marina Street',          'Lagos', 'Nigeria'),
('Hauwa',       'Musa',     'h.musa@company.com',      '07067890123',  '1990-09-09', 'F', 'NGA-016-1990', '2019-06-01', 'Active', 3, 11, 1014, '17 Wuse Zone 3',           'Abuja', 'Nigeria'),
('Emmanuel',    'Ihejirika', 'e.ihejirika@company.com', '07078901234', '1993-07-19', 'M', 'NGA-017-1993', '2021-03-01', 'Active', 3, 11, 1014, '29 Trans-Amadi',           'Port Harcourt', 'Nigeria'),

-- Operations Department
('Grace',       'Uchenna',  'g.uchenna@company.com',   '07089012345',  '1986-12-05', 'F', 'NGA-018-1986', '2016-10-01', 'Active', 4, 13, 1000, '55 Apapa Road',            'Lagos', 'Nigeria'),
('Sule',        'Mohammed', 's.mohammed@company.com',  '07090123456',  '1991-03-14', 'M', 'NGA-019-1991', '2020-07-01', 'Active', 4, 13, 1017, '10 Kaduna South',          'Kaduna', 'Nigeria'),
('Chioma',      'Ugwu',     'c.ugwu@company.com',      '07001234567',  '1998-08-27', 'F', 'NGA-020-1998', '2023-04-01', 'Active', 4, 13, 1017, '44 Independence Layout',   'Enugu', 'Nigeria');
GO

-- ============================================================
-- Update Department Managers (now that Employees exist)
-- ============================================================
UPDATE Departments SET ManagerID = 1002 WHERE DepartmentCode = 'IT001';  -- Emeka Eze
UPDATE Departments SET ManagerID = 1011 WHERE DepartmentCode = 'HR001';  -- Blessing Nkemdirim
UPDATE Departments SET ManagerID = 1014 WHERE DepartmentCode = 'FIN01';  -- Obinna Okonkwo
UPDATE Departments SET ManagerID = 1017 WHERE DepartmentCode = 'OPS01';  -- Grace Uchenna
UPDATE Departments SET ManagerID = 1000 WHERE DepartmentCode = 'EXEC1';  -- Chijioke Okafor
UPDATE Departments SET ManagerID = 1008 WHERE DepartmentCode = 'DAT01';  -- Chukwuemeka Anyanwu
GO

-- ============================================================
-- 4. SALARIES
-- ============================================================
INSERT INTO Salaries (EmployeeID, BasicSalary, HousingAllowance, TransportAllowance, MedicalAllowance, EffectiveDate, Currency)
VALUES
(1000, 2500000, 500000, 150000, 100000, '2010-01-15', 'NGN'),  -- CEO
(1001, 1800000, 400000, 120000, 100000, '2010-02-01', 'NGN'),  -- CTO
(1002, 950000,  250000, 80000,  75000,  '2015-06-01', 'NGN'),  -- IT Manager
(1003, 700000,  180000, 60000,  50000,  '2018-03-01', 'NGN'),  -- Sr DBA
(1004, 450000,  120000, 40000,  35000,  '2020-01-10', 'NGN'),  -- DBA
(1005, 200000,  60000,  30000,  25000,  '2021-05-01', 'NGN'),  -- Jr DBA
(1006, 550000,  140000, 50000,  40000,  '2019-08-15', 'NGN'),  -- Developer
(1007, 380000,  100000, 40000,  35000,  '2022-02-01', 'NGN'),  -- Developer
(1008, 850000,  220000, 70000,  60000,  '2017-04-01', 'NGN'),  -- Sr Data Engineer
(1009, 520000,  130000, 50000,  40000,  '2019-11-01', 'NGN'),  -- Data Engineer
(1010, 430000,  110000, 45000,  35000,  '2022-09-01', 'NGN'),  -- Data Engineer
(1011, 800000,  200000, 70000,  60000,  '2014-07-01', 'NGN'),  -- HR Manager
(1012, 350000,  90000,  40000,  30000,  '2018-09-01', 'NGN'),  -- HR Officer
(1013, 290000,  75000,  35000,  25000,  '2023-01-01', 'NGN'),  -- HR Officer
(1014, 900000,  230000, 75000,  65000,  '2013-03-01', 'NGN'),  -- Finance Manager
(1015, 420000,  110000, 45000,  35000,  '2019-06-01', 'NGN'),  -- Finance Analyst
(1016, 380000,  100000, 40000,  30000,  '2021-03-01', 'NGN'),  -- Finance Analyst
(1017, 450000,  115000, 45000,  35000,  '2016-10-01', 'NGN'),  -- Operations Officer
(1018, 320000,  80000,  35000,  25000,  '2020-07-01', 'NGN'),  -- Operations Officer
(1019, 280000,  70000,  30000,  20000,  '2023-04-01', 'NGN');  -- Operations Officer
GO

-- ============================================================
-- 5. ATTENDANCE (Last 5 working days sample)
-- ============================================================
DECLARE @today DATE = CAST(GETDATE() AS DATE);
DECLARE @eid INT;
DECLARE @d DATE;
DECLARE @status VARCHAR(20);

-- Insert attendance for employees 1000-1019 for recent 5 days
INSERT INTO Attendance (EmployeeID, AttendanceDate, CheckInTime, CheckOutTime, Status)
SELECT
    e.EmployeeID,
    d.AttDate,
    CASE WHEN d.AttDate < @today THEN
        CAST(DATEADD(MINUTE, ABS(CHECKSUM(NEWID())) % 30, '08:00') AS TIME)
    ELSE '08:00' END AS CheckIn,
    CASE WHEN d.AttDate < @today THEN
        CAST(DATEADD(MINUTE, ABS(CHECKSUM(NEWID())) % 60, '17:00') AS TIME)
    ELSE NULL END AS CheckOut,
    CASE
        WHEN ABS(CHECKSUM(NEWID())) % 10 = 0 THEN 'Absent'
        WHEN ABS(CHECKSUM(NEWID())) % 8  = 0 THEN 'Late'
        ELSE 'Present'
    END AS Status
FROM Employees e
CROSS JOIN (
    SELECT DATEADD(DAY, -4, @today) AS AttDate UNION
    SELECT DATEADD(DAY, -3, @today) UNION
    SELECT DATEADD(DAY, -2, @today) UNION
    SELECT DATEADD(DAY, -1, @today) UNION
    SELECT @today
) d
WHERE DATENAME(WEEKDAY, d.AttDate) NOT IN ('Saturday', 'Sunday');
GO

-- ============================================================
-- 6. LEAVE REQUESTS
-- ============================================================
INSERT INTO LeaveRequests (EmployeeID, LeaveType, StartDate, EndDate, Reason, Status, ApprovedBy, ApprovedAt)
VALUES
(1004, 'Annual',       '2024-12-23', '2024-12-31', 'Year-end family vacation',          'Approved',  1003, '2024-12-01 10:00:00'),
(1005, 'Sick',         '2024-11-05', '2024-11-06', 'Fever and malaria treatment',        'Approved',  1003, '2024-11-05 09:00:00'),
(1007, 'Annual',       '2024-10-14', '2024-10-18', 'Personal travel',                   'Approved',  1002, '2024-10-01 11:00:00'),
(1012, 'Sick',         '2024-11-20', '2024-11-21', 'Medical appointment',               'Approved',  1011, '2024-11-20 08:30:00'),
(1016, 'Annual',       '2025-01-06', '2025-01-10', 'New year break extension',           'Pending',   NULL, NULL),
(1009, 'Maternity',    '2025-02-01', '2025-04-30', 'Maternity leave',                   'Approved',  1008, '2025-01-15 14:00:00'),
(1019, 'Annual',       '2025-01-13', '2025-01-17', 'Family wedding',                    'Pending',   NULL, NULL),
(1013, 'Compassionate','2024-12-10', '2024-12-12', 'Bereavement - grandmother passed',  'Approved',  1011, '2024-12-10 07:00:00');
GO

-- ============================================================
-- 7. SYSTEM ROLES & USERS
-- ============================================================
INSERT INTO SystemRoles (RoleName, RoleDescription)
VALUES
    ('Super Admin',    'Full system access — IT Manager and above only'),
    ('HR Admin',       'Access to employee records, leave management, and HR reports'),
    ('Finance Admin',  'Access to salary data and financial reports'),
    ('DBA',            'Database administration access — backup, restore, performance'),
    ('Viewer',         'Read-only access to non-sensitive reports'),
    ('Employee',       'Basic self-service portal access');
GO

INSERT INTO SystemUsers (EmployeeID, Username, PasswordHash, Email, RoleID, IsActive)
VALUES
(1000, 'c.okafor',    HASHBYTES('SHA2_256', 'P@ssw0rd!CEO'),   'c.okafor@company.com',    1, 1),
(1002, 'e.eze',       HASHBYTES('SHA2_256', 'P@ssw0rd!ITMgr'), 'e.eze@company.com',       1, 1),
(1003, 'n.obi',       HASHBYTES('SHA2_256', 'P@ssw0rd!DBA1'),  'n.obi@company.com',       4, 1),
(1004, 't.adeleke',   HASHBYTES('SHA2_256', 'P@ssw0rd!DBA2'),  't.adeleke@company.com',   4, 1),
(1005, 'f.suleiman',  HASHBYTES('SHA2_256', 'P@ssw0rd!JrDBA'), 'f.suleiman@company.com',  4, 1),
(1011, 'b.nkemdirim', HASHBYTES('SHA2_256', 'P@ssw0rd!HRMgr'), 'b.nkemdirim@company.com', 2, 1),
(1014, 'o.okonkwo',   HASHBYTES('SHA2_256', 'P@ssw0rd!Fin'),   'o.okonkwo@company.com',   3, 1);
GO

PRINT 'Sample data inserted successfully.';
GO
