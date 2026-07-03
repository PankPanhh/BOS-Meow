/*
===========================================================
Beverage Operating System
15_hotfix.sql
Patch trước khi code Backend (5 điểm, KHÔNG mở rộng thêm)

Phạm vi CHỈ gồm:
 1. Unique 1 recipe chỉ có 1 version đang active
 2. Chặn recipe_ingredient.quantity <= 0
 3. Chặn selling_price âm (product_variant / topping / combo)
 4. Đồng bộ soft-delete (deleted_at) cho 5 bảng chính
 5. Index cho bảng orders

Lưu ý: Voucher/CRM đã được tách ra thành module riêng ở
14_promotion.sql (chạy trước file này), nên KHÔNG lặp lại ở
đây. File này vẫn cố tình KHÔNG đụng tới: hoàn kho khi hủy
đơn, wiring price_list vào Order, Branch/Store, Cart... để
lại cho sau, tránh over-engineering ở giai đoạn MVP.

Script idempotent - chạy lại nhiều lần không lỗi, an toàn áp
lên DB đã có dữ liệu thật (dùng ADD CONSTRAINT ... NOT VALID
+ VALIDATE CONSTRAINT để tránh khoá bảng lâu khi bảng đã lớn).
===========================================================
*/

------------------------------------------------------------
-- 1. UNIQUE: 1 RECIPE CHỈ CÓ 1 VERSION is_current = TRUE
------------------------------------------------------------

-- Dọn dữ liệu cũ trước (nếu lỡ có 2 version cùng active do thao
-- tác thủ công) để tránh ALTER/CREATE INDEX phía dưới bị lỗi.
-- Quy tắc giữ lại: version có effective_from mới nhất, hoà thì
-- lấy version_no lớn nhất.

WITH ranked AS
(
    SELECT
        id,
        ROW_NUMBER() OVER
        (
            PARTITION BY recipe_id
            ORDER BY effective_from DESC, version_no DESC
        ) AS rn
    FROM recipe_version
    WHERE is_current = TRUE
)
UPDATE recipe_version rv
SET is_current = FALSE
FROM ranked
WHERE rv.id = ranked.id
  AND ranked.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS uq_recipe_current
ON recipe_version(recipe_id)
WHERE is_current = TRUE;

------------------------------------------------------------
-- 2. CHẶN SỐ LƯỢNG NGUYÊN LIỆU <= 0 TRONG CÔNG THỨC
------------------------------------------------------------

ALTER TABLE recipe_ingredient
ADD CONSTRAINT chk_recipe_ingredient_qty
CHECK(quantity > 0)
NOT VALID;

ALTER TABLE recipe_ingredient
VALIDATE CONSTRAINT chk_recipe_ingredient_qty;

------------------------------------------------------------
-- 3. CHẶN GIÁ BÁN ÂM
------------------------------------------------------------

ALTER TABLE product_variant
ADD CONSTRAINT chk_product_variant_price
CHECK(selling_price >= 0)
NOT VALID;

ALTER TABLE product_variant
VALIDATE CONSTRAINT chk_product_variant_price;

ALTER TABLE topping
ADD CONSTRAINT chk_topping_price
CHECK(selling_price >= 0)
NOT VALID;

ALTER TABLE topping
VALIDATE CONSTRAINT chk_topping_price;

ALTER TABLE combo
ADD CONSTRAINT chk_combo_price
CHECK(selling_price >= 0)
NOT VALID;

ALTER TABLE combo
VALIDATE CONSTRAINT chk_combo_price;

------------------------------------------------------------
-- 4. ĐỒNG BỘ SOFT DELETE (deleted_at) CHO 5 BẢNG CHÍNH
--
-- Đã kiểm tra thực tế trên schema hiện tại: product, ingredient,
-- customer, supplier ĐÃ có deleted_at sẵn từ 03/04/05/07. Chỉ
-- riêng product_variant là thiếu. Dùng ADD COLUMN IF NOT EXISTS
-- cho cả 5 bảng để script này an toàn dù chạy trên schema nào.
------------------------------------------------------------

ALTER TABLE product         ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE product_variant ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE ingredient      ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE customer        ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE supplier        ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Hệ quả đi kèm bắt buộc phải xử lý: các cột mã (product_code,
-- sku, ingredient_code, customer_code, supplier_code) đang là
-- UNIQUE toàn bảng. Nếu chỉ thêm deleted_at mà không đổi ràng
-- buộc này, sau khi "xoá mềm" 1 sản phẩm sẽ KHÔNG THỂ tạo mới
-- sản phẩm khác dùng lại đúng mã đó -> đổi thành UNIQUE INDEX
-- có điều kiện (chỉ áp dụng cho bản ghi còn sống).

ALTER TABLE product
DROP CONSTRAINT IF EXISTS product_product_code_key;

CREATE UNIQUE INDEX IF NOT EXISTS uq_product_code_active
ON product(product_code)
WHERE deleted_at IS NULL;

ALTER TABLE product_variant
DROP CONSTRAINT IF EXISTS product_variant_sku_key;

CREATE UNIQUE INDEX IF NOT EXISTS uq_product_variant_sku_active
ON product_variant(sku)
WHERE deleted_at IS NULL AND sku IS NOT NULL;

ALTER TABLE ingredient
DROP CONSTRAINT IF EXISTS ingredient_ingredient_code_key;

CREATE UNIQUE INDEX IF NOT EXISTS uq_ingredient_code_active
ON ingredient(ingredient_code)
WHERE deleted_at IS NULL;

ALTER TABLE customer
DROP CONSTRAINT IF EXISTS customer_customer_code_key;

CREATE UNIQUE INDEX IF NOT EXISTS uq_customer_code_active
ON customer(customer_code)
WHERE deleted_at IS NULL;

ALTER TABLE supplier
DROP CONSTRAINT IF EXISTS supplier_supplier_code_key;

CREATE UNIQUE INDEX IF NOT EXISTS uq_supplier_code_active
ON supplier(supplier_code)
WHERE deleted_at IS NULL;

------------------------------------------------------------
-- 5. INDEX CHO ORDER
--
-- Lưu ý đặt tên: bảng đơn hàng trong hệ thống này tên là
-- "orders" (không phải "customer_order"), cột trạng thái tên
-- là "status" (không phải "order_status" - "order_status" là
-- tên KIỂU ENUM dùng cho cột status, không phải tên cột).
-- 3 index dưới đây thực chất ĐÃ được tạo sẵn trong 08_order.sql
-- (idx_order_customer, idx_order_status, idx_order_created).
-- Dùng IF NOT EXISTS để script này chạy an toàn dù index đã có,
-- không tạo trùng, không báo lỗi.
------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_order_customer ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_order_status   ON orders(status);
CREATE INDEX IF NOT EXISTS idx_order_created  ON orders(created_at);