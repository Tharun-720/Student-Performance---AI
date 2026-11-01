"""Database management service: SQLite backend for Trekverse AI Academy.

Provides persistent storage, schema initialization, student records query,
and logging of predictions and faculty interventions.
"""
import json
import sqlite3
from pathlib import Path
from typing import Any, Dict, List, Optional

DB_PATH = Path(__file__).resolve().parent / "student_intelligence.db"
SCHEMA_PATH = Path(__file__).resolve().parent / "schema.sql"


def get_db_connection(db_file: Path = DB_PATH) -> sqlite3.Connection:
    """Create and configure a SQLite connection."""
    conn = sqlite3.connect(str(db_file))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON;")
    return conn


def init_database(db_file: Path = DB_PATH, schema_file: Path = SCHEMA_PATH) -> None:
    """Initialize database tables and seed initial demo data if empty."""
    conn = get_db_connection(db_file)
    with open(schema_file, "r", encoding="utf-8") as f:
        schema_sql = f.read()

    # SQLite does not support multiple statements in execute(), use executescript()
    conn.executescript(schema_sql)

    # Seed baseline departments and faculty if empty
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM departments")
    if cur.fetchone()[0] == 0:
        cur.execute("INSERT INTO departments (dept_code, dept_name, head_of_dept) VALUES (?, ?, ?)",
                    ("CSE", "Computer Science & Engineering", "Dr. K. Sharma"))
        cur.execute("INSERT INTO departments (dept_code, dept_name, head_of_dept) VALUES (?, ?, ?)",
                    ("AI-DS", "Artificial Intelligence & Data Science", "Dr. P. Varma"))

        cur.execute("INSERT INTO users (username, email, password_hash, role, full_name) VALUES (?, ?, ?, ?, ?)",
                    ("admin", "admin@trekverse.edu", "pbkdf2:sha256:admin", "admin", "System Administrator"))
        cur.execute("INSERT INTO users (username, email, password_hash, role, full_name) VALUES (?, ?, ?, ?, ?)",
                    ("faculty1", "faculty@trekverse.edu", "pbkdf2:sha256:fac", "faculty", "Prof. R. Venkat"))
        cur.execute("INSERT INTO users (username, email, password_hash, role, full_name) VALUES (?, ?, ?, ?, ?)",
                    ("STU1024", "stu1024@trekverse.edu", "pbkdf2:sha256:stu", "student", "Tharun Reddy"))

        cur.execute("INSERT INTO faculty (user_id, employee_code, dept_id, designation) VALUES (?, ?, ?, ?)",
                    (2, "FAC-CSE-01", 1, "Associate Professor"))

        cur.execute("INSERT INTO students (user_id, roll_number, dept_id, admission_year, current_semester, cgpa, academic_standing) VALUES (?, ?, ?, ?, ?, ?, ?)",
                    (3, "STU1024", 2, 2023, 6, 7.84, "Good Standing"))

        # Seed subjects
        subjects = [
            ("CS301", "Database Management Systems (DBMS)", 1, 4, 5),
            ("CS302", "Computer Networks", 1, 4, 5),
            ("CS303", "Machine Learning & AI", 2, 4, 6),
            ("CS304", "Mathematics III", 2, 4, 3),
            ("CS305", "Object-Oriented Programming", 1, 4, 4),
        ]
        for code, name, dept, cred, sem in subjects:
            cur.execute("INSERT INTO subjects (subject_code, subject_name, dept_id, credits, semester) VALUES (?, ?, ?, ?, ?)",
                        (code, name, dept, cred, sem))

        conn.commit()
    conn.close()


def log_prediction(student_roll: str, prediction_result: Dict[str, Any], db_file: Path = DB_PATH) -> int:
    """Log an AI prediction and risk assessment to the database."""
    conn = get_db_connection(db_file)
    cur = conn.cursor()

    # Find or create student
    cur.execute("SELECT student_id FROM students WHERE roll_number = ?", (student_roll,))
    row = cur.fetchone()
    if row:
        student_id = row[0]
    else:
        cur.execute("INSERT INTO students (roll_number, dept_id, admission_year, current_semester, cgpa) VALUES (?, ?, ?, ?, ?)",
                    (student_roll, 1, 2023, 6, prediction_result.get("predicted_grade_20", 12.0) * 0.5))
        student_id = cur.lastrowid

    # Insert prediction
    pr = prediction_result.get("prediction_range", {})
    cur.execute(
        """INSERT INTO predictions (student_id, predicted_score_pct, predicted_grade_20, prediction_range_low, prediction_range_high)
           VALUES (?, ?, ?, ?, ?)""",
        (student_id, prediction_result["predicted_score_pct"], prediction_result["predicted_grade_20"],
         pr.get("low", 0.0), pr.get("high", 100.0))
    )
    pred_id = cur.lastrowid

    # Insert risk assessment
    tier = prediction_result.get("support_level", "Medium Support")
    risk_level = "High Risk" if tier == "High Support" else ("Moderate Risk" if tier == "Medium Support" else "Low Risk")
    probs = prediction_result.get("support_probabilities", {})
    prob = probs.get(tier, 0.70)
    factors = [f"{d['feature']}: {d['shap']:+.2f}" for d in prediction_result.get("explanation", {}).get("decreasing", [])]

    cur.execute(
        """INSERT INTO risk_assessments (student_id, risk_level, risk_probability, top_contributing_factors)
           VALUES (?, ?, ?, ?)""",
        (student_id, risk_level, prob, json.dumps(factors))
    )

    conn.commit()
    conn.close()
    return pred_id


def log_faculty_intervention(student_roll: str, faculty_code: str, intervention_type: str, notes: str, db_file: Path = DB_PATH) -> int:
    """Log a faculty intervention."""
    conn = get_db_connection(db_file)
    cur = conn.cursor()

    cur.execute("SELECT student_id FROM students WHERE roll_number = ?", (student_roll,))
    s_row = cur.fetchone()
    student_id = s_row[0] if s_row else 1

    cur.execute("SELECT faculty_id FROM faculty WHERE employee_code = ?", (faculty_code,))
    f_row = cur.fetchone()
    faculty_id = f_row[0] if f_row else 1

    cur.execute(
        """INSERT INTO interventions (student_id, faculty_id, intervention_type, notes, outcome_status)
           VALUES (?, ?, ?, ?, ?)""",
        (student_id, faculty_id, intervention_type, notes, "Active Follow-up")
    )
    conn.commit()
    intervention_id = cur.lastrowid
    conn.close()
    return intervention_id


def get_all_interventions(db_file: Path = DB_PATH) -> List[Dict[str, Any]]:
    """Retrieve all recorded interventions."""
    conn = get_db_connection(db_file)
    cur = conn.cursor()
    cur.execute("""
        SELECT i.intervention_id, s.roll_number, i.intervention_type, i.notes, i.outcome_status, i.created_at
        FROM interventions i
        JOIN students s ON i.student_id = s.student_id
        ORDER BY i.created_at DESC
    """)
    rows = [dict(r) for r in cur.fetchall()]
    conn.close()
    return rows
