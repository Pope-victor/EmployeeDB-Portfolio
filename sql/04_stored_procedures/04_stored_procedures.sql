-- ============================================================
-- FILE: 04_stored_procedures.sql
-- PROJECT: Employee Database Management System
-- DESCRIPTION: Stored procedures for business logic and DBA tasks
-- ============================================================

USE EmployeeDB;
GO

-- ============================================================
-- SP 1: Add New Employee
-- ============================================================
CREATE OR ALTER PROCEDURE sp_AddEmployee
    @FirstName       VARCHAR(50),
    @LastName        VARCHAR(50),
    @Email           VARCHAR(150),
    @Phone           VARCHAR(20)     = NULL,
    @DateOfBirth     DATE,
    @Gender          CHAR(1),
    @NationalID      VARCHAR(20),
    @HireDate        DATE,
    @DepartmentID    INT,
    @JobTitleID      INT,
    @ManagerID       INT             = NULL,
    @BasicSalary     DECIMAL(12,2),
    @HousingAllowance DECIMAL(12,2)  = 0,
    @TransportAllowance DECIMAL(12,2)= 0,
    @MedicalAllowance DECIMAL(12,2)  = 0,
    @NewEmployeeID   INT             OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validation: Email must be unique
        IF EXISTS (SELECT 1 FROM Employees WHERE Email = @Email)
            THROW 50001, 'Email address already exists in the system.', 1;

        -- Validation: NationalID must be unique
        IF EXISTS (SELECT 1 FROM Employees WHERE NationalID = @NationalID)
            THROW 50002, 'National ID already exists in the system.', 1;

        -- Validation: Department exists
        IF NOT EXISTS (SELECT 1 FROM Departments WHERE DepartmentID = @DepartmentID AND IsActive = 1)
            THROW 50003, 'Department does not exist or is inactive.', 1;

        -- Insert employee
        INSERT INTO Employees (FirstName, LastName, Email, Phone, DateOfBirth, Gender, NationalID,
                               HireDate, DepartmentID, JobTitleID, ManagerID)
        VALUES (@FirstName, @LastName, @Email, @Phone, @DateOfBirth, @Gender, @NationalID,
                @HireDate, @DepartmentID, @JobTitleID, @ManagerID);

        SET @NewEmployeeID = SCOPE_IDENTITY();

        -- Insert initial salary
        INSERT INTO Salaries (EmployeeID, BasicSalary, HousingAllowance, TransportAllowance, MedicalAllowance, EffectiveDate)
        VALUES (@NewEmployeeID, @BasicSalary, @HousingAllowance, @TransportAllowance, @MedicalAllowance, @HireDate);

        -- Audit log
        INSERT INTO AuditLog (TableName, RecordID, Action, NewValues)
        VALUES ('Employees', @NewEmployeeID, 'INSERT',
                CONCAT('{"Name":"', @FirstName, ' ', @LastName, '","Email":"', @Email, '"}'));

        COMMIT TRANSACTION;
        PRINT 'Employee added successfully. EmployeeID: ' + CAST(@NewEmployeeID AS VARCHAR);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev INT            = ERROR_SEVERITY();
        RAISERROR(@ErrMsg, @ErrSev, 1);
    END CATCH;
END;
GO

-- ============================================================
-- SP 2: Update Employee Salary
-- ============================================================
CREATE OR ALTER PROCEDURE sp_UpdateSalary
    @EmployeeID          INT,
    @NewBasicSalary      DECIMAL(12,2),
    @NewHousing          DECIMAL(12,2) = NULL,
    @NewTransport        DECIMAL(12,2) = NULL,
    @NewMedical          DECIMAL(12,2) = NULL,
    @EffectiveDate       DATE          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validation
        IF NOT EXISTS (SELECT 1 FROM Employees WHERE EmployeeID = @EmployeeID AND EmploymentStatus = 'Active')
            THROW 50010, 'Employee not found or is not active.', 1;

        IF @NewBasicSalary <= 0
            THROW 50011, 'Basic salary must be greater than zero.', 1;

        SET @EffectiveDate = ISNULL(@EffectiveDate, CAST(GETDATE() AS DATE));

        -- Close existing salary record
        UPDATE Salaries
        SET EndDate = DATEADD(DAY, -1, @EffectiveDate)
        WHERE EmployeeID = @EmployeeID AND EndDate IS NULL;

        -- Get previous allowances if new ones not supplied
        DECLARE @OldHousing   DECIMAL(12,2),
                @OldTransport DECIMAL(12,2),
                @OldMedical   DECIMAL(12,2);

        SELECT TOP 1
            @OldHousing   = HousingAllowance,
            @OldTransport = TransportAllowance,
            @OldMedical   = MedicalAllowance
        FROM Salaries
        WHERE EmployeeID = @EmployeeID
        ORDER BY EffectiveDate DESC;

        -- Insert new salary record
        INSERT INTO Salaries (EmployeeID, BasicSalary, HousingAllowance, TransportAllowance, MedicalAllowance, EffectiveDate)
        VALUES (
            @EmployeeID,
            @NewBasicSalary,
            ISNULL(@NewHousing,   @OldHousing),
            ISNULL(@NewTransport, @OldTransport),
            ISNULL(@NewMedical,   @OldMedical),
            @EffectiveDate
        );

        -- Audit log
        INSERT INTO AuditLog (TableName, RecordID, Action, NewValues)
        VALUES ('Salaries', @EmployeeID, 'UPDATE',
                CONCAT('{"NewBasic":', @NewBasicSalary, ',"EffectiveDate":"', @EffectiveDate, '"}'));

        COMMIT TRANSACTION;
        PRINT 'Salary updated successfully for EmployeeID: ' + CAST(@EmployeeID AS VARCHAR);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        RAISERROR(ERROR_MESSAGE(), ERROR_SEVERITY(), 1);
    END CATCH;
