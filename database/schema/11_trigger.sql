/*
===========================================================
Beverage Operating System
11_trigger.sql
Automation / Event-Driven Workflow

Triết lý: Order chỉ là sự kiện khởi đầu, các module khác
tự động phản ứng theo chuỗi:

Khách đặt hàng
    |
    v
Tạo Order
    |
    +-- Gửi thông báo cho Kitchen
    +-- Trừ tồn kho theo Recipe (FEFO)
    +-- Tính Cost snapshot cho từng Order Item
    +-- Ghi Timeline
    +-- Thông báo cho khách
    +-- Khi hoàn tất -> cập nhật điểm / hạng khách hàng
    +-- Khi tồn kho chạm ngưỡng -> cảnh báo nhập hàng
===========================================================
*/

------------------------------------------------------------
-- ENUM
------------------------------------------------------------

CREATE TYPE notification_type AS ENUM
(
    'ORDER',
    'DELIVERY',
    'INVENTORY',
    'SYSTEM',
    'PROMOTION'
);

CREATE TYPE notification_channel AS ENUM
(
    'PUSH',
    'SMS',
    'EMAIL',
    'ZALO',
    'IN_APP'
);

CREATE TYPE recipient_type AS ENUM
(
    'CUSTOMER',
    'STAFF'
);

------------------------------------------------------------
-- NOTIFICATION
------------------------------------------------------------

CREATE TABLE notification
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    notification_type          notification_type NOT NULL,

    channel                       notification_channel DEFAULT 'IN_APP',

    recipient_type                   recipient_type NOT NULL,

    recipient_id                       UUID,

    title                                 VARCHAR(255),

    message                                TEXT,

    reference_type                           VARCHAR(50),

    reference_id                               UUID,

    is_read                                      BOOLEAN DEFAULT FALSE,

    created_at                                     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notification_recipient
ON notification(recipient_type, recipient_id);

CREATE INDEX idx_notification_reference
ON notification(reference_type, reference_id);

CREATE INDEX idx_notification_unread
ON notification(is_read);

------------------------------------------------------------
-- TRIGGER FUNCTION 1
-- AFTER INSERT ON order_item
-- Recipe đọc -> Kho trừ (FEFO) -> Cost tính -> lưu snapshot
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_trg_order_item_consume_inventory()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
DECLARE

    v_warehouse_id UUID;

    v_recipe_version_id UUID;

    v_ingredient RECORD;

    v_shortage NUMERIC;

    v_total_cost NUMERIC := 0;

    v_created_by UUID;

BEGIN

    SELECT warehouse_id, created_by INTO v_warehouse_id, v_created_by
    FROM orders
    WHERE id = NEW.order_id;

    -- Lấy recipe_version đang hiệu lực (is_current) của biến thể sản phẩm
    SELECT rv.id INTO v_recipe_version_id
    FROM recipe r
    JOIN recipe_version rv ON rv.recipe_id = r.id AND rv.is_current = TRUE
    WHERE r.product_variant_id = NEW.product_variant_id
    LIMIT 1;

    IF v_recipe_version_id IS NULL THEN
        -- Sản phẩm không có công thức (VD: topping bán rời) -> bỏ qua trừ kho
        RETURN NEW;
    END IF;

    UPDATE order_item
    SET recipe_version_id = v_recipe_version_id
    WHERE id = NEW.id;

    FOR v_ingredient IN
        SELECT ingredient_id, quantity
        FROM recipe_ingredient
        WHERE recipe_version_id = v_recipe_version_id
    LOOP

        v_shortage := fn_consume_ingredient
        (
            v_ingredient.ingredient_id,
            v_warehouse_id,
            v_ingredient.quantity * NEW.quantity,
            'ORDER_ITEM',
            NEW.id,
            v_created_by
        );

        IF v_shortage > 0 THEN
            INSERT INTO notification
            (
                notification_type, channel, recipient_type, recipient_id,
                title, message, reference_type, reference_id
            )
            VALUES
            (
                'INVENTORY', 'IN_APP', 'STAFF', NULL,
                'Thiếu nguyên liệu',
                'Nguyên liệu ' || v_ingredient.ingredient_id || ' thiếu ' || v_shortage || ' khi pha chế đơn hàng',
                'ORDER_ITEM', NEW.id
            );
        END IF;

        v_total_cost := v_total_cost + (v_ingredient.quantity * NEW.quantity) *
        (
            SELECT unit_price
            FROM ingredient_price_history
            WHERE ingredient_id = v_ingredient.ingredient_id
            ORDER BY effective_from DESC
            LIMIT 1
        );

    END LOOP;

    UPDATE order_item
    SET ingredient_cost_amount = COALESCE(v_total_cost,0)
    WHERE id = NEW.id;

    RETURN NEW;

