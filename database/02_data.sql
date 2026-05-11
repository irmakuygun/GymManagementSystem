-- =====================================================
-- Sample data (run AFTER 01_schema.sql)
-- Triggers in 04_triggers.sql will fill membership_end_date,
-- so DO NOT load this file before triggers if you want that
-- behavior.  Order recommended: 01 -> 03 -> 04 -> 05 -> 02.
-- =====================================================
USE gym_management;

-- Membership plans
INSERT INTO membership_plans (plan_name, duration_months, price, access_level) VALUES
 ('Basic Monthly',     1,   500.00, 'basic'),
 ('Standard Quarterly',3,  1350.00, 'standard'),
 ('Premium Yearly',    12, 4800.00, 'premium'),
 ('Student Monthly',   1,   300.00, 'basic');

-- Trainers
INSERT INTO trainers (name, surname, specialty, certification_level, employment_status, hire_date, salary) VALUES
 ('Ahmet',  'Yilmaz',   'Strength Training', 'CrossFit Level 2', 'active',   '2022-03-15', 18000.00),
 ('Elif',   'Demir',    'Yoga',              'RYT 500',          'active',   '2023-01-10', 15000.00),
 ('Mehmet', 'Kaya',     'Cardio & HIIT',     'NASM CPT',         'active',   '2021-06-20', 17500.00),
 ('Zeynep', 'Sahin',    'Pilates',           'BASI Pilates',     'active',   '2024-02-01', 14000.00),
 ('Can',    'Ozturk',   'Boxing',            'WBC Trainer',      'on_leave', '2020-11-05', 16000.00);

-- Classes
INSERT INTO classes (class_name, capacity) VALUES
 ('Power Yoga',     20),
 ('HIIT Cardio',    15),
 ('Strength 101',   12),
 ('Pilates Mat',    18),
 ('Boxing Basics',  10);

-- Class schedule
INSERT INTO class_schedule (class_id, trainer_id, day_of_week, start_time, duration_min, room) VALUES
 (1, 2, 'Monday',    '08:00:00', 60, 'Studio A'),
 (1, 2, 'Wednesday', '08:00:00', 60, 'Studio A'),
 (2, 3, 'Tuesday',   '18:00:00', 45, 'Main Hall'),
 (2, 3, 'Thursday',  '18:00:00', 45, 'Main Hall'),
 (3, 1, 'Monday',    '17:30:00', 75, 'Weight Room'),
 (3, 1, 'Friday',    '17:30:00', 75, 'Weight Room'),
 (4, 4, 'Wednesday', '10:00:00', 50, 'Studio B'),
 (5, 5, 'Saturday',  '11:00:00', 60, 'Boxing Ring');

-- Equipment
INSERT INTO equipment (name, status) VALUES
 ('Treadmill #1',     'available'),
 ('Treadmill #2',     'available'),
 ('Rowing Machine',   'available'),
 ('Squat Rack #1',    'available'),
 ('Squat Rack #2',    'maintenance'),
 ('Yoga Mats Set',    'available'),
 ('Boxing Bag',       'available'),
 ('Pilates Reformer', 'available'),
 ('Dumbbells Set',    'available');

-- Class <-> Equipment
INSERT INTO class_equipment (class_id, equipment_id) VALUES
 (1, 6),                          -- Yoga uses mats
 (2, 1), (2, 2), (2, 3),          -- HIIT uses treadmills + rower
 (3, 4), (3, 9),                  -- Strength uses rack + dumbbells
 (4, 8), (4, 6),                  -- Pilates uses reformer + mats
 (5, 7);                          -- Boxing uses bag

-- Equipment maintenance history
INSERT INTO equipment_maintenance (equipment_id, maintenance_date, description, technician_name) VALUES
 (1, '2025-09-10', 'Belt replacement',          'Murat Aydin'),
 (5, '2026-04-22', 'Bolt tightening + repaint', 'Murat Aydin'),
 (3, '2025-12-01', 'Chain lubrication',         'Sevgi Korkmaz');

