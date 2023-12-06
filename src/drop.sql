-- Active: 1689044315190@@127.0.0.1@5433@retail


SELECT
    pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE
    pg_stat_activity.datname = 'retail'
    AND pid <> pg_backend_pid();
DROP DATABASE IF EXISTS retail;

CREATE DATABASE retail;

