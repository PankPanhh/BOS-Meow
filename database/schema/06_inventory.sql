/*
===========================================================
Beverage Operating System
06_inventory.sql
Inventory Management (Warehouse / Batch - FEFO / Stock Ledger)
===========================================================
*/

------------------------------------------------------------
-- ENUM
------------------------------------------------------------

CREATE TYPE movement_type AS ENUM
(
    'IMPORT',
    'EXPORT',
    'ADJUST_INCREASE',
    'ADJUST_DECREASE',
    'TRANSFER_IN',
    'TRANSFER_OUT',
    'WASTE',
    'ORDER_CONSUME',
    'ORDER_RETURN'
);

CREATE TYPE adjustment_type AS ENUM
(
    'INCREASE',
    'DECREASE'
);

CREATE TYPE transfer_status AS ENUM
(
    'DRAFT',
    'IN_TRANSIT',
    'COMPLETED',
    'CANCELLED'
);

------------------------------------------------------------
-- WAREHOUSE
------------------------------------------------------------

CREATE TABLE warehouse
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    warehouse_code           VARCHAR(50) UNIQUE NOT NULL,

    warehouse_name           VARCHAR(255) NOT NULL,

    address                  TEXT,

    is_default                BOOLEAN DEFAULT FALSE,

    is_active                 BOOLEAN DEFAULT TRUE,

    created_at                TIMESTAMPTZ DEFAULT NOW(),

    updated_at                TIMESTAMPTZ DEFAULT NOW(),

    version                   INT DEFAULT 1
);

CREATE INDEX idx_warehouse_code
ON warehouse(warehouse_code);

------------------------------------------------------------
-- INVENTORY BATCH
-- Nguyên liệu không lưu theo tổng số lượng mà lưu theo lô nhập
-- (ngày nhập / HSD / giá nhập) để tính giá vốn và FEFO chính xác
------------------------------------------------------------

CREATE TABLE inventory_batch
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    ingredient_id            UUID NOT NULL,

    warehouse_id              UUID NOT NULL,

    batch_code                 VARCHAR(50) UNIQUE NOT NULL,

    supplier_id                 UUID,

    purchase_item_id            UUID,

    quantity                     NUMERIC(18,4) NOT NULL,

    remain_quantity               NUMERIC(18,4) NOT NULL,

    import_price                   NUMERIC(18,4) NOT NULL DEFAULT 0,

    imported_at                     TIMESTAMPTZ DEFAULT NOW(),

    expired_at                       TIMESTAMPTZ,

    note                               TEXT,

    created_at                          TIMESTAMPTZ DEFAULT NOW(),

    updated_at                           TIMESTAMPTZ DEFAULT NOW(),

    version                               INT DEFAULT 1,

    CONSTRAINT fk_inventory_batch_ingredient
        FOREIGN KEY(ingredient_id)
        REFERENCES ingredient(id),

    CONSTRAINT fk_inventory_batch_warehouse
        FOREIGN KEY(warehouse_id)
        REFERENCES warehouse(id),

    CONSTRAINT ck_inventory_batch_remain
        CHECK(remain_quantity >= 0 AND remain_quantity <= quantity)
);

-- supplier_id / purchase_item_id được ràng buộc FK ở 07_purchase.sql
-- (supplier & purchase_item chưa tồn tại tại thời điểm chạy file này)

CREATE INDEX idx_inventory_batch_ingredient
ON inventory_batch(ingredient_id);

CREATE INDEX idx_inventory_batch_warehouse
ON inventory_batch(warehouse_id);

CREATE INDEX idx_inventory_batch_expired
ON inventory_batch(expired_at);

CREATE INDEX idx_inventory_batch_remain
ON inventory_batch(remain_quantity);

------------------------------------------------------------
-- INVENTORY STOCK
-- Bảng tổng hợp tồn kho hiện tại theo nguyên liệu / kho
-- (cache tổng hợp từ inventory_batch, phục vụ đọc nhanh
-- cho Dashboard, Recipe availability, Order checkout)
------------------------------------------------------------

CREATE TABLE inventory_stock
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    ingredient_id            UUID NOT NULL,

    warehouse_id               UUID NOT NULL,

    quantity_on_hand             NUMERIC(18,4) NOT NULL DEFAULT 0,

    reserved_quantity              NUMERIC(18,4) NOT NULL DEFAULT 0,

    updated_at                       TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_inventory_stock_ingredient
        FOREIGN KEY(ingredient_id)
        REFERENCES ingredient(id),

    CONSTRAINT fk_inventory_stock_warehouse
        FOREIGN KEY(warehouse_id)
        REFERENCES warehouse(id),

    CONSTRAINT uq_inventory_stock
        UNIQUE(ingredient_id, warehouse_id)
);

CREATE INDEX idx_inventory_stock_ingredient
ON inventory_stock(ingredient_id);

