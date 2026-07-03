/*
===========================================================
Beverage Operating System
07_purchase.sql
Supplier & Purchase Order (Nhập kho)
===========================================================
*/

------------------------------------------------------------
-- ENUM
------------------------------------------------------------

CREATE TYPE purchase_status AS ENUM
(
    'DRAFT',
    'SUBMITTED',
    'APPROVED',
    'PARTIAL_RECEIVED',
    'RECEIVED',
    'CANCELLED'
);

------------------------------------------------------------
-- SUPPLIER
------------------------------------------------------------

CREATE TABLE supplier
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    supplier_code            VARCHAR(50) UNIQUE NOT NULL,

    supplier_name              VARCHAR(255) NOT NULL,

    phone                         VARCHAR(20),

    email                           CITEXT,

    address                           TEXT,

    tax_code                           VARCHAR(50),

    payment_term_day                     INT DEFAULT 0,

    note                                    TEXT,

    is_active                                BOOLEAN DEFAULT TRUE,

    created_at                                 TIMESTAMPTZ DEFAULT NOW(),

    updated_at                                   TIMESTAMPTZ DEFAULT NOW(),

    deleted_at                                     TIMESTAMPTZ,

    version                                          INT DEFAULT 1
);

CREATE INDEX idx_supplier_name
ON supplier(supplier_name);

CREATE INDEX idx_supplier_phone
ON supplier(phone);

-- Ràng buộc FK còn thiếu ở inventory_batch (06_inventory.sql) do supplier
-- chưa tồn tại tại thời điểm đó, nay bổ sung:

ALTER TABLE inventory_batch
ADD CONSTRAINT fk_inventory_batch_supplier
    FOREIGN KEY(supplier_id)
    REFERENCES supplier(id);

------------------------------------------------------------
-- PURCHASE ORDER (PHIẾU ĐẶT HÀNG NHÀ CUNG CẤP)
------------------------------------------------------------

CREATE TABLE purchase_order
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    po_code                   VARCHAR(50) UNIQUE NOT NULL,

    supplier_id                 UUID NOT NULL,

    warehouse_id                   UUID NOT NULL,

    status                            purchase_status DEFAULT 'DRAFT',

    payment_status                      payment_status DEFAULT 'UNPAID',

    order_date                            DATE DEFAULT CURRENT_DATE,

    expected_date                           DATE,

    subtotal_amount                           NUMERIC(18,2) DEFAULT 0,

    total_amount                                NUMERIC(18,2) DEFAULT 0,

    note                                          TEXT,

    created_by                                      UUID,

    created_at                                        TIMESTAMPTZ DEFAULT NOW(),

    updated_at                                          TIMESTAMPTZ DEFAULT NOW(),

    version                                               INT DEFAULT 1,

    CONSTRAINT fk_purchase_order_supplier
        FOREIGN KEY(supplier_id)
        REFERENCES supplier(id),

    CONSTRAINT fk_purchase_order_warehouse
        FOREIGN KEY(warehouse_id)
        REFERENCES warehouse(id),

    CONSTRAINT fk_purchase_order_user
        FOREIGN KEY(created_by)
        REFERENCES app_user(id)
);

CREATE INDEX idx_purchase_order_supplier
ON purchase_order(supplier_id);

CREATE INDEX idx_purchase_order_status
ON purchase_order(status);

CREATE INDEX idx_purchase_order_code
ON purchase_order(po_code);

------------------------------------------------------------
-- PURCHASE ITEM
------------------------------------------------------------

CREATE TABLE purchase_item
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    purchase_order_id         UUID NOT NULL,

    ingredient_id                UUID NOT NULL,

    quantity                       NUMERIC(18,4) NOT NULL,

    unit_price                       NUMERIC(18,4) NOT NULL DEFAULT 0,

    received_quantity                  NUMERIC(18,4) NOT NULL DEFAULT 0,

    total_price                          NUMERIC(18,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,

    CONSTRAINT fk_purchase_item_order
        FOREIGN KEY(purchase_order_id)
        REFERENCES purchase_order(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_purchase_item_ingredient
        FOREIGN KEY(ingredient_id)
        REFERENCES ingredient(id)
);

CREATE INDEX idx_purchase_item_order
ON purchase_item(purchase_order_id);

-- Ràng buộc FK còn thiếu ở inventory_batch (06_inventory.sql):

ALTER TABLE inventory_batch
ADD CONSTRAINT fk_inventory_batch_purchase_item
    FOREIGN KEY(purchase_item_id)
    REFERENCES purchase_item(id);

------------------------------------------------------------
-- PURCHASE PAYMENT
------------------------------------------------------------

CREATE TABLE purchase_payment
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    purchase_order_id         UUID NOT NULL,

    amount                       NUMERIC(18,2) NOT NULL,

    payment_method                 payment_method,

    paid_at                          TIMESTAMPTZ DEFAULT NOW(),

    note                               TEXT,

    created_by                          UUID,

    created_at                            TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_purchase_payment_order
        FOREIGN KEY(purchase_order_id)
        REFERENCES purchase_order(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_purchase_payment_user
        FOREIGN KEY(created_by)
        REFERENCES app_user(id)
);

CREATE INDEX idx_purchase_payment_order
ON purchase_payment(purchase_order_id);

------------------------------------------------------------
-- FUNCTION: NHẬN HÀNG (RECEIVE) - SINH LÔ HÀNG + GHI SỔ KHO
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_receive_purchase_item
(
    p_purchase_item_id UUID,
    p_receive_quantity NUMERIC,
    p_expired_at TIMESTAMPTZ,
    p_created_by UUID
)
RETURNS UUID
LANGUAGE plpgsql
AS
$$
DECLARE

    v_item RECORD;

    v_order RECORD;

    v_batch_id UUID;

    v_total_ordered NUMERIC;

    v_total_received NUMERIC;

BEGIN

    SELECT * INTO v_item
    FROM purchase_item
    WHERE id = p_purchase_item_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'purchase_item % not found', p_purchase_item_id;
    END IF;

    SELECT * INTO v_order
    FROM purchase_order
    WHERE id = v_item.purchase_order_id
    FOR UPDATE;

    v_batch_id := fn_import_stock
    (
        v_item.ingredient_id,
        v_order.warehouse_id,
        p_receive_quantity,
        v_item.unit_price,
        p_expired_at,
        v_order.supplier_id,
        p_purchase_item_id,
        p_created_by
    );

    UPDATE purchase_item
    SET received_quantity = received_quantity + p_receive_quantity
    WHERE id = p_purchase_item_id;

    SELECT SUM(quantity), SUM(received_quantity)
    INTO v_total_ordered, v_total_received
    FROM purchase_item
    WHERE purchase_order_id = v_item.purchase_order_id;

    UPDATE purchase_order
    SET status = CASE
                    WHEN v_total_received >= v_total_ordered THEN 'RECEIVED'
                    WHEN v_total_received > 0 THEN 'PARTIAL_RECEIVED'
                    ELSE status
                 END,
        total_amount = (SELECT COALESCE(SUM(total_price),0) FROM purchase_item WHERE purchase_order_id = v_item.purchase_order_id)
    WHERE id = v_item.purchase_order_id;

    RETURN v_batch_id;

END;
$$;

------------------------------------------------------------
-- UPDATE TRIGGER
------------------------------------------------------------

CREATE TRIGGER trg_supplier_update
BEFORE UPDATE
ON supplier
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_purchase_order_update
BEFORE UPDATE
ON purchase_order
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();