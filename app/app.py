"""Gym Management System - Flask front-end.

Run:
    pip install -r requirements.txt
    cp .env.example .env       # then edit the password
    python app.py

The MySQL database `gym_management` must exist (load the SQL files in
../database/ first).
"""
import os
from datetime import date
from flask import (Flask, render_template, request, redirect,
                   url_for, flash, abort)
import pymysql

from db import query, execute, call_proc

app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET", "dev-secret")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _err_message(exc):
    """Pull a clean, user-friendly message out of a pymysql/DB exception."""
    if isinstance(exc, pymysql.MySQLError) and len(exc.args) >= 2:
        code, msg = exc.args[0], exc.args[1]
        # FK violation on parent delete (referenced rows exist)
        if code == 1451:
            return ("Cannot delete: this record is referenced by other rows "
                    "(e.g. payments, bookings, schedules). Delete those first.")
        # FK violation on child insert/update (parent missing)
        if code == 1452:
            return "Cannot save: referenced record does not exist."
        # Duplicate key
        if code == 1062:
            return "Duplicate entry — a record with the same unique value already exists."
        # Custom SIGNAL from triggers/procedures (45000)
        if code == 1644:
            return msg
        # CHECK constraint violation
        if code == 3819:
            return f"Validation failed: {msg}"
        return f"DB error {code}: {msg}"
    return str(exc)


@app.template_filter("fmt_date")
def fmt_date(value):
    if value is None:
        return ""
    if isinstance(value, date):
        return value.strftime("%Y-%m-%d")
    return str(value)


@app.context_processor
def inject_globals():
    return {"today_str": date.today().strftime("%b %d, %Y").upper()}


# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------
@app.route("/")
def index():
    stats = {
        "members":        query("SELECT COUNT(*) AS c FROM members", one=True)["c"],
        "active_members": query("SELECT COUNT(*) AS c FROM v_active_members", one=True)["c"],
        "trainers":       query("SELECT COUNT(*) AS c FROM trainers WHERE employment_status='active'", one=True)["c"],
        "classes":        query("SELECT COUNT(*) AS c FROM classes", one=True)["c"],
        "bookings_today": query(
            "SELECT COUNT(*) AS c FROM bookings WHERE booking_date=CURDATE()", one=True
        )["c"],
        "revenue":        query(
            "SELECT COALESCE(SUM(amount),0) AS s FROM payments WHERE payment_status='completed'",
            one=True,
        )["s"],
    }
    revenue_by_plan = query("SELECT * FROM v_revenue_by_plan ORDER BY total_revenue DESC")
    upcoming = query(
        """SELECT * FROM v_member_bookings_summary
            WHERE booking_date >= CURDATE() AND status='confirmed'
            ORDER BY booking_date, start_time
            LIMIT 10"""
    )
    return render_template(
        "index.html", stats=stats, revenue_by_plan=revenue_by_plan, upcoming=upcoming
    )


# ---------------------------------------------------------------------------
# Membership Plans
# ---------------------------------------------------------------------------
@app.route("/plans")
def plans_list():
    rows = query("SELECT * FROM membership_plans ORDER BY price")
    return render_template("plans/list.html", rows=rows)


@app.route("/plans/new", methods=["GET", "POST"])
@app.route("/plans/<int:pk>/edit", methods=["GET", "POST"])
def plans_form(pk=None):
    row = query("SELECT * FROM membership_plans WHERE plan_id=%s", (pk,), one=True) if pk else None
    if pk and not row:
        abort(404)
    if request.method == "POST":
        f = request.form
        try:
            if pk:
                execute(
                    """UPDATE membership_plans SET plan_name=%s, duration_months=%s,
                              price=%s, access_level=%s WHERE plan_id=%s""",
                    (f["plan_name"], f["duration_months"], f["price"], f["access_level"], pk),
                )
                flash("Plan updated.", "success")
            else:
                execute(
                    """INSERT INTO membership_plans (plan_name, duration_months, price, access_level)
                              VALUES (%s, %s, %s, %s)""",
                    (f["plan_name"], f["duration_months"], f["price"], f["access_level"]),
                )
                flash("Plan created.", "success")
            return redirect(url_for("plans_list"))
        except Exception as e:
            flash(_err_message(e), "danger")
    return render_template("plans/form.html", row=row)