CREATE INDEX idx_inventory_stock_warehouse
ON inventory_stock(warehouse_id);

------------------------------------------------------------
-- STOCK MOVEMENT (SỔ CÁI KHO / LEDGER)
-- Mọi biến động kho đều phải đi qua bảng này -> Single Source
-- of Truth cho toàn bộ Cost Engine & Report
------------------------------------------------------------

CREATE TABLE stock_movement
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    ingredient_id            UUID NOT NULL,

    warehouse_id               UUID NOT NULL,

    batch_id                     UUID,

    movement_type                  movement_type NOT NULL,

    quantity                         NUMERIC(18,4) NOT NULL,

    unit_cost                          NUMERIC(18,4) DEFAULT 0,

    reference_type                       VARCHAR(50),

    reference_id                           UUID,

    note                                     TEXT,

    created_by                                UUID,

    created_at                                 TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_stock_movement_ingredient
        FOREIGN KEY(ingredient_id)
        REFERENCES ingredient(id),

    CONSTRAINT fk_stock_movement_warehouse
        FOREIGN KEY(warehouse_id)
        REFERENCES warehouse(id),

    CONSTRAINT fk_stock_movement_batch
        FOREIGN KEY(batch_id)
        REFERENCES inventory_batch(id),

    CONSTRAINT fk_stock_movement_user
        FOREIGN KEY(created_by)
        REFERENCES app_user(id)
);

CREATE INDEX idx_stock_movement_ingredient
ON stock_movement(ingredient_id);

CREATE INDEX idx_stock_movement_warehouse
ON stock_movement(warehouse_id);

CREATE INDEX idx_stock_movement_reference
ON stock_movement(reference_type, reference_id);

CREATE INDEX idx_stock_movement_created
ON stock_movement(created_at);

------------------------------------------------------------
-- STOCK ADJUSTMENT (KIỂM KHO / ĐIỀU CHỈNH THỦ CÔNG)
------------------------------------------------------------

CREATE TABLE stock_adjustment
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    ingredient_id            UUID NOT NULL,

    warehouse_id               UUID NOT NULL,

    adjustment_type              adjustment_type NOT NULL,

    quantity                       NUMERIC(18,4) NOT NULL,

    reason                            TEXT,

    created_by                         UUID,

    created_at                           TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_stock_adjustment_ingredient
        FOREIGN KEY(ingredient_id)
        REFERENCES ingredient(id),

    CONSTRAINT fk_stock_adjustment_warehouse
        FOREIGN KEY(warehouse_id)
        REFERENCES warehouse(id),

    CONSTRAINT fk_stock_adjustment_user
        FOREIGN KEY(created_by)
        REFERENCES app_user(id)
);

CREATE INDEX idx_stock_adjustment_ingredient
ON stock_adjustment(ingredient_id);

------------------------------------------------------------
-- STOCK TRANSFER (CHUYỂN KHO GIỮA CHI NHÁNH - SCALE READY)
------------------------------------------------------------

CREATE TABLE stock_transfer
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    transfer_code            VARCHAR(50) UNIQUE NOT NULL,

    from_warehouse_id          UUID NOT NULL,

    to_warehouse_id               UUID NOT NULL,

    status                           transfer_status DEFAULT 'DRAFT',

    note                                TEXT,

    created_by                           UUID,

    created_at                             TIMESTAMPTZ DEFAULT NOW(),

    completed_at                             TIMESTAMPTZ,

    version                                    INT DEFAULT 1,

    CONSTRAINT fk_stock_transfer_from
        FOREIGN KEY(from_warehouse_id)
        REFERENCES warehouse(id),

    CONSTRAINT fk_stock_transfer_to
        FOREIGN KEY(to_warehouse_id)
        REFERENCES warehouse(id),

    CONSTRAINT fk_stock_transfer_user
        FOREIGN KEY(created_by)
        REFERENCES app_user(id),

    CONSTRAINT ck_stock_transfer_diff
        CHECK(from_warehouse_id <> to_warehouse_id)
);

CREATE TABLE stock_transfer_item
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    transfer_id              UUID NOT NULL,

    ingredient_id              UUID NOT NULL,

    quantity                     NUMERIC(18,4) NOT NULL,

    CONSTRAINT fk_transfer_item_transfer
        FOREIGN KEY(transfer_id)
        REFERENCES stock_transfer(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_transfer_item_ingredient
        FOREIGN KEY(ingredient_id)
        REFERENCES ingredient(id)
);

CREATE INDEX idx_transfer_item_transfer
ON stock_transfer_item(transfer_id);

