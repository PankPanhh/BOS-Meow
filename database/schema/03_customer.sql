/*
===========================================================
CUSTOMER
===========================================================
*/

----------------------------------------------------------
-- CUSTOMER
----------------------------------------------------------

CREATE TABLE customer
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_code VARCHAR(30) UNIQUE NOT NULL,

    full_name VARCHAR(255),

    phone VARCHAR(20) UNIQUE,

    email CITEXT,

    gender gender_type,
`
    birthday DATE,

    avatar TEXT,

    note TEXT,

    total_order INT DEFAULT 0,

    total_spent NUMERIC(18,2) DEFAULT 0,

    loyalty_point INT DEFAULT 0,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    updated_at TIMESTAMPTZ DEFAULT NOW(),

    deleted_at TIMESTAMPTZ,

    version INT DEFAULT 1
);

----------------------------------------------------------
-- CUSTOMER ADDRESS
----------------------------------------------------------

CREATE TABLE customer_address
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_id UUID NOT NULL,

    receiver_name VARCHAR(255),

    phone VARCHAR(20),

    province VARCHAR(100),

    district VARCHAR(100),

    ward VARCHAR(100),

    address TEXT,

    latitude NUMERIC(10,7),

    longitude NUMERIC(10,7),

    is_default BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    FOREIGN KEY(customer_id)
        REFERENCES customer(id)
        ON DELETE CASCADE
);

----------------------------------------------------------
-- CUSTOMER FAVORITE
----------------------------------------------------------

CREATE TABLE customer_favorite
(
    customer_id UUID,

    product_id UUID,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    PRIMARY KEY(customer_id,product_id)
);

----------------------------------------------------------
-- CUSTOMER QR
----------------------------------------------------------

CREATE TABLE customer_qr
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_id UUID,

    qr_code TEXT,

    expired_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    FOREIGN KEY(customer_id)
        REFERENCES customer(id)
);

----------------------------------------------------------
-- CUSTOMER POINT HISTORY
----------------------------------------------------------

CREATE TABLE customer_point_history
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_id UUID,

    point INT,

    description TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    FOREIGN KEY(customer_id)
        REFERENCES customer(id)
);

----------------------------------------------------------
-- INDEX
----------------------------------------------------------

CREATE INDEX idx_customer_phone
ON customer(phone);

CREATE INDEX idx_customer_code
ON customer(customer_code);

CREATE INDEX idx_customer_address_customer
ON customer_address(customer_id);

CREATE INDEX idx_customer_point
ON customer_point_history(customer_id);

----------------------------------------------------------
-- TRIGGER
----------------------------------------------------------

CREATE TRIGGER trg_customer_update
BEFORE UPDATE
ON customer
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();