END;
$$;

CREATE TRIGGER trg_order_item_after_insert
AFTER INSERT
ON order_item
FOR EACH ROW
EXECUTE FUNCTION fn_trg_order_item_consume_inventory();

------------------------------------------------------------
-- TRIGGER FUNCTION 2
-- AFTER UPDATE OF status ON orders
-- Ghi Timeline -> thông báo khách/kitchen/delivery -> cập
-- nhật điểm khách hàng khi hoàn tất
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_trg_order_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
BEGIN

    IF NEW.status IS DISTINCT FROM OLD.status THEN

        INSERT INTO order_timeline(order_id, from_status, to_status, action, created_by)
        VALUES(NEW.id, OLD.status, NEW.status, 'STATUS_CHANGE', NEW.created_by);

        IF NEW.status = 'CONFIRMED' THEN
            NEW.confirmed_at := NOW();
        ELSIF NEW.status = 'COMPLETED' THEN
            NEW.completed_at := NOW();
        ELSIF NEW.status = 'CANCELLED' THEN
            NEW.cancelled_at := NOW();
        END IF;

        IF NEW.customer_id IS NOT NULL THEN
            INSERT INTO notification
            (
                notification_type, channel, recipient_type, recipient_id,
                title, message, reference_type, reference_id
            )
            VALUES
            (
                'ORDER', 'PUSH', 'CUSTOMER', NEW.customer_id,
                'Cập nhật đơn hàng ' || NEW.order_code,
                'Đơn hàng của bạn hiện đang: ' || NEW.status,
                'ORDER', NEW.id
            );
        END IF;

        IF NEW.status = 'COMPLETED' AND NEW.customer_id IS NOT NULL THEN

            UPDATE customer
            SET total_order = total_order + 1,
                total_spent = total_spent + NEW.total_amount,
                loyalty_point = loyalty_point + FLOOR(NEW.total_amount / 10000)
            WHERE id = NEW.customer_id;

            INSERT INTO customer_point_history(customer_id, point, description)
            VALUES(NEW.customer_id, FLOOR(NEW.total_amount / 10000), 'Tích điểm từ đơn hàng ' || NEW.order_code);

        END IF;

    END IF;

    RETURN NEW;

END;
$$;

CREATE TRIGGER trg_order_status_change
BEFORE UPDATE
ON orders
FOR EACH ROW
EXECUTE FUNCTION fn_trg_order_status_change();

------------------------------------------------------------
-- TRIGGER FUNCTION 3
-- AFTER INSERT ON ingredient_price_history
-- Giá nguyên liệu thay đổi -> tự tính lại Cost cho toàn bộ
-- recipe_version đang active dùng nguyên liệu đó
-- (Single Source of Truth cho Cost Engine)
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_trg_ingredient_price_recalculate()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
DECLARE

    v_recipe_version RECORD;

    v_new_cost NUMERIC;

