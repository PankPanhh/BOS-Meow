/*
===========================================================
Beverage Operating System
14_promotion.sql
Voucher / Promotion (mảnh còn thiếu của CRM theo ý_tưởng.txt:
"Khách hàng. Lịch sử. Voucher. Điểm.")

Phạm vi MVP - cố tình giữ gọn:
 - 1 voucher áp dụng ở cấp ĐƠN HÀNG (không áp theo từng item)
 - Không làm hệ thống rule engine phức tạp nhiều tầng, dùng
   JSONB cho promotion để linh hoạt mà không sinh thêm chục bảng
 - Tận dụng lại customer.loyalty_point đã có sẵn từ 11_trigger.sql,
   KHÔNG tạo thêm hệ thống hạng thành viên (tier) vì chưa có yêu
   cầu cụ thể - tránh over-engineering

Không đụng tới bảng đã có (orders, order_item...) bằng ALTER,
mà tạo bảng liên kết order_voucher riêng -> an toàn, không phá
vỡ 08_order.sql.
===========================================================
*/

------------------------------------------------------------
-- ENUM
------------------------------------------------------------

CREATE TYPE voucher_type AS ENUM
(
    'PERCENT',
    'FIXED_AMOUNT',
    'FREE_SHIPPING'
);

CREATE TYPE voucher_status AS ENUM
(
    'ACTIVE',
    'INACTIVE',
    'EXPIRED'
);

CREATE TYPE promotion_type AS ENUM
(
    'BUY_X_GET_Y',
    'COMBO_DISCOUNT',
    'HAPPY_HOUR',
    'FLASH_SALE'
);

------------------------------------------------------------
-- VOUCHER
------------------------------------------------------------

CREATE TABLE voucher
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    voucher_code              VARCHAR(50) NOT NULL,

    voucher_name                 VARCHAR(255) NOT NULL,

    description                     TEXT,

    voucher_type                      voucher_type NOT NULL,

    discount_percent                     NUMERIC(5,2),

    discount_amount                        NUMERIC(18,2),

    max_discount_amount                       NUMERIC(18,2),

    min_order_amount                            NUMERIC(18,2) DEFAULT 0,

    usage_limit_total                             INT,

    usage_limit_per_customer                        INT DEFAULT 1,

    used_count                                        INT DEFAULT 0,

    start_date                                          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    end_date                                              TIMESTAMPTZ,

    status                                                  voucher_status DEFAULT 'ACTIVE',

    created_by                                                UUID,

    created_at                                                  TIMESTAMPTZ DEFAULT NOW(),

    updated_at                                                    TIMESTAMPTZ DEFAULT NOW(),

    deleted_at                                                      TIMESTAMPTZ,

    version                                                           INT DEFAULT 1,

    CONSTRAINT fk_voucher_user
        FOREIGN KEY(created_by)
        REFERENCES app_user(id),

    CONSTRAINT chk_voucher_percent
        CHECK(voucher_type <> 'PERCENT' OR (discount_percent > 0 AND discount_percent <= 100)),

    CONSTRAINT chk_voucher_fixed
        CHECK(voucher_type <> 'FIXED_AMOUNT' OR discount_amount > 0),

    CONSTRAINT chk_voucher_min_order
        CHECK(min_order_amount >= 0),

    CONSTRAINT chk_voucher_usage_limit
        CHECK(usage_limit_total IS NULL OR usage_limit_total > 0),

    CONSTRAINT chk_voucher_date_range
        CHECK(end_date IS NULL OR end_date > start_date)
);

-- Mã voucher chỉ cần UNIQUE trong số các voucher còn sống, để
-- có thể tái sử dụng mã cũ sau khi voucher hết hạn bị xoá mềm
-- (cùng cách tiếp cận như 15_hotfix.sql xử lý cho product/customer)

CREATE UNIQUE INDEX uq_voucher_code_active
ON voucher(voucher_code)
WHERE deleted_at IS NULL;

CREATE INDEX idx_voucher_status
ON voucher(status);

CREATE INDEX idx_voucher_date_range
ON voucher(start_date, end_date);

------------------------------------------------------------
-- VOUCHER SCOPE (tuỳ chọn giới hạn theo sản phẩm/danh mục)
-- Không có dòng nào -> áp dụng cho toàn bộ menu
------------------------------------------------------------

