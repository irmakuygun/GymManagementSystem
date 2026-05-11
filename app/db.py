import os
import pymysql
from pymysql.cursors import DictCursor
from dotenv import load_dotenv

load_dotenv()

DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "127.0.0.1"),
    "port":     int(os.getenv("DB_PORT", "3306")),
    "user":     os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASSWORD", ""),
    "database": os.getenv("DB_NAME", "gym_management"),
    "charset":  "utf8mb4",
    "cursorclass": DictCursor,
    "autocommit": True,
}


def get_conn():
    return pymysql.connect(**DB_CONFIG)


def query(sql, params=None, one=False):
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params or ())
            rows = cur.fetchall()
            return (rows[0] if rows else None) if one else rows


def execute(sql, params=None):
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params or ())
            return cur.lastrowid


def call_proc(name, args=()):
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.callproc(name, args)
