-- ====================================================================
-- Trekverse AI Academy - Database Architecture Schema
-- AI-Powered Student Academic Management & Early-Warning System
-- ====================================================================

-- 1. Users Table (Authentication & Role-Based Access Control)
CREATE TABLE IF NOT EXISTS users (
    user_id INTEGER PRIMARY KEY AUTOINCREMENT,
    username VARCHAR(80) UNIQUE NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK(role IN ('admin', 'faculty', 'student')),
    full_name VARCHAR(120) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active INTEGER DEFAULT 1
);

-- 2. Departments Table
CREATE TABLE IF NOT EXISTS departments (
    dept_id INTEGER PRIMARY KEY AUTOINCREMENT,
    dept_code VARCHAR(10) UNIQUE NOT NULL,
    dept_name VARCHAR(100) NOT NULL,
    head_of_dept VARCHAR(100)
);

-- 3. Faculty Table
CREATE TABLE IF NOT EXISTS faculty (
    faculty_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER UNIQUE,
    employee_code VARCHAR(20) UNIQUE NOT NULL,
    dept_id INTEGER,
    designation VARCHAR(50),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
);

-- 4. Students Table
CREATE TABLE IF NOT EXISTS students (
    student_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER UNIQUE,
    roll_number VARCHAR(30) UNIQUE NOT NULL,
    dept_id INTEGER,
    admission_year INTEGER NOT NULL,
    current_semester INTEGER NOT NULL,
    cgpa REAL DEFAULT 0.0,
    academic_standing VARCHAR(30) DEFAULT 'Good Standing',
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
);

-- 5. Subjects Table
CREATE TABLE IF NOT EXISTS subjects (
    subject_id INTEGER PRIMARY KEY AUTOINCREMENT,
    subject_code VARCHAR(20) UNIQUE NOT NULL,
    subject_name VARCHAR(100) NOT NULL,
    dept_id INTEGER,
    credits INTEGER DEFAULT 3,
    semester INTEGER NOT NULL,
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
);

-- 6. Attendance Table
CREATE TABLE IF NOT EXISTS attendance (
    attendance_id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER NOT NULL,
    subject_id INTEGER NOT NULL,
    total_classes INTEGER NOT NULL DEFAULT 0,
    attended_classes INTEGER NOT NULL DEFAULT 0,
    attendance_pct REAL GENERATED ALWAYS AS (ROUND((attended_classes * 100.0) / NULLIF(total_classes, 0), 2)) STORED,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES students(student_id),
    FOREIGN KEY (subject_id) REFERENCES subjects(subject_id)
);

-- 7. Assignments Table
CREATE TABLE IF NOT EXISTS assignments (
    assignment_id INTEGER PRIMARY KEY AUTOINCREMENT,
    subject_id INTEGER NOT NULL,
    title VARCHAR(150) NOT NULL,
    max_score REAL DEFAULT 100.0,
    due_date DATE,
    FOREIGN KEY (subject_id) REFERENCES subjects(subject_id)
);

-- 8. Internal Marks Table
CREATE TABLE IF NOT EXISTS internal_marks (
    internal_id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER NOT NULL,
    subject_id INTEGER NOT NULL,
    exam_type VARCHAR(20) NOT NULL, -- e.g. 'Mid-1', 'Mid-2', 'Quiz', 'Assignment'
    score REAL NOT NULL,
    max_score REAL DEFAULT 20.0,
    score_pct REAL GENERATED ALWAYS AS (ROUND((score * 100.0) / NULLIF(max_score, 0), 2)) STORED,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES students(student_id),
    FOREIGN KEY (subject_id) REFERENCES subjects(subject_id)
);

-- 9. Semester Results Table
CREATE TABLE IF NOT EXISTS semester_results (
    result_id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER NOT NULL,
    semester INTEGER NOT NULL,
    sgpa REAL NOT NULL,
    cgpa_cumulative REAL NOT NULL,
    total_credits_earned INTEGER NOT NULL,
    backlogs_count INTEGER DEFAULT 0,
    FOREIGN KEY (student_id) REFERENCES students(student_id)
);

