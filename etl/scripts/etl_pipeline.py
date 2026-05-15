"""
============================================================
FILE: etl_pipeline.py
PROJECT: Employee Database Management System
DESCRIPTION: Python ETL pipeline — Extract from CSV,
             Transform/validate data, Load into SQL Server.
             Demonstrates beginner Data Engineering skills.
DEPENDENCIES: pip install pandas pyodbc sqlalchemy loguru
============================================================
"""

import os
import re
import pyodbc
import pandas as pd
from datetime import datetime
from loguru import logger

# ============================================================
# CONFIGURATION
# ============================================================
DB_CONFIG = {
    "server":   "localhost",          # Change to your SQL Server name
    "database": "EmployeeDB",
    "username": "login_etl_service",
    "password": "ETL@Str0ngP@ss!2024",
    "driver":   "ODBC Driver 17 for SQL Server",
}

CSV_PATH   = os.path.join(os.path.dirname(__file__), "data", "new_employees.csv")
LOG_PATH   = os.path.join(os.path.dirname(__file__), "logs")
os.makedirs(LOG_PATH, exist_ok=True)

# Configure logging
logger.add(
    os.path.join(LOG_PATH, "etl_{time:YYYY-MM-DD}.log"),
    rotation="1 day",
    retention="30 days",
    level="INFO"
)


# ============================================================
# STEP 1: EXTRACT — Read CSV file
# ============================================================
def extract(filepath: str) -> pd.DataFrame:
    """Read CSV file and return a raw DataFrame."""
    logger.info(f"[EXTRACT] Reading CSV: {filepath}")
    try:
        df = pd.read_csv(filepath, dtype=str)   # Read all as string first
        df.columns = df.columns.str.strip()       # Remove whitespace from headers
        logger.info(f"[EXTRACT] Loaded {len(df)} rows, {len(df.columns)} columns.")
        return df
    except FileNotFoundError:
        logger.error(f"[EXTRACT] CSV file not found: {filepath}")
        raise