@app.post("/plans/<int:pk>/delete")
def plans_delete(pk):
    try:
        execute("DELETE FROM membership_plans WHERE plan_id=%s", (pk,))
        flash("Plan deleted.", "success")
    except Exception as e:
        flash(_err_message(e), "danger")
    return redirect(url_for("plans_list"))


# ---------------------------------------------------------------------------
# Trainers
# ---------------------------------------------------------------------------
@app.route("/trainers")
def trainers_list():
    rows = query("SELECT * FROM trainers ORDER BY name, surname")
    return render_template("trainers/list.html", rows=rows)


@app.route("/trainers/new", methods=["GET", "POST"])
@app.route("/trainers/<int:pk>/edit", methods=["GET", "POST"])
def trainers_form(pk=None):
    row = query("SELECT * FROM trainers WHERE trainer_id=%s", (pk,), one=True) if pk else None
    if pk and not row:
        abort(404)
    if request.method == "POST":
        f = request.form
        try:
            if pk:
                execute(
                    """UPDATE trainers SET name=%s, surname=%s, specialty=%s,
                              certification_level=%s, employment_status=%s, hire_date=%s,
                              salary=%s WHERE trainer_id=%s""",
                    (f["name"], f["surname"], f.get("specialty"), f.get("certification_level"),
                     f["employment_status"], f["hire_date"], f.get("salary") or None, pk),
                )
                flash("Trainer updated.", "success")
            else:
                execute(
                    """INSERT INTO trainers (name, surname, specialty, certification_level,
                              employment_status, hire_date, salary)
                              VALUES (%s,%s,%s,%s,%s,%s,%s)""",
                    (f["name"], f["surname"], f.get("specialty"), f.get("certification_level"),
                     f["employment_status"], f["hire_date"], f.get("salary") or None),
                )
                flash("Trainer created.", "success")
            return redirect(url_for("trainers_list"))
        except Exception as e:
            flash(_err_message(e), "danger")
    return render_template("trainers/form.html", row=row)


@app.post("/trainers/<int:pk>/delete")
def trainers_delete(pk):
    try:
        execute("DELETE FROM trainers WHERE trainer_id=%s", (pk,))
        flash("Trainer deleted.", "success")
    except Exception as e:
        flash(_err_message(e), "danger")
    return redirect(url_for("trainers_list"))


# ---------------------------------------------------------------------------
# Classes
# ---------------------------------------------------------------------------
@app.route("/classes")
def classes_list():
    rows = query("SELECT * FROM classes ORDER BY class_name")
    return render_template("classes/list.html", rows=rows)


@app.route("/classes/new", methods=["GET", "POST"])
@app.route("/classes/<int:pk>/edit", methods=["GET", "POST"])
def classes_form(pk=None):
    row = query("SELECT * FROM classes WHERE class_id=%s", (pk,), one=True) if pk else None
    if pk and not row:
        abort(404)
    all_equipment = query("SELECT * FROM equipment ORDER BY name")
    selected = set()
    if pk:
        selected = {r["equipment_id"] for r in query(
            "SELECT equipment_id FROM class_equipment WHERE class_id=%s", (pk,)
        )}
    if request.method == "POST":
        f = request.form
        try:
            if pk:
                execute(
                    "UPDATE classes SET class_name=%s, capacity=%s WHERE class_id=%s",
                    (f["class_name"], f["capacity"], pk),
                )
                cid = pk
            else:
                cid = execute(
                    "INSERT INTO classes (class_name, capacity) VALUES (%s,%s)",
                    (f["class_name"], f["capacity"]),
                )
            execute("DELETE FROM class_equipment WHERE class_id=%s", (cid,))
            for eq in request.form.getlist("equipment_ids"):
                execute(
                    "INSERT INTO class_equipment (class_id, equipment_id) VALUES (%s,%s)",
                    (cid, int(eq)),
                )
            flash("Class saved.", "success")
            return redirect(url_for("classes_list"))
        except Exception as e:
            flash(_err_message(e), "danger")
    return render_template("classes/form.html", row=row, all_equipment=all_equipment,
                           selected=selected)