-- 10. Model Versions Table
CREATE TABLE IF NOT EXISTS model_versions (
    version_id INTEGER PRIMARY KEY AUTOINCREMENT,
    model_name VARCHAR(80) NOT NULL,
    model_type VARCHAR(30) NOT NULL, -- 'regressor', 'classifier', 'clusterer', 'deep_learning'
    algorithm VARCHAR(50) NOT NULL,
    metric_name VARCHAR(30),
    metric_val REAL,
    artifact_path VARCHAR(255) NOT NULL,
    trained_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active INTEGER DEFAULT 0
);

-- 11. Predictions Table
CREATE TABLE IF NOT EXISTS predictions (
    prediction_id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER NOT NULL,
    subject_id INTEGER,
    model_version_id INTEGER,
    predicted_score_pct REAL NOT NULL,
    predicted_grade_20 REAL NOT NULL,
    prediction_range_low REAL,
    prediction_range_high REAL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES students(student_id),
    FOREIGN KEY (subject_id) REFERENCES subjects(subject_id),
    FOREIGN KEY (model_version_id) REFERENCES model_versions(version_id)
);

-- 12. Risk Assessments Table (AI Early-Warning System)
CREATE TABLE IF NOT EXISTS risk_assessments (
    assessment_id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER NOT NULL,
    risk_level VARCHAR(20) NOT NULL CHECK(risk_level IN ('Low Risk', 'Moderate Risk', 'High Risk')),
    risk_probability REAL NOT NULL,
    top_contributing_factors TEXT, -- JSON array of factors
    status VARCHAR(30) DEFAULT 'Active',
    assessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES students(student_id)
);

-- 13. Recommendations Table (AI Learning Pathway Engine)
CREATE TABLE IF NOT EXISTS recommendations (
    recommendation_id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER NOT NULL,
    severity VARCHAR(20) NOT NULL CHECK(severity IN ('Critical', 'High', 'Medium', 'Low', 'Info')),
    title VARCHAR(150) NOT NULL,
    finding TEXT NOT NULL,
    action_detail TEXT NOT NULL,
    resource_link VARCHAR(255),
    is_acknowledged INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES students(student_id)
);

-- 14. Study Plans Table (Personalized Study Planner)
CREATE TABLE IF NOT EXISTS study_plans (
    plan_id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER NOT NULL,
    target_subject_id INTEGER,
    weekly_hours_allocated REAL DEFAULT 14.0,
    plan_schedule_json TEXT NOT NULL,
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES students(student_id),
    FOREIGN KEY (target_subject_id) REFERENCES subjects(subject_id)
);

-- 15. Faculty Interventions Table
CREATE TABLE IF NOT EXISTS interventions (
    intervention_id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER NOT NULL,
    faculty_id INTEGER NOT NULL,
    intervention_type VARCHAR(50) NOT NULL, -- 'Mentoring', 'Remedial Session', 'Attendance Warning', 'Counseling'
    notes TEXT,
    follow_up_date DATE,
    outcome_status VARCHAR(30) DEFAULT 'Pending Review',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES students(student_id),
    FOREIGN KEY (faculty_id) REFERENCES faculty(faculty_id)
);

-- 16. Audit Logs Table (Model & Data Governance)
CREATE TABLE IF NOT EXISTS audit_logs (
    log_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    action VARCHAR(100) NOT NULL,
    entity_name VARCHAR(50) NOT NULL,
    entity_id INTEGER,
    details TEXT,
    ip_address VARCHAR(45),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- Create Indexes for performance
CREATE INDEX IF NOT EXISTS idx_students_roll ON students(roll_number);
CREATE INDEX IF NOT EXISTS idx_predictions_student ON predictions(student_id);
CREATE INDEX IF NOT EXISTS idx_risk_student ON risk_assessments(student_id);
CREATE INDEX IF NOT EXISTS idx_attendance_student ON attendance(student_id);
CREATE INDEX IF NOT EXISTS idx_interventions_student ON interventions(student_id);