------------------------------------------------------------
-- FUNCTION: UPSERT INVENTORY STOCK
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_upsert_inventory_stock
(
    p_ingredient_id UUID,
    p_warehouse_id UUID,
    p_delta_quantity NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
AS
$$
BEGIN

    INSERT INTO inventory_stock(ingredient_id, warehouse_id, quantity_on_hand, updated_at)
    VALUES(p_ingredient_id, p_warehouse_id, p_delta_quantity, NOW())
    ON CONFLICT(ingredient_id, warehouse_id)
    DO UPDATE
    SET
        quantity_on_hand = inventory_stock.quantity_on_hand + p_delta_quantity,
        updated_at = NOW();

END;
$$;

------------------------------------------------------------
-- FUNCTION: IMPORT STOCK (tạo lô hàng mới + ghi ledger)
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_import_stock
(
    p_ingredient_id UUID,
    p_warehouse_id UUID,
    p_quantity NUMERIC,
    p_import_price NUMERIC,
    p_expired_at TIMESTAMPTZ,
    p_supplier_id UUID,
    p_purchase_item_id UUID,
    p_created_by UUID
)
RETURNS UUID
LANGUAGE plpgsql
AS
$$
DECLARE

    v_batch_id UUID;

    v_batch_code VARCHAR(50);

BEGIN

    v_batch_code := 'BATCH-' || TO_CHAR(NOW(),'YYYYMMDDHH24MISS') || '-' || SUBSTRING(gen_random_uuid()::TEXT,1,4);

    INSERT INTO inventory_batch
    (
        ingredient_id, warehouse_id, batch_code, supplier_id,
        purchase_item_id, quantity, remain_quantity, import_price,
        expired_at
    )
    VALUES
    (
        p_ingredient_id, p_warehouse_id, v_batch_code, p_supplier_id,
        p_purchase_item_id, p_quantity, p_quantity, p_import_price,
        p_expired_at
    )
    RETURNING id INTO v_batch_id;

    INSERT INTO stock_movement
    (
        ingredient_id, warehouse_id, batch_id, movement_type,
        quantity, unit_cost, reference_type, reference_id, created_by
    )
    VALUES
    (
        p_ingredient_id, p_warehouse_id, v_batch_id, 'IMPORT',
        p_quantity, p_import_price, 'PURCHASE_ITEM', p_purchase_item_id, p_created_by
    );

    PERFORM fn_upsert_inventory_stock(p_ingredient_id, p_warehouse_id, p_quantity);

    -- cập nhật giá nhập mới nhất vào bảng giá nguyên liệu (single source of truth cho Cost Engine)
    INSERT INTO ingredient_price_history(ingredient_id, supplier_id, unit_price, note)
    VALUES(p_ingredient_id, p_supplier_id, p_import_price, 'Auto từ phiếu nhập kho');

    RETURN v_batch_id;

END;
$$;

------------------------------------------------------------
-- FUNCTION: CONSUME INGREDIENT (FEFO - First Expired First Out)
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_consume_ingredient
(
    p_ingredient_id UUID,
    p_warehouse_id UUID,
    p_quantity NUMERIC,
    p_reference_type VARCHAR,
    p_reference_id UUID,
    p_created_by UUID
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS
$$
DECLARE

    v_batch RECORD;

    v_remaining_to_consume NUMERIC := p_quantity;

    v_take NUMERIC;

    v_shortage NUMERIC := 0;

BEGIN

    FOR v_batch IN
        SELECT id, remain_quantity, import_price
        FROM inventory_batch
        WHERE ingredient_id = p_ingredient_id
          AND warehouse_id = p_warehouse_id
          AND remain_quantity > 0
        ORDER BY expired_at ASC NULLS LAST, imported_at ASC
        FOR UPDATE
    LOOP

        EXIT WHEN v_remaining_to_consume <= 0;

        v_take := LEAST(v_batch.remain_quantity, v_remaining_to_consume);

        UPDATE inventory_batch
        SET remain_quantity = remain_quantity - v_take,
            updated_at = NOW()
        WHERE id = v_batch.id;

        INSERT INTO stock_movement
        (
            ingredient_id, warehouse_id, batch_id, movement_type,
            quantity, unit_cost, reference_type, reference_id, created_by
        )
        VALUES
        (
            p_ingredient_id, p_warehouse_id, v_batch.id, 'ORDER_CONSUME',
            v_take, v_batch.import_price, p_reference_type, p_reference_id, p_created_by
        );

        v_remaining_to_consume := v_remaining_to_consume - v_take;

    END LOOP;

    IF v_remaining_to_consume > 0 THEN
        v_shortage := v_remaining_to_consume;
    END IF;

    PERFORM fn_upsert_inventory_stock(p_ingredient_id, p_warehouse_id, -(p_quantity - v_shortage));

    RETURN v_shortage;

END;
$$;

------------------------------------------------------------
-- UPDATE TRIGGER
------------------------------------------------------------

CREATE TRIGGER trg_warehouse_update
BEFORE UPDATE
ON warehouse
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_inventory_batch_update
BEFORE UPDATE
ON inventory_batch
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_stock_transfer_update
BEFORE UPDATE
ON stock_transfer
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();