@app.post("/classes/<int:pk>/delete")
def classes_delete(pk):
    try:
        execute("DELETE FROM classes WHERE class_id=%s", (pk,))
        flash("Class deleted.", "success")
    except Exception as e:
        flash(_err_message(e), "danger")
    return redirect(url_for("classes_list"))


# ---------------------------------------------------------------------------
# Class schedule
# ---------------------------------------------------------------------------
@app.route("/schedule")
def schedule_list():
    rows = query("SELECT * FROM v_class_schedule_full ORDER BY day_of_week, start_time")
    return render_template("schedule/list.html", rows=rows)


@app.route("/schedule/new", methods=["GET", "POST"])
@app.route("/schedule/<int:pk>/edit", methods=["GET", "POST"])
def schedule_form(pk=None):
    row = (query("SELECT * FROM class_schedule WHERE schedule_id=%s", (pk,), one=True)
           if pk else None)
    if pk and not row:
        abort(404)
    classes  = query("SELECT * FROM classes ORDER BY class_name")
    trainers = query("SELECT * FROM trainers WHERE employment_status='active' ORDER BY name")
    if request.method == "POST":
        f = request.form
        try:
            if pk:
                execute(
                    """UPDATE class_schedule SET class_id=%s, trainer_id=%s, day_of_week=%s,
                              start_time=%s, duration_min=%s, room=%s WHERE schedule_id=%s""",
                    (f["class_id"], f["trainer_id"], f["day_of_week"], f["start_time"],
                     f["duration_min"], f.get("room"), pk),
                )
            else:
                execute(
                    """INSERT INTO class_schedule (class_id, trainer_id, day_of_week, start_time,
                              duration_min, room) VALUES (%s,%s,%s,%s,%s,%s)""",
                    (f["class_id"], f["trainer_id"], f["day_of_week"], f["start_time"],
                     f["duration_min"], f.get("room")),
                )
            flash("Schedule saved.", "success")
            return redirect(url_for("schedule_list"))
        except Exception as e:
            flash(_err_message(e), "danger")
    return render_template("schedule/form.html", row=row, classes=classes, trainers=trainers)


@app.post("/schedule/<int:pk>/delete")
def schedule_delete(pk):
    try:
        execute("DELETE FROM class_schedule WHERE schedule_id=%s", (pk,))
        flash("Schedule deleted.", "success")
    except Exception as e:
        flash(_err_message(e), "danger")
    return redirect(url_for("schedule_list"))


# ---------------------------------------------------------------------------
# Equipment
# ---------------------------------------------------------------------------
@app.route("/equipment")
def equipment_list():
    rows = query("SELECT * FROM v_equipment_status ORDER BY name")
    return render_template("equipment/list.html", rows=rows)


@app.route("/equipment/new", methods=["GET", "POST"])
@app.route("/equipment/<int:pk>/edit", methods=["GET", "POST"])
def equipment_form(pk=None):
    row = query("SELECT * FROM equipment WHERE equipment_id=%s", (pk,), one=True) if pk else None
    if pk and not row:
        abort(404)
    if request.method == "POST":
        f = request.form
        try:
            if pk:
                execute(
                    "UPDATE equipment SET name=%s, status=%s WHERE equipment_id=%s",
                    (f["name"], f["status"], pk),
                )
            else:
                execute(
                    "INSERT INTO equipment (name, status) VALUES (%s,%s)",
                    (f["name"], f["status"]),
                )
            flash("Equipment saved.", "success")
            return redirect(url_for("equipment_list"))
        except Exception as e:
            flash(_err_message(e), "danger")
    return render_template("equipment/form.html", row=row)


@app.post("/equipment/<int:pk>/delete")
def equipment_delete(pk):
    try:
        execute("DELETE FROM equipment WHERE equipment_id=%s", (pk,))
        flash("Equipment deleted.", "success")
    except Exception as e:
        flash(_err_message(e), "danger")
    return redirect(url_for("equipment_list"))


