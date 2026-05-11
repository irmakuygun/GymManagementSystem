-- =====================================================
-- Triggers
-- =====================================================
USE gym_management;

DROP TRIGGER IF EXISTS trg_members_bi;
DROP TRIGGER IF EXISTS trg_members_bu;
DROP TRIGGER IF EXISTS trg_bookings_bi;
DROP TRIGGER IF EXISTS trg_attendance_bi;
DROP TRIGGER IF EXISTS trg_maintenance_ai;
DROP TRIGGER IF EXISTS trg_maintenance_ad;
DROP TRIGGER IF EXISTS trg_payments_bi;

DELIMITER $$

-- ---------------------------------------------------
-- Auto-fill membership_end_date from plan duration
-- when a member is inserted with a plan_id and a
-- start date but no end date.
-- ---------------------------------------------------
CREATE TRIGGER trg_members_bi
BEFORE INSERT ON members
FOR EACH ROW
BEGIN
    IF NEW.membership_start_date IS NULL THEN
        SET NEW.membership_start_date = NEW.join_date;
    END IF;
    IF NEW.membership_end_date IS NULL AND NEW.plan_id IS NOT NULL THEN
        SET NEW.membership_end_date = plan_end_date(NEW.plan_id, NEW.membership_start_date);
    END IF;
END$$

-- ---------------------------------------------------
-- If plan_id or start_date changes and end_date is
-- not explicitly being set, recompute end_date.
-- ---------------------------------------------------
CREATE TRIGGER trg_members_bu
BEFORE UPDATE ON members
FOR EACH ROW
BEGIN
    IF ((NEW.plan_id <=> OLD.plan_id) = 0
        OR (NEW.membership_start_date <=> OLD.membership_start_date) = 0)
       AND (NEW.membership_end_date <=> OLD.membership_end_date) = 1 THEN
        IF NEW.plan_id IS NOT NULL AND NEW.membership_start_date IS NOT NULL THEN
            SET NEW.membership_end_date =
                plan_end_date(NEW.plan_id, NEW.membership_start_date);
        END IF;
    END IF;
END$$

-- ---------------------------------------------------
-- Prevent overbooking and bookings for inactive
-- members.
-- ---------------------------------------------------
CREATE TRIGGER trg_bookings_bi
BEFORE INSERT ON bookings
FOR EACH ROW
BEGIN
    DECLARE v_capacity INT DEFAULT 0;
    DECLARE v_used     INT DEFAULT 0;
    DECLARE v_active   TINYINT DEFAULT 0;

    SET v_active = is_membership_active(NEW.member_id);
    IF v_active = 0 AND NEW.status IN ('confirmed','attended') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot book: member membership is not active.';
    END IF;

    SELECT c.capacity INTO v_capacity
      FROM class_schedule cs
      JOIN classes c ON c.class_id = cs.class_id
     WHERE cs.schedule_id = NEW.schedule_id;

    SELECT COUNT(*) INTO v_used
      FROM bookings
     WHERE schedule_id  = NEW.schedule_id
       AND booking_date = NEW.booking_date
       AND status IN ('confirmed','attended');

    IF v_used >= v_capacity THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot book: class is full for that date.';
    END IF;
END$$

-- ---------------------------------------------------
-- Sanity-check attendance: check_in cannot be earlier
-- than the booking_date if booking_id is supplied.
-- (Late check-in is allowed; early check-in is not.)
-- ---------------------------------------------------
CREATE TRIGGER trg_attendance_bi
BEFORE INSERT ON attendance
FOR EACH ROW
BEGIN
    DECLARE v_bd DATE;
    IF NEW.booking_id IS NOT NULL THEN
        SELECT booking_date INTO v_bd
          FROM bookings
         WHERE booking_id = NEW.booking_id;
        IF v_bd IS NOT NULL AND DATE(NEW.check_in_time) < v_bd THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Attendance check_in_time cannot be earlier than booking_date.';
        END IF;
    END IF;
END$$

-- ---------------------------------------------------
-- When maintenance is recorded, mark the equipment
-- as 'maintenance'.
-- ---------------------------------------------------
CREATE TRIGGER trg_maintenance_ai
AFTER INSERT ON equipment_maintenance
FOR EACH ROW
BEGIN
    UPDATE equipment
       SET status = 'maintenance'
     WHERE equipment_id = NEW.equipment_id
       AND status <> 'retired';
END$$

-- ---------------------------------------------------
-- When the LAST maintenance record for an equipment
-- is deleted, flip status back to 'available'.
-- ---------------------------------------------------
CREATE TRIGGER trg_maintenance_ad
AFTER DELETE ON equipment_maintenance
FOR EACH ROW
BEGIN
    DECLARE v_left INT DEFAULT 0;
    SELECT COUNT(*) INTO v_left
      FROM equipment_maintenance
     WHERE equipment_id = OLD.equipment_id;
    IF v_left = 0 THEN
        UPDATE equipment
           SET status = 'available'
         WHERE equipment_id = OLD.equipment_id
           AND status = 'maintenance';
    END IF;
END$$

-- ---------------------------------------------------
-- Auto-fill payments.next_billing_date when missing,
-- using the plan's duration.
-- ---------------------------------------------------
CREATE TRIGGER trg_payments_bi
BEFORE INSERT ON payments
FOR EACH ROW
BEGIN
    DECLARE v_months INT DEFAULT 0;
    IF NEW.next_billing_date IS NULL THEN
        SELECT duration_months INTO v_months
          FROM membership_plans
         WHERE plan_id = NEW.plan_id;
        IF v_months IS NOT NULL THEN
            SET NEW.next_billing_date =
                DATE_ADD(NEW.payment_date, INTERVAL v_months MONTH);
        END IF;
    END IF;
END$$

DELIMITER ;
