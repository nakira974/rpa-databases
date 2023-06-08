-- Set default encoding and locale to English_Australia.1752
CREATE DATABASE AnkamaGames
    WITH
    OWNER = postgres          -- sets the owner of the database as "postgres"
    ENCODING = 'UTF8'      -- sets the character encoding of the database
    LC_COLLATE = 'English_Australia.1252'  -- sets the collation rules for sorting strings
    LC_CTYPE = 'English_Australia.1252'    -- sets the character classification rules
    TABLESPACE = pg_default   -- declares the default tablespace where tables will be created
    CONNECTION LIMIT = 256;   -- sets a limit on the number of concurrent connections to the database

-- Adds a description to the database
COMMENT ON DATABASE "AnkamaGames"
    IS 'Ankama Games accounts and related content database';


BEGIN;

\c "AnkamaGames";


CREATE SEQUENCE IF NOT EXISTS accounts_id_seq START 1;
-- Create sequence for accounts table id
CREATE SEQUENCE IF NOT EXISTS accounts_id_seq START 1;

-- Create sequence for characters table id
CREATE SEQUENCE IF NOT EXISTS characters_id_seq START 1;

-- Create accounts table
CREATE TABLE IF NOT EXISTS accounts (
    id BIGINT PRIMARY KEY DEFAULT nextval('accounts_id_seq'),
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL
);

-- Create characters table with foreign key to accounts table for owner field
CREATE TABLE IF NOT EXISTS characters (
    id BIGINT PRIMARY KEY DEFAULT nextval('characters_id_seq'),
    name VARCHAR(255) NOT NULL,
    class VARCHAR(255) NOT NULL,
    owner BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE
);



-- Create materialized view for user characters
CREATE MATERIALIZED VIEW IF NOT EXISTS user_characters AS
    SELECT a.email, c.name, c.class
    FROM accounts a
    JOIN characters c ON c.owner = a.id;

-- Create index on owner field of characters table
CREATE INDEX IF NOT EXISTS idx_characters_owner ON characters(owner);

-- Create function to add character to account
CREATE OR REPLACE FUNCTION add_character_to_account(
    in_email VARCHAR(255),
    in_name VARCHAR(255),
    in_class VARCHAR(255)
) RETURNS VOID AS $$
DECLARE
    account_id BIGINT;
BEGIN
    -- Get account id from email
    SELECT id INTO STRICT account_id FROM accounts WHERE email = in_email LIMIT 1;

    -- If account exists, insert character with account id as owner
    IF FOUND THEN
        INSERT INTO characters(name, class, owner) VALUES (in_name, in_class, account_id);
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION refresh_user_characters()
  RETURNS trigger AS
$$
BEGIN
  REFRESH MATERIALIZED VIEW user_characters;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER tr_accounts_refresh_user_characters
AFTER INSERT OR UPDATE OR DELETE ON accounts
  FOR EACH STATEMENT
  EXECUTE FUNCTION refresh_user_characters();

CREATE OR REPLACE TRIGGER tr_characters_refresh_user_characters
AFTER INSERT OR UPDATE OR DELETE ON characters
  FOR EACH STATEMENT
  EXECUTE FUNCTION refresh_user_characters();
COMMIT;