# Equipment maintenance (sub-list per equipment)
@app.route("/equipment/<int:eq_id>/maintenance", methods=["GET", "POST"])
def maintenance_list(eq_id):
    eq = query("SELECT * FROM equipment WHERE equipment_id=%s", (eq_id,), one=True)
    if not eq:
        abort(404)
    if request.method == "POST":
        f = request.form
        try:
            execute(
                """INSERT INTO equipment_maintenance
                          (equipment_id, maintenance_date, description, technician_name)
                          VALUES (%s,%s,%s,%s)""",
                (eq_id, f["maintenance_date"], f.get("description"), f.get("technician_name")),
            )
            flash("Maintenance record added.", "success")
            return redirect(url_for("maintenance_list", eq_id=eq_id))
        except Exception as e:
            flash(_err_message(e), "danger")
    rows = query(
        "SELECT * FROM equipment_maintenance WHERE equipment_id=%s ORDER BY maintenance_date DESC",
        (eq_id,),
    )
    return render_template("equipment/maintenance.html", eq=eq, rows=rows)


@app.post("/maintenance/<int:pk>/delete")
def maintenance_delete(pk):
    rec = query("SELECT * FROM equipment_maintenance WHERE maintenance_id=%s", (pk,), one=True)
    if not rec:
        abort(404)
    try:
        execute("DELETE FROM equipment_maintenance WHERE maintenance_id=%s", (pk,))
        flash("Maintenance record deleted.", "success")
    except Exception as e:
        flash(_err_message(e), "danger")
    return redirect(url_for("maintenance_list", eq_id=rec["equipment_id"]))


# ---------------------------------------------------------------------------
# Members
# ---------------------------------------------------------------------------
@app.route("/members")
def members_list():
    rows = query("SELECT * FROM v_member_overview ORDER BY name, surname")
    return render_template("members/list.html", rows=rows)


@app.route("/members/<int:pk>")
def members_detail(pk):
    m = query("SELECT * FROM v_member_overview WHERE member_id=%s", (pk,), one=True)
    if not m:
        abort(404)
    metrics  = query("SELECT * FROM health_metrics WHERE member_id=%s ORDER BY recorded_date DESC",
                     (pk,))
    payments = query("SELECT * FROM payments WHERE member_id=%s ORDER BY payment_date DESC", (pk,))
    bookings = query(
        "SELECT * FROM v_member_bookings_summary WHERE member_id=%s ORDER BY booking_date DESC",
        (pk,),
    )
    return render_template("members/detail.html", m=m, metrics=metrics,
                           payments=payments, bookings=bookings)


@app.route("/members/new", methods=["GET", "POST"])
@app.route("/members/<int:pk>/edit", methods=["GET", "POST"])
def members_form(pk=None):
    row = query("SELECT * FROM members WHERE member_id=%s", (pk,), one=True) if pk else None
    if pk and not row:
        abort(404)
    plans = query("SELECT * FROM membership_plans ORDER BY price")
    if request.method == "POST":
        f = request.form
        try:
            args = (
                f["name"], f["surname"], f.get("phone"), f["join_date"],
                f.get("plan_id") or None,
                f.get("membership_start_date") or None,
                f.get("membership_end_date") or None,
            )
            if pk:
                execute(
                    """UPDATE members SET name=%s, surname=%s, phone=%s, join_date=%s,
                              plan_id=%s, membership_start_date=%s, membership_end_date=%s
                              WHERE member_id=%s""",
                    args + (pk,),
                )
            else:
                execute(
                    """INSERT INTO members (name, surname, phone, join_date, plan_id,
                              membership_start_date, membership_end_date)
                              VALUES (%s,%s,%s,%s,%s,%s,%s)""",
                    args,
                )
            flash("Member saved.", "success")
            return redirect(url_for("members_list"))
        except Exception as e:
            flash(_err_message(e), "danger")
    return render_template("members/form.html", row=row, plans=plans)


