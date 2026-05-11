-- Convenience: run schema + functions + triggers + views + data in the right order.
-- Usage:  mysql -u root -p < run_all.sql
SOURCE 01_schema.sql;
SOURCE 03_functions.sql;
SOURCE 04_triggers.sql;
SOURCE 05_views.sql;
SOURCE 02_data.sql;
