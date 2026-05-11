-- =====================================================
-- Reporting views
-- =====================================================
USE gym_management;

DROP VIEW IF EXISTS v_active_members;
DROP VIEW IF EXISTS v_member_overview;
DROP VIEW IF EXISTS v_class_schedule_full;
DROP VIEW IF EXISTS v_member_bookings_summary;
DROP VIEW IF EXISTS v_equipment_status;
DROP VIEW IF EXISTS v_revenue_by_plan;

-- Active members (membership window covers today)
CREATE VIEW v_active_members AS
SELECT m.member_id, m.name, m.surname, m.phone,
       p.plan_name, m.membership_start_date, m.membership_end_date
  FROM members m
  LEFT JOIN membership_plans p ON p.plan_id = m.plan_id
 WHERE is_membership_active(m.member_id) = 1;

-- Member 360°: plan, totals, last metric
CREATE VIEW v_member_overview AS
SELECT m.member_id, m.name, m.surname, m.phone, m.join_date,
       p.plan_name, m.membership_start_date, m.membership_end_date,
       is_membership_active(m.member_id) AS is_active,
       member_total_revenue(m.member_id) AS total_paid,
       (SELECT recorded_date FROM health_metrics
         WHERE member_id = m.member_id
         ORDER BY recorded_date DESC LIMIT 1) AS last_metric_date,
       (SELECT weight FROM health_metrics
         WHERE member_id = m.member_id
         ORDER BY recorded_date DESC LIMIT 1) AS last_weight
  FROM members m
  LEFT JOIN membership_plans p ON p.plan_id = m.plan_id;

-- Class schedule with denormalized class + trainer names
CREATE VIEW v_class_schedule_full AS
SELECT cs.schedule_id, cs.day_of_week, cs.start_time, cs.duration_min, cs.room,
       c.class_id,  c.class_name, c.capacity,
       t.trainer_id, CONCAT(t.name, ' ', t.surname) AS trainer_name,
       t.specialty
  FROM class_schedule cs
  JOIN classes  c ON c.class_id  = cs.class_id
  JOIN trainers t ON t.trainer_id = cs.trainer_id;

-- Member booking history
CREATE VIEW v_member_bookings_summary AS
SELECT b.booking_id, b.member_id,
       CONCAT(m.name, ' ', m.surname)        AS member_name,
       b.schedule_id, c.class_name,
       cs.day_of_week, cs.start_time, cs.room,
       CONCAT(t.name, ' ', t.surname)        AS trainer_name,
       b.booking_date, b.status
  FROM bookings b
  JOIN members  m  ON m.member_id  = b.member_id
  JOIN class_schedule cs ON cs.schedule_id = b.schedule_id
  JOIN classes  c  ON c.class_id   = cs.class_id
  JOIN trainers t  ON t.trainer_id = cs.trainer_id;

-- Equipment + most-recent maintenance
CREATE VIEW v_equipment_status AS
SELECT e.equipment_id, e.name, e.status,
       (SELECT MAX(maintenance_date)
          FROM equipment_maintenance em
         WHERE em.equipment_id = e.equipment_id) AS last_maintenance,
       (SELECT COUNT(*) FROM equipment_maintenance em
         WHERE em.equipment_id = e.equipment_id) AS maintenance_count
  FROM equipment e;

-- Total completed revenue per plan
CREATE VIEW v_revenue_by_plan AS
SELECT p.plan_id, p.plan_name, p.price,
       COUNT(pay.payment_id) AS completed_payments,
       COALESCE(SUM(CASE WHEN pay.payment_status='completed'
                         THEN pay.amount END), 0) AS total_revenue
  FROM membership_plans p
  LEFT JOIN payments pay ON pay.plan_id = p.plan_id
 GROUP BY p.plan_id, p.plan_name, p.price;