@app.post("/members/<int:pk>/delete")
def members_delete(pk):
    try:
        execute("DELETE FROM members WHERE member_id=%s", (pk,))
        flash("Member deleted.", "success")
    except Exception as e:
        flash(_err_message(e), "danger")
    return redirect(url_for("members_list"))


# ---------------------------------------------------------------------------
# Health metrics
# ---------------------------------------------------------------------------
@app.route("/metrics")
def metrics_list():
    rows = query(
        """SELECT hm.*, CONCAT(m.name,' ',m.surname) AS member_name
             FROM health_metrics hm JOIN members m USING (member_id)
            ORDER BY recorded_date DESC"""
    )
    return render_template("metrics/list.html", rows=rows)


@app.route("/metrics/new", methods=["GET", "POST"])
@app.route("/metrics/<int:pk>/edit", methods=["GET", "POST"])
def metrics_form(pk=None):
    row = query("SELECT * FROM health_metrics WHERE metric_id=%s", (pk,), one=True) if pk else None
    if pk and not row:
        abort(404)
    members = query("SELECT member_id, name, surname FROM members ORDER BY name")
    if request.method == "POST":
        f = request.form
        try:
            if pk:
                execute(
                    """UPDATE health_metrics SET member_id=%s, weight=%s, body_fat=%s,
                              muscle_mass=%s, recorded_date=%s WHERE metric_id=%s""",
                    (f["member_id"], f.get("weight") or None, f.get("body_fat") or None,
                     f.get("muscle_mass") or None, f["recorded_date"], pk),
                )
            else:
                execute(
                    """INSERT INTO health_metrics (member_id, weight, body_fat, muscle_mass,
                              recorded_date) VALUES (%s,%s,%s,%s,%s)""",
                    (f["member_id"], f.get("weight") or None, f.get("body_fat") or None,
                     f.get("muscle_mass") or None, f["recorded_date"]),
                )
            flash("Health metric saved.", "success")
            return redirect(url_for("metrics_list"))
        except Exception as e:
            flash(_err_message(e), "danger")
    return render_template("metrics/form.html", row=row, members=members)


@app.post("/metrics/<int:pk>/delete")
def metrics_delete(pk):
    try:
        execute("DELETE FROM health_metrics WHERE metric_id=%s", (pk,))
        flash("Metric deleted.", "success")
    except Exception as e:
        flash(_err_message(e), "danger")
    return redirect(url_for("metrics_list"))


# ---------------------------------------------------------------------------
# Payments
# ---------------------------------------------------------------------------
@app.route("/payments")
def payments_list():
    rows = query(
        """SELECT p.*, CONCAT(m.name,' ',m.surname) AS member_name, mp.plan_name
             FROM payments p
             JOIN members  m  ON m.member_id = p.member_id
             JOIN membership_plans mp ON mp.plan_id = p.plan_id
            ORDER BY p.payment_date DESC"""
    )
    return render_template("payments/list.html", rows=rows)


@app.route("/payments/new", methods=["GET", "POST"])
@app.route("/payments/<int:pk>/edit", methods=["GET", "POST"])
def payments_form(pk=None):
    row = query("SELECT * FROM payments WHERE payment_id=%s", (pk,), one=True) if pk else None
    if pk and not row:
        abort(404)
    members = query("SELECT member_id, name, surname FROM members ORDER BY name")
    plans   = query("SELECT * FROM membership_plans ORDER BY price")
    if request.method == "POST":
        f = request.form
        try:
            if pk:
                execute(
                    """UPDATE payments SET member_id=%s, plan_id=%s, amount=%s,
                              payment_date=%s, payment_method=%s, next_billing_date=%s,
                              payment_status=%s WHERE payment_id=%s""",
                    (f["member_id"], f["plan_id"], f["amount"], f["payment_date"],
                     f["payment_method"], f.get("next_billing_date") or None,
                     f["payment_status"], pk),
                )
            else:
                execute(
                    """INSERT INTO payments (member_id, plan_id, amount, payment_date,
                              payment_method, next_billing_date, payment_status)
                              VALUES (%s,%s,%s,%s,%s,%s,%s)""",
                    (f["member_id"], f["plan_id"], f["amount"], f["payment_date"],
                     f["payment_method"], f.get("next_billing_date") or None,
                     f["payment_status"]),
                )
            flash("Payment saved.", "success")
            return redirect(url_for("payments_list"))
        except Exception as e:
            flash(_err_message(e), "danger")
    return render_template("payments/form.html", row=row, members=members, plans=plans)


