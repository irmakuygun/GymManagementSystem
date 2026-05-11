-- =====================================================
-- Gym Management System - Schema (MySQL 8.x)
-- =====================================================
DROP DATABASE IF EXISTS gym_management;
CREATE DATABASE gym_management CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE gym_management;

-- ---------- membership_plans ----------
CREATE TABLE membership_plans (
    plan_id           INT AUTO_INCREMENT PRIMARY KEY,
    plan_name         VARCHAR(50)    NOT NULL UNIQUE,
    duration_months   INT            NOT NULL CHECK (duration_months > 0),
    price             DECIMAL(10,2)  NOT NULL CHECK (price >= 0),
    access_level      VARCHAR(20)    NOT NULL
);

-- ---------- trainers ----------
CREATE TABLE trainers (
    trainer_id          INT AUTO_INCREMENT PRIMARY KEY,
    name                VARCHAR(50) NOT NULL,
    surname             VARCHAR(50) NOT NULL,
    specialty           VARCHAR(50),
    certification_level VARCHAR(50),
    employment_status   ENUM('active','inactive','on_leave') NOT NULL DEFAULT 'active',
    hire_date           DATE NOT NULL,
    salary              DECIMAL(10,2) CHECK (salary >= 0)
);

-- ---------- classes ----------
CREATE TABLE classes (
    class_id   INT AUTO_INCREMENT PRIMARY KEY,
    class_name VARCHAR(50) NOT NULL UNIQUE,
    capacity   INT NOT NULL CHECK (capacity > 0)
);

-- ---------- class_schedule ----------
CREATE TABLE class_schedule (
    schedule_id  INT AUTO_INCREMENT PRIMARY KEY,
    class_id     INT NOT NULL,
    trainer_id   INT NOT NULL,
    day_of_week  ENUM('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday') NOT NULL,
    start_time   TIME NOT NULL,
    duration_min INT  NOT NULL CHECK (duration_min > 0),
    room         VARCHAR(20),
    FOREIGN KEY (class_id)   REFERENCES classes(class_id)   ON DELETE CASCADE,
    FOREIGN KEY (trainer_id) REFERENCES trainers(trainer_id) ON DELETE RESTRICT,
    UNIQUE KEY uq_room_slot (room, day_of_week, start_time)
);

-- ---------- equipment ----------
CREATE TABLE equipment (
    equipment_id INT AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(50) NOT NULL,
    status       ENUM('available','maintenance','retired') NOT NULL DEFAULT 'available'
);

-- ---------- equipment_maintenance ----------
CREATE TABLE equipment_maintenance (
    maintenance_id   INT AUTO_INCREMENT PRIMARY KEY,
    equipment_id     INT NOT NULL,
    maintenance_date DATE NOT NULL,
    description      TEXT,
    technician_name  VARCHAR(100),
    FOREIGN KEY (equipment_id) REFERENCES equipment(equipment_id) ON DELETE CASCADE
);

-- ---------- class_equipment (M:N join) ----------
CREATE TABLE class_equipment (
    class_id     INT NOT NULL,
    equipment_id INT NOT NULL,
    PRIMARY KEY (class_id, equipment_id),
    FOREIGN KEY (class_id)     REFERENCES classes(class_id)     ON DELETE CASCADE,
    FOREIGN KEY (equipment_id) REFERENCES equipment(equipment_id) ON DELETE CASCADE
);

-- ---------- members ----------
CREATE TABLE members (
    member_id             INT AUTO_INCREMENT PRIMARY KEY,
    name                  VARCHAR(50) NOT NULL,
    surname               VARCHAR(50) NOT NULL,
    phone                 VARCHAR(20),
    join_date             DATE NOT NULL,
    plan_id               INT,
    membership_start_date DATE,
    membership_end_date   DATE,
    FOREIGN KEY (plan_id) REFERENCES membership_plans(plan_id) ON DELETE SET NULL
);

-- ---------- health_metrics ----------
CREATE TABLE health_metrics (
    metric_id     INT AUTO_INCREMENT PRIMARY KEY,
    member_id     INT NOT NULL,
    weight        DECIMAL(5,2) CHECK (weight  >= 0),
    body_fat      DECIMAL(4,2) CHECK (body_fat >= 0 AND body_fat <= 100),
    muscle_mass   DECIMAL(5,2) CHECK (muscle_mass >= 0),
    recorded_date DATE NOT NULL,
    FOREIGN KEY (member_id) REFERENCES members(member_id) ON DELETE CASCADE
);

-- ---------- payments ----------
CREATE TABLE payments (
    payment_id        INT AUTO_INCREMENT PRIMARY KEY,
    member_id         INT NOT NULL,
    plan_id           INT NOT NULL,
    amount            DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
    payment_date      DATE NOT NULL,
    payment_method    ENUM('cash','credit_card','debit_card','bank_transfer') NOT NULL,
    next_billing_date DATE,
    payment_status    ENUM('pending','completed','failed','refunded') NOT NULL DEFAULT 'pending',
    FOREIGN KEY (member_id) REFERENCES members(member_id)         ON DELETE CASCADE,
    FOREIGN KEY (plan_id)   REFERENCES membership_plans(plan_id)  ON DELETE RESTRICT
);

-- ---------- bookings ----------
CREATE TABLE bookings (
    booking_id   INT AUTO_INCREMENT PRIMARY KEY,
    member_id    INT NOT NULL,
    schedule_id  INT NOT NULL,
    booking_date DATE NOT NULL,
    status       ENUM('confirmed','cancelled','attended','no_show') NOT NULL DEFAULT 'confirmed',
    FOREIGN KEY (member_id)   REFERENCES members(member_id)        ON DELETE CASCADE,
    FOREIGN KEY (schedule_id) REFERENCES class_schedule(schedule_id) ON DELETE CASCADE,
    UNIQUE KEY uq_member_schedule_date (member_id, schedule_id, booking_date)
);

-- ---------- attendance ----------
CREATE TABLE attendance (
    log_id         INT AUTO_INCREMENT PRIMARY KEY,
    member_id      INT NOT NULL,
    booking_id     INT,
    check_in_time  DATETIME NOT NULL,
    check_out_time DATETIME,
    FOREIGN KEY (member_id)  REFERENCES members(member_id)   ON DELETE CASCADE,
    FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) ON DELETE SET NULL,
    CHECK (check_out_time IS NULL OR check_out_time >= check_in_time)
);

-- Indexes that help frequent reads
CREATE INDEX idx_members_plan          ON members(plan_id);
CREATE INDEX idx_payments_member       ON payments(member_id);
CREATE INDEX idx_bookings_schedule     ON bookings(schedule_id);
CREATE INDEX idx_attendance_member     ON attendance(member_id);
CREATE INDEX idx_health_metrics_member ON health_metrics(member_id);
