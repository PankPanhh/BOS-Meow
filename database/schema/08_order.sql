/*
===========================================================
Beverage Operating System
08_order.sql
Order (Đơn hàng) - Order Item - Timeline - Payment
===========================================================
*/

------------------------------------------------------------
-- ENUM
------------------------------------------------------------

CREATE TYPE order_type AS ENUM
(
    'DINE_IN',
    'TAKE_AWAY',
    'DELIVERY'
);

CREATE TYPE order_source AS ENUM
(
    'QR',
    'WEBSITE',
    'APP',
    'POS'
);

------------------------------------------------------------
-- SEQUENCE (SINH MÃ ĐƠN HÀNG)
------------------------------------------------------------

CREATE SEQUENCE seq_order_code START 1;

------------------------------------------------------------
-- ORDER
-- Đơn hàng là "sự kiện khởi đầu" (event trigger) cho toàn bộ
-- chuỗi workflow: Kitchen - Inventory - Cost - Dashboard -
-- Notification (xem chi tiết ở 11_trigger.sql)
------------------------------------------------------------

CREATE TABLE orders
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_code                VARCHAR(50) UNIQUE NOT NULL,

    customer_id                  UUID,

    warehouse_id                    UUID NOT NULL,

    order_type                        order_type NOT NULL DEFAULT 'TAKE_AWAY',

    order_source                        order_source NOT NULL DEFAULT 'QR',

    status                                order_status DEFAULT 'NEW',

    payment_status                         payment_status DEFAULT 'UNPAID',

    payment_method                           payment_method,

    table_no                                   VARCHAR(20),

    subtotal_amount                              NUMERIC(18,2) DEFAULT 0,

    discount_amount                                NUMERIC(18,2) DEFAULT 0,

    shipping_fee                                     NUMERIC(18,2) DEFAULT 0,

    tax_amount                                         NUMERIC(18,2) DEFAULT 0,

    total_amount                                         NUMERIC(18,2) DEFAULT 0,

    note                                                   TEXT,

    cancel_reason                                            TEXT,

    confirmed_at                                               TIMESTAMPTZ,

    completed_at                                                 TIMESTAMPTZ,

    cancelled_at                                                   TIMESTAMPTZ,

    created_by                                                       UUID,

    created_at                                                         TIMESTAMPTZ DEFAULT NOW(),

    updated_at                                                           TIMESTAMPTZ DEFAULT NOW(),

    version                                                                INT DEFAULT 1,

    CONSTRAINT fk_order_customer
        FOREIGN KEY(customer_id)
        REFERENCES customer(id),

    CONSTRAINT fk_order_warehouse
        FOREIGN KEY(warehouse_id)
        REFERENCES warehouse(id),

    CONSTRAINT fk_order_user
        FOREIGN KEY(created_by)
        REFERENCES app_user(id)
);

CREATE INDEX idx_order_code
ON orders(order_code);

CREATE INDEX idx_order_customer
ON orders(customer_id);

CREATE INDEX idx_order_status
ON orders(status);

CREATE INDEX idx_order_created
ON orders(created_at);

------------------------------------------------------------
-- ORDER ITEM
------------------------------------------------------------

CREATE TABLE order_item
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id                  UUID NOT NULL,

    product_variant_id           UUID NOT NULL,

    recipe_version_id               UUID,

    quantity                          NUMERIC(10,2) NOT NULL DEFAULT 1,

    unit_price                          NUMERIC(18,2) NOT NULL,

    discount_amount                       NUMERIC(18,2) DEFAULT 0,

    ingredient_cost_amount                  NUMERIC(18,2) DEFAULT 0,

    total_price                               NUMERIC(18,2) NOT NULL,

    note                                         TEXT,

    created_at                                     TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_order_item_order
        FOREIGN KEY(order_id)
        REFERENCES orders(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_order_item_variant
        FOREIGN KEY(product_variant_id)
        REFERENCES product_variant(id),

    CONSTRAINT fk_order_item_recipe_version
        FOREIGN KEY(recipe_version_id)
        REFERENCES recipe_version(id)
);

CREATE INDEX idx_order_item_order
ON order_item(order_id);

CREATE INDEX idx_order_item_variant
ON order_item(product_variant_id);

------------------------------------------------------------
-- ORDER ITEM TOPPING
------------------------------------------------------------

CREATE TABLE order_item_topping
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_item_id             UUID NOT NULL,

    topping_id                   UUID NOT NULL,

    quantity                       INT NOT NULL DEFAULT 1,

    unit_price                       NUMERIC(18,2) DEFAULT 0,

    CONSTRAINT fk_order_item_topping_item
        FOREIGN KEY(order_item_id)
        REFERENCES order_item(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_order_item_topping_topping
        FOREIGN KEY(topping_id)
        REFERENCES topping(id)
);

CREATE INDEX idx_order_item_topping_item
ON order_item_topping(order_item_id);

------------------------------------------------------------
-- ORDER ITEM MODIFIER
------------------------------------------------------------

CREATE TABLE order_item_modifier
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_item_id             UUID NOT NULL,

    modifier_option_id           UUID NOT NULL,

    extra_price                    NUMERIC(18,2) DEFAULT 0,

    CONSTRAINT fk_order_item_modifier_item
        FOREIGN KEY(order_item_id)
        REFERENCES order_item(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_order_item_modifier_option
        FOREIGN KEY(modifier_option_id)
        REFERENCES modifier_option(id)
);

CREATE INDEX idx_order_item_modifier_item
ON order_item_modifier(order_item_id);

------------------------------------------------------------
-- ORDER TIMELINE (LỊCH SỬ TRẠNG THÁI ĐƠN HÀNG)
------------------------------------------------------------

CREATE TABLE order_timeline
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id                  UUID NOT NULL,

    from_status                  order_status,

    to_status                       order_status NOT NULL,

    action                            VARCHAR(100),

    note                                 TEXT,

    created_by                            UUID,

    created_at                              TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_order_timeline_order
        FOREIGN KEY(order_id)
        REFERENCES orders(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_order_timeline_user
        FOREIGN KEY(created_by)
        REFERENCES app_user(id)
);

CREATE INDEX idx_order_timeline_order
ON order_timeline(order_id);

------------------------------------------------------------
-- PAYMENT
------------------------------------------------------------

CREATE TABLE payment
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id                  UUID NOT NULL,

    amount                       NUMERIC(18,2) NOT NULL,

    payment_method                 payment_method NOT NULL,

    transaction_code                 VARCHAR(100),

    status                              payment_status DEFAULT 'PENDING',

    paid_at                               TIMESTAMPTZ,

    created_at                              TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_payment_order
        FOREIGN KEY(order_id)
        REFERENCES orders(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_payment_order
ON payment(order_id);

------------------------------------------------------------
-- FUNCTION: SINH MÃ ĐƠN HÀNG
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_generate_order_code()
RETURNS VARCHAR
LANGUAGE plpgsql
AS
$$
DECLARE

    v_code VARCHAR(50);

BEGIN

    v_code := 'ORD' || TO_CHAR(NOW(),'YYMMDD') || LPAD(NEXTVAL('seq_order_code')::TEXT,5,'0');

    RETURN v_code;

END;
$$;

------------------------------------------------------------
-- UPDATE TRIGGER
------------------------------------------------------------

CREATE TRIGGER trg_order_update
BEFORE UPDATE
ON orders
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();