BEGIN

    FOR v_recipe_version IN
        SELECT DISTINCT rv.id
        FROM recipe_version rv
        JOIN recipe_ingredient ri ON ri.recipe_version_id = rv.id
        WHERE ri.ingredient_id = NEW.ingredient_id
          AND rv.is_current = TRUE
    LOOP

        v_new_cost := fn_calculate_recipe_cost(v_recipe_version.id);

        INSERT INTO recipe_cost(recipe_version_id, ingredient_cost, total_cost)
        VALUES(v_recipe_version.id, v_new_cost, v_new_cost)
        ON CONFLICT(recipe_version_id)
        DO UPDATE
        SET
            ingredient_cost = EXCLUDED.ingredient_cost,
            total_cost = recipe_cost.packaging_cost + recipe_cost.labor_cost + recipe_cost.overhead_cost + EXCLUDED.ingredient_cost,
            calculated_at = NOW();

    END LOOP;

    RETURN NEW;

END;
$$;

CREATE TRIGGER trg_ingredient_price_recalculate
AFTER INSERT
ON ingredient_price_history
FOR EACH ROW
EXECUTE FUNCTION fn_trg_ingredient_price_recalculate();

------------------------------------------------------------
-- TRIGGER FUNCTION 4
-- AFTER UPDATE ON inventory_stock
-- Tồn kho chạm ngưỡng tối thiểu -> cảnh báo nhập hàng
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_trg_low_stock_alert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
DECLARE

    v_min_stock NUMERIC;

    v_ingredient_name VARCHAR;

BEGIN

    SELECT minimum_stock, ingredient_name
    INTO v_min_stock, v_ingredient_name
    FROM ingredient
    WHERE id = NEW.ingredient_id;

    IF NEW.quantity_on_hand <= v_min_stock THEN

        INSERT INTO notification
        (
            notification_type, channel, recipient_type, recipient_id,
            title, message, reference_type, reference_id
        )
        VALUES
        (
            'INVENTORY', 'IN_APP', 'STAFF', NULL,
            'Sắp hết nguyên liệu: ' || v_ingredient_name,
            'Tồn kho hiện tại: ' || NEW.quantity_on_hand || ' (định mức tối thiểu: ' || v_min_stock || ')',
            'INGREDIENT', NEW.ingredient_id
        );

    END IF;

    RETURN NEW;

END;
$$;

CREATE TRIGGER trg_inventory_low_stock
AFTER UPDATE
ON inventory_stock
FOR EACH ROW
EXECUTE FUNCTION fn_trg_low_stock_alert();

------------------------------------------------------------
-- TRIGGER FUNCTION 5
-- AFTER UPDATE OF status ON delivery
-- Đồng bộ trạng thái Đơn hàng khi Delivery hoàn tất/thất bại
-- + thông báo khách hàng
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_trg_delivery_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
DECLARE

    v_customer_id UUID;

    v_order_code VARCHAR;

BEGIN

    IF NEW.status IS DISTINCT FROM OLD.status THEN

        CASE NEW.status
            WHEN 'ASSIGNED' THEN NEW.assigned_at := NOW();
            WHEN 'PICKED_UP' THEN NEW.picked_up_at := NOW();
            WHEN 'DELIVERING' THEN NEW.delivering_at := NOW();
            WHEN 'DELIVERED' THEN NEW.delivered_at := NOW();
            ELSE NULL;
        END CASE;

        SELECT customer_id, order_code INTO v_customer_id, v_order_code
        FROM orders
        WHERE id = NEW.order_id;

        IF v_customer_id IS NOT NULL THEN
            INSERT INTO notification
            (
                notification_type, channel, recipient_type, recipient_id,
                title, message, reference_type, reference_id
            )
            VALUES
            (
                'DELIVERY', 'PUSH', 'CUSTOMER', v_customer_id,
                'Cập nhật giao hàng ' || v_order_code,
                'Trạng thái giao hàng: ' || NEW.status,
                'DELIVERY', NEW.id
            );
        END IF;

        IF NEW.status = 'DELIVERED' THEN
            UPDATE orders SET status = 'COMPLETED' WHERE id = NEW.order_id AND status <> 'COMPLETED';
        END IF;

    END IF;

    RETURN NEW;

END;
$$;

CREATE TRIGGER trg_delivery_status_change
BEFORE UPDATE
ON delivery
FOR EACH ROW
EXECUTE FUNCTION fn_trg_delivery_status_change();