@app.post("/payments/<int:pk>/delete")
def payments_delete(pk):
    try:
        execute("DELETE FROM payments WHERE payment_id=%s", (pk,))
        flash("Payment deleted.", "success")
    except Exception as e:
        flash(_err_message(e), "danger")
    return redirect(url_for("payments_list"))


# ---------------------------------------------------------------------------
# Bookings  (uses sp_book_class so triggers/SP enforce rules)
# ---------------------------------------------------------------------------
@app.route("/bookings")
def bookings_list():
    rows = query(
        "SELECT * FROM v_member_bookings_summary ORDER BY booking_date DESC, start_time"
    )
    return render_template("bookings/list.html", rows=rows)


@app.route("/bookings/new", methods=["GET", "POST"])
def bookings_new():
    members  = query("SELECT member_id, name, surname FROM members ORDER BY name")
    schedule = query("SELECT * FROM v_class_schedule_full ORDER BY day_of_week, start_time")
    if request.method == "POST":
        f = request.form
        try:
            call_proc("sp_book_class",
                      (int(f["member_id"]), int(f["schedule_id"]), f["booking_date"]))
            flash("Booking created.", "success")
            return redirect(url_for("bookings_list"))
        except Exception as e:
            flash(_err_message(e), "danger")
    return render_template("bookings/form.html", members=members, schedule=schedule)


@app.post("/bookings/<int:pk>/cancel")
def bookings_cancel(pk):
    try:
        execute("UPDATE bookings SET status='cancelled' WHERE booking_id=%s", (pk,))
        flash("Booking cancelled.", "success")
    except Exception as e:
        flash(_err_message(e), "danger")
    return redirect(url_for("bookings_list"))


@app.post("/bookings/<int:pk>/delete")
def bookings_delete(pk):
    try:
        execute("DELETE FROM bookings WHERE booking_id=%s", (pk,))
        flash("Booking deleted.", "success")
    except Exception as e:
        flash(_err_message(e), "danger")
    return redirect(url_for("bookings_list"))


# ---------------------------------------------------------------------------
# Attendance
# ---------------------------------------------------------------------------
@app.route("/attendance")
def attendance_list():
    rows = query(
        """SELECT a.*, CONCAT(m.name,' ',m.surname) AS member_name,
                  c.class_name, b.booking_date
             FROM attendance a
             JOIN members m USING (member_id)
             LEFT JOIN bookings b ON b.booking_id = a.booking_id
             LEFT JOIN class_schedule cs ON cs.schedule_id = b.schedule_id
             LEFT JOIN classes c ON c.class_id = cs.class_id
            ORDER BY check_in_time DESC"""
    )
    return render_template("attendance/list.html", rows=rows)


@app.route("/attendance/checkin/<int:booking_id>", methods=["POST"])
def attendance_checkin(booking_id):
    try:
        call_proc("sp_check_in", (booking_id,))
        flash("Checked in.", "success")
    except Exception as e:
        flash(_err_message(e), "danger")
    return redirect(url_for("bookings_list"))


@app.post("/attendance/<int:pk>/checkout")
def attendance_checkout(pk):
    try:
        execute("UPDATE attendance SET check_out_time=NOW() WHERE log_id=%s", (pk,))
        flash("Checked out.", "success")
    except Exception as e:
        flash(_err_message(e), "danger")
    return redirect(url_for("attendance_list"))


@app.post("/attendance/<int:pk>/delete")
def attendance_delete(pk):
    try:
        execute("DELETE FROM attendance WHERE log_id=%s", (pk,))
        flash("Attendance deleted.", "success")
    except Exception as e:
        flash(_err_message(e), "danger")
    return redirect(url_for("attendance_list"))


if __name__ == "__main__":
    app.run(debug=True, port=5050)
