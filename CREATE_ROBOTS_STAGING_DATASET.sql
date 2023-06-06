BEGIN;
\c "Robots_Staging";

-- Inserts sample robots into the "robots" table
INSERT INTO robots(robot_name, robot_description)
VALUES('Robot 1', 'This is the first robot'),
      ('Robot 2', 'This is the second robot'),
      ('Robot 3', 'This is the third robot');

-- Inserts sample jobs into the "jobs" table
INSERT INTO jobs(job_name, job_description, job_priority, job_schedule_time, job_duration, job_status, robot_id)
VALUES('Job 1', 'This is the first job', 'High', NOW() + INTERVAL '1 hour', INTERVAL '2 hours', 'Scheduled', 1),
      ('Job 2', 'This is the second job', 'Low', NOW() - INTERVAL '2 hours', INTERVAL '1 hour', 'Completed', 2),
      ('Job 3', 'This is the third job', 'Medium', NOW() + INTERVAL '30 minutes', INTERVAL '45 minutes', 'In Progress', 3),
      ('Job 4', 'This is the fourth job', 'High', NOW() + INTERVAL '2 days', INTERVAL '6 hours', 'Scheduled', 1),
      ('Job 5', 'This is the fifth job', 'Medium', NOW() - INTERVAL '1 day', INTERVAL '3 hours', 'Failed', 2);

-- Inserts sample logs into the "logs" table
INSERT INTO logs(log_time, log_message, status_code, job_id)
VALUES(NOW() - INTERVAL '30 minutes', 'Job started', NULL, 1),
      (NOW() - INTERVAL '15 minutes', 'Job in progress', NULL, 1),
      (NOW(), 'Job completed successfully', 1, 1),
      (NOW() - INTERVAL '2 hours', 'Job started', NULL, 2),
      (NOW() - INTERVAL '1 hour', 'Job execution failed', 0, 2),
      (NOW() + INTERVAL '10 minutes', 'Job scheduled', NULL, 3);

-- Updates the status of a job to "Failed"
UPDATE jobs SET job_status = 'Failed' WHERE job_id = 4;

-- Inserts a new log entry for the failed job
INSERT INTO logs(log_time, log_message, status_code, job_id)
VALUES(NOW(), 'Job execution failed', 0, 4);

-- Inserts sample data into the full-text search table
INSERT INTO fts(fts_content, job_id)
SELECT TO_TSVECTOR('english', job_description), job_id
FROM jobs;

-- Refreshes the materialized view for daily log summaries
REFRESH MATERIALIZED VIEW daily_log_summary;

-- Commits the transaction
COMMIT;