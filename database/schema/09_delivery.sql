/*
===========================================================
Beverage Operating System
09_delivery.sql
Delivery (Giao hàng tự vận hành - không qua Grab/Shopee)
===========================================================
*/

------------------------------------------------------------
-- ENUM
------------------------------------------------------------

CREATE TYPE delivery_status AS ENUM
(
    'WAITING',
    'ASSIGNED',
    'PICKED_UP',
    'DELIVERING',
    'DELIVERED',
    'FAILED',
    'CANCELLED'
);

------------------------------------------------------------
-- DELIVERY
------------------------------------------------------------

CREATE TABLE delivery
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id                  UUID UNIQUE NOT NULL,

    delivery_code                VARCHAR(50) UNIQUE NOT NULL,

    delivery_user_id                UUID,

    receiver_name                     VARCHAR(255),

    receiver_phone                      VARCHAR(20),

    province                              VARCHAR(100),

    district                                VARCHAR(100),

    ward                                      VARCHAR(100),

    address                                     TEXT,

    latitude                                      NUMERIC(10,7),

    longitude                                       NUMERIC(10,7),

    distance_km                                       NUMERIC(10,2),

    delivery_fee                                        NUMERIC(18,2) DEFAULT 0,

    status                                                delivery_status DEFAULT 'WAITING',

    assigned_at                                             TIMESTAMPTZ,

    picked_up_at                                              TIMESTAMPTZ,

    delivering_at                                               TIMESTAMPTZ,

    delivered_at                                                  TIMESTAMPTZ,

    failed_reason                                                   TEXT,

    note                                                              TEXT,

    created_at                                                          TIMESTAMPTZ DEFAULT NOW(),

    updated_at                                                            TIMESTAMPTZ DEFAULT NOW(),

    version                                                                 INT DEFAULT 1,

    CONSTRAINT fk_delivery_order
        FOREIGN KEY(order_id)
        REFERENCES orders(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_delivery_user
        FOREIGN KEY(delivery_user_id)
        REFERENCES app_user(id)
);

CREATE INDEX idx_delivery_order
ON delivery(order_id);

CREATE INDEX idx_delivery_user
ON delivery(delivery_user_id);

CREATE INDEX idx_delivery_status
ON delivery(status);

------------------------------------------------------------
-- DELIVERY TRACKING (VỊ TRÍ REAL-TIME)
------------------------------------------------------------

CREATE TABLE delivery_tracking
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    delivery_id               UUID NOT NULL,

    latitude                     NUMERIC(10,7) NOT NULL,

    longitude                      NUMERIC(10,7) NOT NULL,

    tracked_at                       TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_delivery_tracking_delivery
        FOREIGN KEY(delivery_id)
        REFERENCES delivery(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_delivery_tracking_delivery
ON delivery_tracking(delivery_id);

------------------------------------------------------------
-- DELIVERY PROOF (BẰNG CHỨNG GIAO HÀNG)
------------------------------------------------------------

CREATE TABLE delivery_proof
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    delivery_id               UUID NOT NULL,

    image_url                    TEXT,

    signature_url                  TEXT,

    note                              TEXT,

    created_at                          TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_delivery_proof_delivery
        FOREIGN KEY(delivery_id)
        REFERENCES delivery(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- DELIVERY RATING
------------------------------------------------------------

CREATE TABLE delivery_rating
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    delivery_id               UUID NOT NULL,

    customer_id                  UUID,

    rating                          SMALLINT NOT NULL CHECK(rating BETWEEN 1 AND 5),

    comment                           TEXT,

    created_at                          TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_delivery_rating_delivery
        FOREIGN KEY(delivery_id)
        REFERENCES delivery(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_delivery_rating_customer
        FOREIGN KEY(customer_id)
        REFERENCES customer(id)
);

CREATE INDEX idx_delivery_rating_delivery
ON delivery_rating(delivery_id);

------------------------------------------------------------
-- UPDATE TRIGGER
------------------------------------------------------------

CREATE TRIGGER trg_delivery_update
BEFORE UPDATE
ON delivery
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();