# ============================================================
# STEP 2: TRANSFORM — Validate and clean data
# ============================================================
def transform(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    """
    Validate, clean, and enrich the raw DataFrame.
    Returns (valid_df, rejected_df).
    """
    logger.info(f"[TRANSFORM] Starting transformation on {len(df)} rows...")
    rejected_rows = []

    def reject(row_idx, row, reason):
        row["_RejectionReason"] = reason
        row["_OriginalIndex"]   = row_idx
        rejected_rows.append(row)

    valid_rows = []

    for idx, row in df.iterrows():
        row = row.copy()
        errors = []

        # ---- 2A: Strip whitespace from all fields ----
        for col in row.index:
            if isinstance(row[col], str):
                row[col] = row[col].strip()

        # ---- 2B: Email validation ----
        email_pattern = r"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$"
        if not re.match(email_pattern, str(row.get("Email", ""))):
            errors.append("Invalid email format")

        # ---- 2C: Phone normalisation ----
        phone = re.sub(r"\D", "", str(row.get("Phone", "")))
        if len(phone) == 11 and phone.startswith("0"):
            row["Phone"] = phone          # Keep as-is
        elif len(phone) == 10:
            row["Phone"] = "0" + phone    # Add leading zero
        else:
            errors.append(f"Invalid phone number: {row.get('Phone')}")

        # ---- 2D: Date validation ----
        for date_col in ["DateOfBirth", "HireDate"]:
            try:
                parsed = datetime.strptime(str(row[date_col]), "%Y-%m-%d").date()
                row[date_col] = parsed
            except (ValueError, KeyError):
                errors.append(f"Invalid date in {date_col}: {row.get(date_col)}")

        # ---- 2E: Gender normalisation ----
        gender = str(row.get("Gender", "")).upper().strip()
        if gender in ("M", "MALE"):
            row["Gender"] = "M"
        elif gender in ("F", "FEMALE"):
            row["Gender"] = "F"
        else:
            errors.append(f"Invalid gender value: {row.get('Gender')}")

        # ---- 2F: Salary fields — numeric conversion ----
        salary_cols = ["BasicSalary", "HousingAllowance", "TransportAllowance", "MedicalAllowance"]
        for col in salary_cols:
            try:
                val = float(str(row.get(col, 0)).replace(",", ""))
                if val < 0:
                    errors.append(f"{col} cannot be negative")
                row[col] = round(val, 2)
            except ValueError:
                errors.append(f"Non-numeric value in {col}: {row.get(col)}")

        # ---- 2G: Required fields check ----
        required = ["FirstName", "LastName", "Email", "NationalID", "HireDate", "DepartmentName"]
        for field in required:
            if not row.get(field) or str(row[field]).strip() == "":
                errors.append(f"Missing required field: {field}")

        # ---- 2H: Name capitalisation ----
        row["FirstName"] = str(row.get("FirstName", "")).title()
        row["LastName"]  = str(row.get("LastName", "")).title()
        row["City"]      = str(row.get("City", "")).title()

        # ---- 2I: Derived fields ----
        row["GrossSalary"] = (
            row.get("BasicSalary", 0) +
            row.get("HousingAllowance", 0) +
            row.get("TransportAllowance", 0) +
            row.get("MedicalAllowance", 0)
        )
        row["LoadedAt"]         = datetime.now()
        row["EmploymentStatus"] = "Active"

        # ---- Route row ----
        if errors:
            reject(idx, row, " | ".join(errors))
        else:
            valid_rows.append(row)

    valid_df    = pd.DataFrame(valid_rows)   if valid_rows    else pd.DataFrame()
    rejected_df = pd.DataFrame(rejected_rows) if rejected_rows else pd.DataFrame()

    logger.info(f"[TRANSFORM] Valid rows: {len(valid_df)} | Rejected rows: {len(rejected_df)}")

    if not rejected_df.empty:
        reject_path = os.path.join(LOG_PATH, f"rejected_{datetime.now():%Y%m%d_%H%M%S}.csv")
        rejected_df.to_csv(reject_path, index=False)
        logger.warning(f"[TRANSFORM] Rejected rows saved to: {reject_path}")

    return valid_df, rejected_df


# ============================================================
# STEP 3: LOAD — Insert into SQL Server
# ============================================================
def load(df: pd.DataFrame, conn_str: str) -> dict:
    """Load validated rows into SQL Server. Returns summary stats."""
    if df.empty:
        logger.warning("[LOAD] No valid rows to load.")
        return {"inserted": 0, "skipped": 0, "errors": 0}

    logger.info(f"[LOAD] Connecting to SQL Server...")

    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
    except pyodbc.Error as e:
        logger.error(f"[LOAD] Database connection failed: {e}")
        raise

    inserted = 0
    skipped  = 0
    errors   = 0

    for _, row in df.iterrows():
        try:
            # ---- Lookup DepartmentID ----
            cursor.execute(
                "SELECT DepartmentID FROM Departments WHERE DepartmentName = ?",
                row["DepartmentName"]
            )
            dept_result = cursor.fetchone()
            if not dept_result:
                logger.warning(f"[LOAD] Department not found: {row['DepartmentName']} — skipping {row['Email']}")
                skipped += 1
                continue
            dept_id = dept_result[0]

            # ---- Lookup JobTitleID ----
            cursor.execute(
                "SELECT JobTitleID FROM JobTitles WHERE JobTitle = ?",
                row["JobTitle"]
            )
            job_result = cursor.fetchone()
            if not job_result:
                logger.warning(f"[LOAD] Job title not found: {row['JobTitle']} — skipping {row['Email']}")
                skipped += 1
                continue
            job_id = job_result[0]

            # ---- Skip duplicates (idempotent load) ----
            cursor.execute(
                "SELECT 1 FROM Employees WHERE Email = ? OR NationalID = ?",
                row["Email"], row["NationalID"]
            )
            if cursor.fetchone():
                logger.info(f"[LOAD] Duplicate skipped: {row['Email']}")
                skipped += 1
                continue

            # ---- Insert Employee ----
            cursor.execute("""
                INSERT INTO Employees
                    (FirstName, LastName, Email, Phone, DateOfBirth, Gender, NationalID,
                     HireDate, EmploymentStatus, DepartmentID, JobTitleID, City, Country)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
                row["FirstName"], row["LastName"], row["Email"], row["Phone"],
                row["DateOfBirth"], row["Gender"], row["NationalID"],
                row["HireDate"], row["EmploymentStatus"],
                dept_id, job_id,
                row.get("City", "Lagos"), row.get("Country", "Nigeria")
            )

            # Get the new EmployeeID
            cursor.execute("SELECT SCOPE_IDENTITY()")
            new_emp_id = int(cursor.fetchone()[0])

            # ---- Insert Salary ----
            cursor.execute("""
                INSERT INTO Salaries
                    (EmployeeID, BasicSalary, HousingAllowance, TransportAllowance,
                     MedicalAllowance, EffectiveDate, Currency)
                VALUES (?, ?, ?, ?, ?, ?, 'NGN')
            """,
                new_emp_id,
                row["BasicSalary"], row["HousingAllowance"],
                row["TransportAllowance"], row["MedicalAllowance"],
                row["HireDate"]
            )

            inserted += 1
            logger.info(f"[LOAD] Inserted: {row['FirstName']} {row['LastName']} → EmployeeID {new_emp_id}")

        except pyodbc.Error as e:
            errors += 1
            logger.error(f"[LOAD] DB error for {row.get('Email')}: {e}")
            conn.rollback()
            continue

    conn.commit()
    cursor.close()
    conn.close()

    summary = {"inserted": inserted, "skipped": skipped, "errors": errors}
    logger.info(f"[LOAD] Complete — {summary}")
    return summary


# ============================================================
# MAIN PIPELINE ORCHESTRATOR
# ============================================================
def run_pipeline():
    logger.info("=" * 60)
    logger.info("  EmployeeDB ETL Pipeline Started")
    logger.info(f"  Run Time: {datetime.now():%Y-%m-%d %H:%M:%S}")
    logger.info("=" * 60)

    # Build connection string
    conn_str = (
        f"DRIVER={{{DB_CONFIG['driver']}}};"
        f"SERVER={DB_CONFIG['server']};"
        f"DATABASE={DB_CONFIG['database']};"
        f"UID={DB_CONFIG['username']};"
        f"PWD={DB_CONFIG['password']};"
        f"TrustServerCertificate=yes;"
    )

    # Run ETL steps
    raw_df          = extract(CSV_PATH)
    valid_df, _     = transform(raw_df)
    summary         = load(valid_df, conn_str)

    logger.info("=" * 60)
    logger.info("  ETL Pipeline Summary")
    logger.info(f"  Rows Extracted : {len(raw_df)}")
    logger.info(f"  Rows Valid     : {len(valid_df)}")
    logger.info(f"  Rows Inserted  : {summary['inserted']}")
    logger.info(f"  Rows Skipped   : {summary['skipped']}")
    logger.info(f"  Errors         : {summary['errors']}")
    logger.info("=" * 60)

    return summary


if __name__ == "__main__":
    run_pipeline()