CREATE TABLE voucher_product
(
    voucher_id          UUID,

    product_id           UUID,

    PRIMARY KEY(voucher_id, product_id),

    CONSTRAINT fk_voucher_product_voucher
        FOREIGN KEY(voucher_id)
        REFERENCES voucher(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_voucher_product_product
        FOREIGN KEY(product_id)
        REFERENCES product(id)
        ON DELETE CASCADE
);

CREATE TABLE voucher_category
(
    voucher_id          UUID,

    category_id           UUID,

    PRIMARY KEY(voucher_id, category_id),

    CONSTRAINT fk_voucher_category_voucher
        FOREIGN KEY(voucher_id)
        REFERENCES voucher(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_voucher_category_category
        FOREIGN KEY(category_id)
        REFERENCES product_category(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- CUSTOMER VOUCHER (VOUCHER PHÁT RIÊNG CHO 1 KHÁCH - VD SINH NHẬT)
------------------------------------------------------------

CREATE TABLE customer_voucher
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_id               UUID NOT NULL,

    voucher_id                   UUID NOT NULL,

    assigned_at                     TIMESTAMPTZ DEFAULT NOW(),

    is_used                            BOOLEAN DEFAULT FALSE,

    used_at                               TIMESTAMPTZ,

    CONSTRAINT fk_customer_voucher_customer
        FOREIGN KEY(customer_id)
        REFERENCES customer(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_customer_voucher_voucher
        FOREIGN KEY(voucher_id)
        REFERENCES voucher(id)
        ON DELETE CASCADE,

    CONSTRAINT uq_customer_voucher
        UNIQUE(customer_id, voucher_id)
);

CREATE INDEX idx_customer_voucher_customer
ON customer_voucher(customer_id);

------------------------------------------------------------
-- ORDER VOUCHER (VOUCHER ĐÃ ÁP DỤNG CHO 1 ĐƠN HÀNG CỤ THỂ)
------------------------------------------------------------

CREATE TABLE order_voucher
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id                  UUID NOT NULL,

    voucher_id                   UUID NOT NULL,

    discount_amount                 NUMERIC(18,2) NOT NULL,

    created_at                        TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_order_voucher_order
        FOREIGN KEY(order_id)
        REFERENCES orders(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_order_voucher_voucher
        FOREIGN KEY(voucher_id)
        REFERENCES voucher(id),

    CONSTRAINT uq_order_voucher
        UNIQUE(order_id, voucher_id)
);

CREATE INDEX idx_order_voucher_order
ON order_voucher(order_id);

CREATE INDEX idx_order_voucher_voucher
ON order_voucher(voucher_id);

------------------------------------------------------------
-- PROMOTION (CHIẾN DỊCH LINH HOẠT - HAPPY HOUR / FLASH SALE...)
-- Dùng JSONB cho điều kiện để không phải sinh thêm nhiều bảng
-- con cho từng loại khuyến mãi ở giai đoạn MVP. Khi nghiệp vụ
-- rõ ràng và ổn định hơn, có thể tách JSONB này ra bảng riêng.
------------------------------------------------------------

CREATE TABLE promotion
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    promotion_code            VARCHAR(50) NOT NULL,

    promotion_name               VARCHAR(255) NOT NULL,

    promotion_type                  promotion_type NOT NULL,

    description                        TEXT,

    conditions                           JSONB,

    start_date                             TIMESTAMPTZ NOT NULL,

    end_date                                 TIMESTAMPTZ,

    is_active                                  BOOLEAN DEFAULT TRUE,

    created_by                                   UUID,

    created_at                                     TIMESTAMPTZ DEFAULT NOW(),

    updated_at                                       TIMESTAMPTZ DEFAULT NOW(),

    version                                            INT DEFAULT 1,

    CONSTRAINT fk_promotion_user
        FOREIGN KEY(created_by)
        REFERENCES app_user(id),

    CONSTRAINT chk_promotion_date_range
        CHECK(end_date IS NULL OR end_date > start_date)
);

CREATE UNIQUE INDEX uq_promotion_code_active
ON promotion(promotion_code)
WHERE is_active = TRUE;

CREATE INDEX idx_promotion_date_range
ON promotion(start_date, end_date);

------------------------------------------------------------
-- FUNCTION: KIỂM TRA VOUCHER CÓ HỢP LỆ KHÔNG
-- Backend gọi hàm này TRƯỚC khi cho khách bấm "Áp dụng" để
-- hiển thị lỗi ngay trên UI, KHÔNG tự trừ lượt dùng ở bước này
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_validate_voucher
(
    p_voucher_code VARCHAR,
    p_customer_id UUID,
    p_order_amount NUMERIC
)
RETURNS TABLE
(
    is_valid BOOLEAN,
    voucher_id UUID,
    discount_amount NUMERIC,
    message TEXT
)
LANGUAGE plpgsql
AS
$$
DECLARE

    v_voucher RECORD;

    v_used_by_customer INT;

    v_discount NUMERIC := 0;

BEGIN

    SELECT * INTO v_voucher
    FROM voucher
    WHERE voucher_code = p_voucher_code
      AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, NULL::UUID, 0::NUMERIC, 'Mã voucher không tồn tại';
        RETURN;
    END IF;

    IF v_voucher.status <> 'ACTIVE' THEN
        RETURN QUERY SELECT FALSE, v_voucher.id, 0::NUMERIC, 'Voucher đã ngừng áp dụng';
        RETURN;
    END IF;

    IF NOW() < v_voucher.start_date OR (v_voucher.end_date IS NOT NULL AND NOW() > v_voucher.end_date) THEN
        RETURN QUERY SELECT FALSE, v_voucher.id, 0::NUMERIC, 'Voucher chưa tới hạn hoặc đã hết hạn';
        RETURN;
    END IF;

    IF p_order_amount < v_voucher.min_order_amount THEN
        RETURN QUERY SELECT FALSE, v_voucher.id, 0::NUMERIC,
            'Đơn hàng chưa đạt giá trị tối thiểu ' || v_voucher.min_order_amount;
        RETURN;
    END IF;

    IF v_voucher.usage_limit_total IS NOT NULL AND v_voucher.used_count >= v_voucher.usage_limit_total THEN
        RETURN QUERY SELECT FALSE, v_voucher.id, 0::NUMERIC, 'Voucher đã hết lượt sử dụng';
        RETURN;
    END IF;

    IF p_customer_id IS NOT NULL THEN

        SELECT COUNT(*) INTO v_used_by_customer
        FROM order_voucher ov
        JOIN orders o ON o.id = ov.order_id
        WHERE ov.voucher_id = v_voucher.id
          AND o.customer_id = p_customer_id
          AND o.status <> 'CANCELLED';

        IF v_used_by_customer >= v_voucher.usage_limit_per_customer THEN
            RETURN QUERY SELECT FALSE, v_voucher.id, 0::NUMERIC, 'Bạn đã dùng hết lượt cho voucher này';
            RETURN;
        END IF;

    END IF;

    -- Tính số tiền giảm
    IF v_voucher.voucher_type = 'PERCENT' THEN
        v_discount := p_order_amount * v_voucher.discount_percent / 100;
        IF v_voucher.max_discount_amount IS NOT NULL THEN
            v_discount := LEAST(v_discount, v_voucher.max_discount_amount);
        END IF;
    ELSIF v_voucher.voucher_type = 'FIXED_AMOUNT' THEN
        v_discount := LEAST(v_voucher.discount_amount, p_order_amount);
    ELSE
        v_discount := 0; -- FREE_SHIPPING xử lý riêng ở shipping_fee, không trừ vào subtotal
    END IF;

    RETURN QUERY SELECT TRUE, v_voucher.id, v_discount, 'OK';

END;
$$;

------------------------------------------------------------
-- FUNCTION: ÁP DỤNG VOUCHER VÀO ĐƠN HÀNG
-- Khoá dòng voucher (FOR UPDATE) để tránh 2 khách cùng dùng nốt
-- lượt cuối cùng của voucher tại cùng 1 thời điểm (race condition)
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_apply_voucher
(
    p_order_id UUID,
    p_voucher_code VARCHAR,
    p_customer_id UUID
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS
$$
DECLARE

    v_voucher_id UUID;

    v_voucher_row RECORD;

    v_order_amount NUMERIC;

    v_check RECORD;

BEGIN

    SELECT COALESCE(SUM(total_price),0) INTO v_order_amount
    FROM order_item
    WHERE order_id = p_order_id;

    SELECT * INTO v_check
    FROM fn_validate_voucher(p_voucher_code, p_customer_id, v_order_amount);

    IF NOT v_check.is_valid THEN
        RAISE EXCEPTION '%', v_check.message;
    END IF;

    -- Khoá dòng voucher để cập nhật used_count an toàn khi nhiều
    -- người cùng áp dụng đồng thời
    SELECT * INTO v_voucher_row
    FROM voucher
    WHERE id = v_check.voucher_id
    FOR UPDATE;

    IF v_voucher_row.usage_limit_total IS NOT NULL AND v_voucher_row.used_count >= v_voucher_row.usage_limit_total THEN
        RAISE EXCEPTION 'Voucher đã hết lượt sử dụng (trùng lúc với người khác)';
    END IF;

    INSERT INTO order_voucher(order_id, voucher_id, discount_amount)
    VALUES(p_order_id, v_check.voucher_id, v_check.discount_amount)
    ON CONFLICT(order_id, voucher_id) DO NOTHING;

    UPDATE voucher
    SET used_count = used_count + 1
    WHERE id = v_check.voucher_id;

    IF p_customer_id IS NOT NULL THEN
        UPDATE customer_voucher
        SET is_used = TRUE, used_at = NOW()
        WHERE customer_id = p_customer_id AND voucher_id = v_check.voucher_id;
    END IF;

    UPDATE orders
    SET discount_amount = COALESCE(discount_amount,0) + v_check.discount_amount,
        total_amount = subtotal_amount + shipping_fee + tax_amount - (COALESCE(discount_amount,0) + v_check.discount_amount)
    WHERE id = p_order_id;

    RETURN v_check.discount_amount;

END;
$$;

------------------------------------------------------------
-- UPDATE TRIGGER
------------------------------------------------------------

CREATE TRIGGER trg_voucher_update
BEFORE UPDATE
ON voucher
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_promotion_update
BEFORE UPDATE
ON promotion
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();