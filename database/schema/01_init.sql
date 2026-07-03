/*
===========================================================
Beverage Operating System
01_init.sql
===========================================================
*/

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "citext";

----------------------------------------------------------
-- ENUM
----------------------------------------------------------

CREATE TYPE user_status AS ENUM
(
    'ACTIVE',
    'INACTIVE',
    'LOCKED'
);

CREATE TYPE gender_type AS ENUM
(
    'MALE',
    'FEMALE',
    'OTHER'
);

CREATE TYPE payment_method AS ENUM
(
    'CASH',
    'COD',
    'BANK_TRANSFER',
    'MOMO',
    'ZALOPAY'
);

CREATE TYPE payment_status AS ENUM
(
    'UNPAID',
    'PENDING',
    'PAID',
    'FAILED',
    'REFUNDED'
);

CREATE TYPE order_status AS ENUM
(
    'NEW',
    'CONFIRMED',
    'PREPARING',
    'READY',
    'DELIVERING',
    'COMPLETED',
    'CANCELLED'
);

----------------------------------------------------------
-- BASE FUNCTION
----------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_update_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
BEGIN
    NEW.updated_at = NOW();
    NEW.version = OLD.version + 1;
    RETURN NEW;
END;
$$;

----------------------------------------------------------
-- AUDIT TABLE
----------------------------------------------------------

CREATE TABLE audit_log
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    table_name VARCHAR(100) NOT NULL,

    record_id UUID,

    action VARCHAR(20),

    old_data JSONB,

    new_data JSONB,

    created_by UUID,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_table
ON audit_log(table_name);

CREATE INDEX idx_audit_record
ON audit_log(record_id);

----------------------------------------------------------
-- SETTING
----------------------------------------------------------

CREATE TABLE app_setting
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    setting_key VARCHAR(150) UNIQUE NOT NULL,

    setting_value TEXT,

    description TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    updated_at TIMESTAMPTZ DEFAULT NOW(),

    version INT DEFAULT 1
);

CREATE TRIGGER trg_setting_timestamp
BEFORE UPDATE
ON app_setting
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();