-- Members. Start dates are CURDATE-relative so every seed member is currently
-- active regardless of when this file is loaded. The bookings trigger requires
-- active membership for inserts to succeed. The trg_members_bi trigger fills
-- membership_end_date from plan_end_date(plan_id, start).
INSERT INTO members (name, surname, phone, join_date, plan_id, membership_start_date) VALUES
 ('Ali',     'Vural',     '+905551110001', DATE_SUB(CURDATE(), INTERVAL 200 DAY), 3, DATE_SUB(CURDATE(), INTERVAL 30 DAY)),  -- 12mo plan
 ('Selin',   'Akar',      '+905551110002', DATE_SUB(CURDATE(), INTERVAL 120 DAY), 1, DATE_SUB(CURDATE(), INTERVAL  5 DAY)),  -- 1mo  plan
 ('Burak',   'Cetin',     '+905551110003', DATE_SUB(CURDATE(), INTERVAL 400 DAY), 2, DATE_SUB(CURDATE(), INTERVAL 30 DAY)),  -- 3mo  plan
 ('Deniz',   'Polat',     '+905551110004', DATE_SUB(CURDATE(), INTERVAL  60 DAY), 1, DATE_SUB(CURDATE(), INTERVAL  5 DAY)),  -- 1mo  plan
 ('Ece',     'Tan',       '+905551110005', DATE_SUB(CURDATE(), INTERVAL 150 DAY), 4, DATE_SUB(CURDATE(), INTERVAL  7 DAY)),  -- 1mo  plan
 ('Furkan',  'Aksoy',     '+905551110006', DATE_SUB(CURDATE(), INTERVAL 270 DAY), 3, DATE_SUB(CURDATE(), INTERVAL 60 DAY)),  -- 12mo plan
 ('Gizem',   'Erden',     '+905551110007', DATE_SUB(CURDATE(), INTERVAL 120 DAY), 2, DATE_SUB(CURDATE(), INTERVAL 60 DAY));  -- 3mo  plan

-- Health metrics (historical reference points relative to today)
INSERT INTO health_metrics (member_id, weight, body_fat, muscle_mass, recorded_date) VALUES
 (1, 78.40, 18.20, 35.10, DATE_SUB(CURDATE(), INTERVAL 110 DAY)),
 (1, 76.80, 17.10, 36.00, DATE_SUB(CURDATE(), INTERVAL  20 DAY)),
 (2, 62.10, 22.50, 24.30, DATE_SUB(CURDATE(), INTERVAL  35 DAY)),
 (3, 85.60, 20.10, 38.40, DATE_SUB(CURDATE(), INTERVAL  65 DAY)),
 (4, 70.20, 16.80, 32.00, DATE_SUB(CURDATE(), INTERVAL  25 DAY)),
 (6, 90.30, 22.10, 40.20, DATE_SUB(CURDATE(), INTERVAL  80 DAY));

-- Payments (payment_date matches/follows membership start; next_billing_date filled by trigger if omitted, but we set it for clarity)
INSERT INTO payments (member_id, plan_id, amount, payment_date, payment_method, next_billing_date, payment_status) VALUES
 (1, 3, 4800.00, DATE_SUB(CURDATE(), INTERVAL  30 DAY), 'credit_card',   DATE_ADD(CURDATE(), INTERVAL 335 DAY), 'completed'),
 (2, 1,  500.00, DATE_SUB(CURDATE(), INTERVAL   5 DAY), 'cash',          DATE_ADD(CURDATE(), INTERVAL  25 DAY), 'completed'),
 (3, 2, 1350.00, DATE_SUB(CURDATE(), INTERVAL  30 DAY), 'bank_transfer', DATE_ADD(CURDATE(), INTERVAL  60 DAY), 'completed'),
 (4, 1,  500.00, DATE_SUB(CURDATE(), INTERVAL   5 DAY), 'debit_card',    DATE_ADD(CURDATE(), INTERVAL  25 DAY), 'completed'),
 (5, 4,  300.00, DATE_SUB(CURDATE(), INTERVAL   7 DAY), 'cash',          DATE_ADD(CURDATE(), INTERVAL  23 DAY), 'pending'),
 (6, 3, 4800.00, DATE_SUB(CURDATE(), INTERVAL  60 DAY), 'credit_card',   DATE_ADD(CURDATE(), INTERVAL 305 DAY), 'completed'),
 (7, 2, 1350.00, DATE_SUB(CURDATE(), INTERVAL  60 DAY), 'credit_card',   DATE_ADD(CURDATE(), INTERVAL  30 DAY), 'completed');

-- Bookings (CURDATE-relative — past = attended, today = testable check-in, future = upcoming)
INSERT INTO bookings (member_id, schedule_id, booking_date, status) VALUES
 (1, 1, CURDATE(),                            'confirmed'),
 (3, 3, CURDATE(),                            'confirmed'),
 (4, 5, DATE_SUB(CURDATE(), INTERVAL 3 DAY),  'attended'),
 (2, 1, DATE_ADD(CURDATE(), INTERVAL 1 DAY),  'confirmed'),
 (5, 7, DATE_ADD(CURDATE(), INTERVAL 3 DAY),  'confirmed'),
 (6, 8, DATE_ADD(CURDATE(), INTERVAL 5 DAY),  'confirmed'),
 (7, 2, DATE_ADD(CURDATE(), INTERVAL 4 DAY),  'confirmed');

-- Attendance (only the past 'attended' booking #3 has attendance recorded)
INSERT INTO attendance (member_id, booking_id, check_in_time, check_out_time) VALUES
 (4, 3, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 3 DAY), '17:25:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 3 DAY), '18:45:00'));
