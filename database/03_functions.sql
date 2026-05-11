-- =====================================================
-- Stored functions and procedures
-- =====================================================
USE gym_management;

DROP FUNCTION IF EXISTS available_spots;
DROP FUNCTION IF EXISTS is_membership_active;
DROP FUNCTION IF EXISTS member_total_revenue;
DROP FUNCTION IF EXISTS plan_end_date;
DROP PROCEDURE IF EXISTS sp_book_class;
DROP PROCEDURE IF EXISTS sp_check_in;

DELIMITER $$

-- ---------------------------------------------------
-- available_spots(schedule_id) -> remaining capacity
-- (capacity minus confirmed/attended bookings for the
--  schedule's most recent occurrence date in bookings)
-- ---------------------------------------------------
CREATE FUNCTION available_spots(p_schedule_id INT, p_booking_date DATE)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_capacity INT DEFAULT 0;
    DECLARE v_used     INT DEFAULT 0;

    SELECT c.capacity INTO v_capacity
      FROM class_schedule cs
      JOIN classes c ON c.class_id = cs.class_id
     WHERE cs.schedule_id = p_schedule_id;

    SELECT COUNT(*) INTO v_used
      FROM bookings
     WHERE schedule_id = p_schedule_id
       AND booking_date = p_booking_date
       AND status IN ('confirmed','attended');

    RETURN GREATEST(v_capacity - v_used, 0);
END$$

-- ---------------------------------------------------
-- is_membership_active(member_id) -> 1 if today is
-- between membership_start_date and membership_end_date
-- ---------------------------------------------------
CREATE FUNCTION is_membership_active(p_member_id INT)
RETURNS TINYINT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_active TINYINT DEFAULT 0;
    SELECT CASE
              WHEN membership_start_date IS NOT NULL
               AND membership_end_date   IS NOT NULL
               AND CURDATE() BETWEEN membership_start_date AND membership_end_date
              THEN 1 ELSE 0
           END
      INTO v_active
      FROM members
     WHERE member_id = p_member_id;
    RETURN COALESCE(v_active, 0);
END$$

-- ---------------------------------------------------
-- member_total_revenue(member_id) -> sum of completed
-- payment amounts
-- ---------------------------------------------------
CREATE FUNCTION member_total_revenue(p_member_id INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(12,2);
    SELECT COALESCE(SUM(amount), 0)
      INTO v_total
      FROM payments
     WHERE member_id = p_member_id
       AND payment_status = 'completed';
    RETURN v_total;
END$$

-- ---------------------------------------------------
-- plan_end_date(plan_id, start_date) -> derived end
-- date based on plan's duration_months.
-- ---------------------------------------------------
CREATE FUNCTION plan_end_date(p_plan_id INT, p_start DATE)
RETURNS DATE
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_months INT DEFAULT 0;
    SELECT duration_months INTO v_months
      FROM membership_plans
     WHERE plan_id = p_plan_id;
    IF v_months IS NULL OR p_start IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN DATE_SUB(DATE_ADD(p_start, INTERVAL v_months MONTH), INTERVAL 1 DAY);
END$$

-- ---------------------------------------------------
-- sp_book_class(member_id, schedule_id, booking_date)
-- Creates a booking only if there is a free spot AND
-- the member's membership is active.
-- ---------------------------------------------------
CREATE PROCEDURE sp_book_class(IN p_member_id   INT,
                               IN p_schedule_id INT,
                               IN p_booking_date DATE)
BEGIN
    IF is_membership_active(p_member_id) = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Membership is not active.';
    END IF;

    IF available_spots(p_schedule_id, p_booking_date) <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Class is full for this date.';
    END IF;

    INSERT INTO bookings (member_id, schedule_id, booking_date, status)
    VALUES (p_member_id, p_schedule_id, p_booking_date, 'confirmed');
END$$

-- ---------------------------------------------------
-- sp_check_in(booking_id) -> creates an attendance row
-- with check_in_time = NOW() and flips booking status
-- to 'attended'.
-- ---------------------------------------------------
CREATE PROCEDURE sp_check_in(IN p_booking_id INT)
BEGIN
    DECLARE v_member_id INT;

    SELECT member_id INTO v_member_id
      FROM bookings
     WHERE booking_id = p_booking_id;

    IF v_member_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Booking not found.';
    END IF;

    INSERT INTO attendance (member_id, booking_id, check_in_time)
    VALUES (v_member_id, p_booking_id, NOW());

    UPDATE bookings SET status = 'attended' WHERE booking_id = p_booking_id;
END$$

DELIMITER ;
