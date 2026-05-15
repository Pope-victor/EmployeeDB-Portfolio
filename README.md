# 🗄️ Employee Database Management System

### A Full-Stack Database Administration Portfolio Project

![SQL Server](https://img.shields.io/badge/SQL%20Server-2019%2F2022-CC2927?logo=microsoft-sql-server&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python&logoColor=white)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen)
![Level](https://img.shields.io/badge/Level-Junior%20DBA-blue)

---

## 📌 Project Overview

This project demonstrates practical **Database Administration (DBA)** and **beginner Data Engineering** skills through a realistic Employee Management System built on SQL Server.

It covers the full DBA lifecycle:
- **Database Design** — normalised schema, constraints, relationships
- **SQL Development** — complex queries, stored procedures, views
- **DBA Operations** — backup, recovery, user security, encryption
- **Performance Tuning** — indexes, query optimisation, monitoring
- **Data Engineering** — Python ETL pipeline (Extract → Transform → Load)

---

## 📁 Project Structure

```
EmployeeDB_Portfolio/
│
├── sql/
│   ├── 01_schema/
│   │   └── 01_create_database.sql          # Full schema: tables, PKs, FKs, constraints
│   ├── 02_data/
│   │   └── 02_insert_sample_data.sql       # 20 realistic employees + all related data
│   ├── 03_queries/
│   │   └── 03_complex_queries.sql          # 10 complex queries: JOINs, CTEs, window funcs
│   ├── 04_stored_procedures/
│   │   └── 04_stored_procedures.sql        # 5 business-logic stored procedures
│   ├── 05_views/
│   │   └── 05_views.sql                    # 6 reporting views
│   ├── 06_backup_recovery/
│   │   └── 06_backup_recovery.sql          # Full/Diff/Log backup + restore scripts
│   ├── 07_security/
│   │   └── 07_security_permissions.sql     # Logins, roles, permissions, TDE, RLS
│   └── 08_performance/
│       └── 08_performance_optimization.sql # Indexes, query tuning, monitoring DMVs
│
├── etl/
│   ├── data/
│   │   └── new_employees.csv               # 15 employees to import via ETL
│   └── scripts/
│       └── etl_pipeline.py                 # Python ETL: Extract → Transform → Load
│
├── docs/
│   └── README.md                           # This file
└── portfolio/
    └── portfolio_content.md                # Resume bullets, LinkedIn summary, GitHub bio
```

---

## 🗂️ Database Schema

### Entity Relationship Overview

```
JobTitles ──────┐
                ├── Employees ──── Departments
Departments ────┘       │
                        ├── Salaries
                        ├── Attendance
                        ├── LeaveRequests
                        └── SystemUsers ── SystemRoles
                                │
                                └── AuditLog (tracks all changes)
```

### Tables

| Table           | Purpose                                          | Key Columns                                  |
|-----------------|--------------------------------------------------|----------------------------------------------|
| `Employees`     | Core employee records (20 sample rows)           | EmployeeID, DepartmentID, JobTitleID, ManagerID |
| `Departments`   | Company departments with budget tracking         | DepartmentID, ManagerID, Budget              |
| `JobTitles`     | Job title lookup with salary bands               | JobTitleID, JobGrade, MinSalary, MaxSalary   |
| `Salaries`      | Full salary history per employee                 | SalaryID, GrossSalary (computed), EffectiveDate |
| `Attendance`    | Daily attendance with check-in/out times         | WorkHours (computed), Status                 |
| `LeaveRequests` | Leave applications and approval workflow         | TotalDays (computed), Status, ApprovedBy     |
| `SystemUsers`   | Application logins linked to employees           | PasswordHash (SHA2-256), RoleID              |
| `SystemRoles`   | RBAC roles (Admin, HR, Finance, DBA, Viewer)     | RoleName, RoleDescription                    |
| `AuditLog`      | Tracks INSERT/UPDATE/DELETE on critical tables   | OldValues, NewValues (JSON), ChangedBy       |

### Design Principles Applied
- **3rd Normal Form (3NF)** — No transitive dependencies
- **Computed columns** — GrossSalary, WorkHours, TotalDays (persisted)
- **Self-referencing FK** — Employees.ManagerID → Employees.EmployeeID
- **Deferred FK** — Departments.ManagerID added after Employees table exists
- **Filtered indexes** — Only index Active employees (smaller, faster)
- **Audit trail** — AuditLog captures all data changes with timestamps

---

## 🚀 Setup Instructions

### Prerequisites
- SQL Server 2019 or 2022 (Developer Edition — free)
- SQL Server Management Studio (SSMS) 19+
- Python 3.10+ (for ETL only)
- Git

### Step 1: Clone the Repository
```bash
git clone https://github.com/yourusername/EmployeeDB-Portfolio.git
cd EmployeeDB-Portfolio
```

### Step 2: Create Folders on Your SQL Server
```
C:\SQLData\       — Database files (.mdf, .ldf)
C:\SQLBackups\    — Backup files (.bak, .trn)
C:\SQLBackups\Certificates\  — TDE certificate backups
```

### Step 3: Run SQL Scripts in Order
Open SSMS and run scripts in this order:

```
1. sql/01_schema/01_create_database.sql
2. sql/02_data/02_insert_sample_data.sql
3. sql/03_queries/03_complex_queries.sql
4. sql/04_stored_procedures/04_stored_procedures.sql
5. sql/05_views/05_views.sql
6. sql/06_backup_recovery/06_backup_recovery.sql
7. sql/07_security/07_security_permissions.sql
8. sql/08_performance/08_performance_optimization.sql
```

### Step 4: Run the Python ETL Pipeline
```bash
cd etl/scripts
pip install pandas pyodbc sqlalchemy loguru
python etl_pipeline.py
```

> ⚙️ Update `DB_CONFIG` in `etl_pipeline.py` with your SQL Server name and credentials.

---

## 🔑 Key Features Demonstrated

### Database Administration
| Task | Script | Technique |
|------|--------|-----------|
| Full backup | `06_backup_recovery.sql` | `BACKUP DATABASE ... WITH COMPRESSION, CHECKSUM` |
| Point-in-time recovery | `06_backup_recovery.sql` | `RESTORE LOG ... WITH STOPAT` |
| User + role management | `07_security_permissions.sql` | `CREATE LOGIN`, `CREATE ROLE`, `GRANT/DENY` |
| Transparent Data Encryption | `07_security_permissions.sql` | TDE with AES-256 |
| Row-Level Security | `07_security_permissions.sql` | `CREATE SECURITY POLICY` |
| Index fragmentation analysis | `08_performance_optimization.sql` | `sys.dm_db_index_physical_stats` |
| Slow query identification | `08_performance_optimization.sql` | `sys.dm_exec_query_stats` |
| Missing index suggestions | `08_performance_optimization.sql` | `sys.dm_db_missing_index_details` |

### SQL Development
| Feature | Example |
|---------|---------|
| Window functions | `ROW_NUMBER() OVER (PARTITION BY DepartmentID)` |
| CTEs | `WITH RankedSalaries AS (...)` |
| Filtered indexes | `WHERE EmploymentStatus = 'Active'` |
| Computed columns | `GrossSalary AS (Basic + Housing + Transport + Medical) PERSISTED` |
| Self-referencing FK | `ManagerID REFERENCES Employees(EmployeeID)` |
| Dynamic SQL | `sp_DatabaseBackup` uses `EXEC sp_executesql` |
| Error handling | All SPs use `BEGIN TRY / BEGIN CATCH / RAISERROR` |
| Transactions | All write SPs wrapped in `BEGIN / COMMIT / ROLLBACK` |

### Python ETL Pipeline
- **Extract** — Reads CSV with `pandas`, handles encoding
- **Transform** — Email regex validation, phone normalisation, date parsing, salary type conversion, duplicate detection, rejection log
- **Load** — Idempotent inserts (skips duplicates), foreign key lookups, full error handling, structured logging with `loguru`

---

## 📊 Sample Queries to Try

```sql
-- 1. View all active employees with salaries
SELECT * FROM vw_CurrentSalaries;

-- 2. Department payroll summary
SELECT * FROM vw_DepartmentSummary ORDER BY MonthlyPayroll DESC;

-- 3. Add a new employee
DECLARE @NewID INT;
EXEC sp_AddEmployee
    @FirstName = 'Adaeze', @LastName = 'Obi',
    @Email = 'a.obi@company.com', @DateOfBirth = '1995-06-01',
    @Gender = 'F', @NationalID = 'NGA-TEST-001',
    @HireDate = '2024-01-15', @DepartmentID = 1,
    @JobTitleID = 1, @BasicSalary = 180000,
    @NewEmployeeID = @NewID OUTPUT;
PRINT 'New Employee ID: ' + CAST(@NewID AS VARCHAR);

-- 4. View performance stats
SELECT * FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED');
```

---

## 🛡️ Security Architecture

```
Server Level:        login_dba_admin | login_hr_user | login_finance_user
                            ↓               ↓               ↓
Database Level:       user_dba_admin | user_hr_user  | user_finance_user
                            ↓               ↓               ↓
Role Level:           role_dba       | role_hr       | role_finance
                            ↓               ↓               ↓
Object Permissions:   FULL DATA      | Employee/Leave | Salary/Payroll
                            ↓               ↓               ↓
Additional:           Row-Level Security (dept filter) + TDE (AES-256)
```

---

## 🧰 Technologies Used

| Technology | Purpose |
|------------|---------|
| **SQL Server 2019/2022** | Primary RDBMS |
| **T-SQL** | Stored procedures, views, queries |
| **Python 3.10+** | ETL pipeline |
| **pandas** | CSV extraction and transformation |
| **pyodbc** | SQL Server connection from Python |
| **loguru** | Structured ETL logging |
| **Git / GitHub** | Version control |

---

## 👤 Author

**[Your Name]**
Junior Database Administrator | Data Engineering Enthusiast

- 📧 youremail@gmail.com
- 💼 [LinkedIn](https://linkedin.com/in/yourprofile)
- 🐙 [GitHub](https://github.com/yourusername)

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

*Built as a portfolio project to demonstrate real-world Junior DBA skills.*
