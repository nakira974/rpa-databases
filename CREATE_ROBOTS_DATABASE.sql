-- Creates a new database called "Robots"
CREATE DATABASE "Robots"
    WITH
    OWNER = postgres          -- sets the owner of the database as "postgres"
    ENCODING = 'WIN1252'      -- sets the character encoding of the database
    LC_COLLATE = 'French_France.1252'  -- sets the collation rules for sorting strings
    LC_CTYPE = 'French_France.1252'    -- sets the character classification rules
    TABLESPACE = pg_default   -- declares the default tablespace where tables will be created
    CONNECTION LIMIT = 256;   -- sets a limit on the number of concurrent connections to the database

-- Adds a description to the database
COMMENT ON DATABASE "Robots"
    IS 'RPA job execution logging and scheduling database';

-- Switches to the newly created database
BEGIN;
\c "Robots";

-- Creates sequences for generating unique IDs for the tables
CREATE SEQUENCE IF NOT EXISTS robot_id_seq;
CREATE SEQUENCE IF NOT EXISTS job_id_seq;
CREATE SEQUENCE IF NOT EXISTS log_id_seq;
CREATE SEQUENCE IF NOT EXISTS fts_id_seq;

-- Creates the "robots" table
CREATE TABLE IF NOT EXISTS robots (
    robot_id INTEGER DEFAULT NEXTVAL('robot_id_seq'::regclass) PRIMARY KEY,
    robot_name TEXT,
    robot_description TEXT
);

-- Creates the "jobs" table
CREATE TABLE IF NOT EXISTS jobs (
    job_id INTEGER DEFAULT NEXTVAL('job_id_seq'::regclass) PRIMARY KEY,
    job_name TEXT,
    job_description TEXT,
    job_priority TEXT,
    job_schedule_time TIMESTAMP,
    job_duration INTERVAL,
    job_status TEXT,
    robot_id INTEGER REFERENCES robots(robot_id)
);

-- Creates the "logs" table
CREATE TABLE IF NOT EXISTS logs (
    log_id INTEGER DEFAULT NEXTVAL('log_id_seq'::regclass) PRIMARY KEY,
    log_time TIMESTAMP DEFAULT NOW(),
    log_message TEXT,
    status_code INTEGER,
    job_id INTEGER REFERENCES jobs(job_id)
);

-- Creates the "fts" table for full-text search
CREATE TABLE IF NOT EXISTS fts (
    fts_id INTEGER DEFAULT NEXTVAL('fts_id_seq'::regclass) PRIMARY KEY,
    fts_content TSVECTOR,
    job_id INTEGER REFERENCES jobs(job_id)
);

-- Creates a custom function for calculating estimated job duration
CREATE OR REPLACE FUNCTION get_job_duration(job_description TEXT) RETURNS INTERVAL AS $$
DECLARE
  duration INTERVAL;
BEGIN
  -- custom logic to calculate the estimated duration of a job based on its description
  RETURN duration;
END;
$$ LANGUAGE plpgsql;

-- Creates a custom function for executing a job on a specified robot
CREATE OR REPLACE FUNCTION execute_job(job_id INTEGER, robot_id INTEGER) RETURNS VOID AS $$
BEGIN
  -- custom logic to execute a job on a specified robot
END;
$$ LANGUAGE plpgsql;

-- Creates indexes for faster querying of data
CREATE INDEX IF NOT EXISTS idx_job_schedule_time ON jobs(job_schedule_time);
CREATE INDEX IF NOT EXISTS idx_log_status_code ON logs(status_code);
CREATE INDEX IF NOT EXISTS idx_fts_content ON fts USING gin(fts_content);

-- Creates a function for adding a new job to the database
CREATE OR REPLACE FUNCTION add_job(job_name TEXT, job_description TEXT, job_priority TEXT,
                                   job_schedule_time TIMESTAMP, robot_id INTEGER)
RETURNS INTEGER AS $$
DECLARE
  job_id INTEGER;
BEGIN
  INSERT INTO jobs(job_name, job_description, job_priority, job_schedule_time, robot_id)
  VALUES(job_name, job_description, job_priority, job_schedule_time, robot_id)
  RETURNING job_id INTO job_id;

  -- Adds the new job to the full-text search table
  INSERT INTO fts(fts_content, job_id)
  SELECT TO_TSVECTOR('english', job_description), job_id;

  RETURN job_id;
END;
$$ LANGUAGE plpgsql;

-- Creates a function for updating job status in the "logs" table
CREATE OR REPLACE FUNCTION update_job_status()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.job_status != OLD.job_status THEN
    INSERT INTO logs(log_message, status_code, job_id)
    VALUES(
      CASE
        WHEN NEW.job_status = 'Completed' THEN 'Job completed successfully'
        ELSE 'Job execution failed'
      END,
      CASE
        WHEN NEW.job_status = 'Completed' THEN 1
        ELSE 0
      END,
      NEW.job_id
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Creates a trigger to execute the "update_job_status" function when a job's status is updated
CREATE OR REPLACE TRIGGER tr_upd_job_status
AFTER UPDATE ON jobs
FOR EACH ROW
EXECUTE FUNCTION update_job_status();

-- Creates a function for inserting a new log entry
CREATE OR REPLACE FUNCTION insert_log_entry()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO logs(log_message, status_code, job_id)
  VALUES(
    CASE
      WHEN NEW.status_code = 1 THEN 'Execution succeeded'
      ELSE 'Execution failed'
    END,
    NEW.status_code,
    NEW.job_id
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Creates a trigger to execute the "insert_log_entry" function before a new log entry is inserted
CREATE OR REPLACE TRIGGER tr_ins_log_entry
BEFORE INSERT ON logs
FOR EACH ROW
EXECUTE FUNCTION insert_log_entry();

-- Creates a materialized view for daily log summaries
CREATE MATERIALIZED VIEW IF NOT EXISTS daily_log_summary AS
SELECT
  DATE_TRUNC('day', log_time) AS log_date,
  COUNT(*) AS total_logs,
  SUM(CASE WHEN status_code = 1 THEN 1 ELSE 0 END) AS succeeded_logs,
  SUM(CASE WHEN status_code = 0 THEN 1 ELSE 0 END) AS failed_logs
FROM logs
GROUP BY DATE_TRUNC('day', log_time);

-- Creates an index on the log_date column of the daily_log_summary table
CREATE INDEX IF NOT EXISTS idx_daily_log_summary_date ON daily_log_summary(log_date);

-- Adds a text search configuration for searching through log messages
DO $$BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_ts_config WHERE cfgname = 'logs_search_config'
  ) THEN

    CREATE TEXT SEARCH DICTIONARY english_stem (
            TEMPLATE = snowball,
            Language = english
        );

    CREATE TEXT SEARCH CONFIGURATION logs_search_config (
      PARSER = pg_catalog.default
    );

    ALTER TEXT SEARCH CONFIGURATION logs_search_config
        ADD MAPPING FOR asciiword, word, numword WITH english_stem;

  END IF;
END$$;

-- Creates an index on the log_message column of the logs table for full-text search
CREATE INDEX IF NOT EXISTS idx_logs_fts_content ON logs USING gin(to_tsvector('logs_search_config', log_message));

-- Commits the transaction
COMMIT;