END;
GO

-- ============================================================
-- SP 3: Process Leave Request
-- ============================================================
CREATE OR ALTER PROCEDURE sp_ProcessLeaveRequest
    @LeaveID        INT,
    @Action         VARCHAR(10),     -- 'Approve' or 'Reject'
    @ApproverID     INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Action NOT IN ('Approve', 'Reject')
            THROW 50020, 'Action must be Approve or Reject.', 1;

        IF NOT EXISTS (SELECT 1 FROM LeaveRequests WHERE LeaveID = @LeaveID AND Status = 'Pending')
            THROW 50021, 'Leave request not found or already processed.', 1;

        DECLARE @Status VARCHAR(20) = CASE WHEN @Action = 'Approve' THEN 'Approved' ELSE 'Rejected' END;

        UPDATE LeaveRequests
        SET Status     = @Status,
            ApprovedBy = @ApproverID,
            ApprovedAt = GETDATE()
        WHERE LeaveID  = @LeaveID;

        -- If approved, update attendance records for those days
        IF @Action = 'Approve'
        BEGIN
            DECLARE @EmpID    INT, @Start DATE, @End DATE;
            SELECT @EmpID = EmployeeID, @Start = StartDate, @End = EndDate
            FROM LeaveRequests WHERE LeaveID = @LeaveID;

            INSERT INTO Attendance (EmployeeID, AttendanceDate, Status)
            SELECT @EmpID, DateValue, 'Leave'
            FROM (
                SELECT DATEADD(DAY, n.Number, @Start) AS DateValue
                FROM (SELECT TOP (DATEDIFF(DAY, @Start, @End)+1)
                             ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS Number
                      FROM sys.all_objects) n
            ) Dates
            WHERE DATENAME(WEEKDAY, DateValue) NOT IN ('Saturday','Sunday')
            AND NOT EXISTS (
                SELECT 1 FROM Attendance a
                WHERE a.EmployeeID = @EmpID AND a.AttendanceDate = DateValue
            );
        END;

        COMMIT TRANSACTION;
        PRINT 'Leave request ' + @Status + ' successfully.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        RAISERROR(ERROR_MESSAGE(), ERROR_SEVERITY(), 1);
    END CATCH;
END;
GO

-- ============================================================
-- SP 4: Terminate Employee
-- ============================================================
CREATE OR ALTER PROCEDURE sp_TerminateEmployee
    @EmployeeID        INT,
    @TerminationDate   DATE,
    @Reason            VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM Employees WHERE EmployeeID = @EmployeeID AND EmploymentStatus = 'Active')
            THROW 50030, 'Employee not found or already terminated.', 1;

        -- Update employee status
        UPDATE Employees
        SET EmploymentStatus = 'Terminated',
            TerminationDate  = @TerminationDate,
            UpdatedAt        = GETDATE()
        WHERE EmployeeID = @EmployeeID;

        -- Close salary record
        UPDATE Salaries
        SET EndDate = @TerminationDate
        WHERE EmployeeID = @EmployeeID AND EndDate IS NULL;

        -- Deactivate system user
        UPDATE SystemUsers SET IsActive = 0 WHERE EmployeeID = @EmployeeID;

        -- Audit log
        INSERT INTO AuditLog (TableName, RecordID, Action, NewValues)
        VALUES ('Employees', @EmployeeID, 'UPDATE',
                CONCAT('{"Action":"Termination","Date":"', @TerminationDate, '","Reason":"', ISNULL(@Reason,'N/A'), '"}'));

        COMMIT TRANSACTION;
        PRINT 'Employee ' + CAST(@EmployeeID AS VARCHAR) + ' terminated successfully.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        RAISERROR(ERROR_MESSAGE(), ERROR_SEVERITY(), 1);
    END CATCH;
END;
GO

-- ============================================================
-- SP 5: Get Employee Full Profile (for HR / portal)
-- ============================================================
CREATE OR ALTER PROCEDURE sp_GetEmployeeProfile
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Employee info
    SELECT
        e.EmployeeID,
        e.FirstName + ' ' + e.LastName  AS FullName,
        e.Email, e.Phone,
        e.Gender, e.DateOfBirth,
        DATEDIFF(YEAR, e.DateOfBirth, GETDATE()) AS Age,
        e.HireDate,
        DATEDIFF(YEAR, e.HireDate, GETDATE())    AS YearsOfService,
        e.EmploymentStatus,
        d.DepartmentName,
        j.JobTitle, j.JobGrade,
        m.FirstName + ' ' + m.LastName           AS ManagerName
    FROM Employees e
    JOIN Departments d ON e.DepartmentID = d.DepartmentID
    JOIN JobTitles   j ON e.JobTitleID   = j.JobTitleID
    LEFT JOIN Employees m ON e.ManagerID = m.EmployeeID
    WHERE e.EmployeeID = @EmployeeID;

    -- Current salary
    SELECT BasicSalary, HousingAllowance, TransportAllowance, MedicalAllowance, GrossSalary, EffectiveDate
    FROM Salaries WHERE EmployeeID = @EmployeeID AND EndDate IS NULL;

    -- Leave history (last 5)
    SELECT TOP 5 LeaveType, StartDate, EndDate, TotalDays, Status
    FROM LeaveRequests WHERE EmployeeID = @EmployeeID
    ORDER BY StartDate DESC;

    -- Attendance (last 10 days)
    SELECT TOP 10 AttendanceDate, CheckInTime, CheckOutTime, Status, WorkHours
    FROM Attendance WHERE EmployeeID = @EmployeeID
    ORDER BY AttendanceDate DESC;
END;
GO

PRINT 'All stored procedures created successfully.';
GO
