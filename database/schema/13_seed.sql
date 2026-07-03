/*
===========================================================
Beverage Operating System
13_seed.sql
Seed Data (Master Data + 1 sản phẩm demo "Matcha Latte"
theo đúng ví dụ trong tài liệu ý tưởng: Recipe First)

Toàn bộ script dùng ON CONFLICT DO NOTHING theo mã (code) tự
nhiên + subquery tra cứu id -> chạy lại nhiều lần an toàn
(idempotent), không phá dữ liệu đã có.
===========================================================
*/

------------------------------------------------------------
-- 1. ROLE & PERMISSION
------------------------------------------------------------

INSERT INTO role(code, name, description)
VALUES
('OWNER','Chủ quán','Toàn quyền hệ thống'),
('MANAGER','Quản lý','Quản lý vận hành, không có quyền hệ thống'),
('KITCHEN','Pha chế','Màn hình Kitchen'),
('DELIVERY','Giao hàng','Màn hình Delivery'),
('CUSTOMER','Khách hàng','Tài khoản khách hàng trên Website')
ON CONFLICT (code) DO NOTHING;

INSERT INTO permission(code, module, action, description)
VALUES
('order.view','ORDER','VIEW','Xem đơn hàng'),
('order.manage','ORDER','MANAGE','Quản lý đơn hàng'),
('inventory.view','INVENTORY','VIEW','Xem tồn kho'),
('inventory.manage','INVENTORY','MANAGE','Quản lý tồn kho'),
('report.view','REPORT','VIEW','Xem báo cáo'),
('system.manage','SYSTEM','MANAGE','Quản trị hệ thống')
ON CONFLICT (code) DO NOTHING;

INSERT INTO role_permission(role_id, permission_id)
SELECT r.id, p.id
FROM role r
CROSS JOIN permission p
WHERE r.code = 'OWNER'
ON CONFLICT DO NOTHING;

INSERT INTO role_permission(role_id, permission_id)
SELECT r.id, p.id
FROM role r
JOIN permission p ON p.code IN ('order.view','order.manage','inventory.view','report.view')
WHERE r.code = 'MANAGER'
ON CONFLICT DO NOTHING;

INSERT INTO role_permission(role_id, permission_id)
SELECT r.id, p.id
FROM role r
JOIN permission p ON p.code = 'order.view'
WHERE r.code IN ('KITCHEN','DELIVERY')
ON CONFLICT DO NOTHING;

------------------------------------------------------------
-- 2. APP USER (OWNER MẶC ĐỊNH)
-- password mặc định "Admin@123" -> cần đổi ngay sau khi cài đặt
------------------------------------------------------------

INSERT INTO app_user(username, email, phone, password_hash, full_name, status, email_verified)
VALUES
('owner','owner@bos.local','0900000000', crypt('Admin@123', gen_salt('bf')), 'Chủ quán', 'ACTIVE', TRUE)
ON CONFLICT (username) DO NOTHING;

INSERT INTO user_role(user_id, role_id)
SELECT u.id, r.id
FROM app_user u
JOIN role r ON r.code = 'OWNER'
WHERE u.username = 'owner'
ON CONFLICT DO NOTHING;

------------------------------------------------------------
-- 3. APP SETTING
------------------------------------------------------------

INSERT INTO app_setting(setting_key, setting_value, description)
VALUES
('shop.name','BOS Beverage','Tên quán hiển thị trên Website/Hoá đơn'),
('shop.tax_percent','0','Thuế VAT áp dụng (%)'),
('loyalty.point_per_vnd','10000','Số VND tương ứng 1 điểm tích luỹ'),
('order.code_prefix','ORD','Tiền tố mã đơn hàng')
ON CONFLICT (setting_key) DO NOTHING;

------------------------------------------------------------
-- 4. WAREHOUSE (KHO CHÍNH)
------------------------------------------------------------

INSERT INTO warehouse(warehouse_code, warehouse_name, address, is_default)
VALUES
('WH-MAIN','Kho chính','Chi nhánh 1', TRUE)
ON CONFLICT (warehouse_code) DO NOTHING;

------------------------------------------------------------
-- 5. SUPPLIER
------------------------------------------------------------

INSERT INTO supplier(supplier_code, supplier_name, phone, email, address)
VALUES
('SUP-001','Công ty Nguyên liệu Pha chế ABC','0909123456','contact@abc-supply.vn','TP. Hồ Chí Minh')
ON CONFLICT (supplier_code) DO NOTHING;

------------------------------------------------------------
-- 6. PRODUCT CATEGORY
------------------------------------------------------------

INSERT INTO product_category(category_code, category_name, slug, display_order)
VALUES
('COFFEE','Coffee','coffee',1),
('TEA','Tea','tea',2),
('MILK_TEA','Milk Tea','milk-tea',3),
('FRUIT_TEA','Fruit Tea','fruit-tea',4),
('MATCHA','Matcha','matcha',5),
('TOPPING','Topping','topping',6)
ON CONFLICT (category_code) DO NOTHING;

------------------------------------------------------------
-- 7. PRODUCT SIZE
------------------------------------------------------------

INSERT INTO product_size(size_code, size_name, display_order)
VALUES
('S','Size S',1),
('M','Size M',2),
('L','Size L',3)
ON CONFLICT (size_code) DO NOTHING;

------------------------------------------------------------
-- 8. INGREDIENT CATEGORY
------------------------------------------------------------

INSERT INTO ingredient_category(category_code, category_name, display_order)
VALUES
('DAIRY','Sữa & Kem',1),
('TEA_POWDER','Trà & Bột',2),
('SYRUP','Đường & Syrup',3),
('PACKAGING','Bao bì',4),
('TOPPING_ING','Nguyên liệu Topping',5)
ON CONFLICT (category_code) DO NOTHING;

------------------------------------------------------------
-- 9. INGREDIENT
-- Theo đúng ví dụ trong ý tưởng: Matcha, Milk, Sugar, Ice,
-- Cup, Lid, Straw, Sticker - mọi thứ đều là Ingredient
------------------------------------------------------------

INSERT INTO ingredient(category_id, ingredient_code, ingredient_name, unit_id, minimum_stock, reorder_point, is_inventory)
SELECT ic.id, v.code, v.name, iu.id, v.min_stock, v.reorder, TRUE
FROM
(
    VALUES
    ('ING-MATCHA','Matcha','TEA_POWDER','G',500,1000),
    ('ING-MILK','Milk','DAIRY','ML',5000,10000),
    ('ING-SUGAR','Sugar','SYRUP','ML',3000,6000),
    ('ING-ICE','Ice','DAIRY','G',10000,20000),
    ('ING-CUP','Cup','PACKAGING','PCS',200,500),
    ('ING-LID','Lid','PACKAGING','PCS',200,500),
    ('ING-STRAW','Straw','PACKAGING','PCS',200,500),
    ('ING-STICKER','Sticker','PACKAGING','PCS',200,500)
) AS v(code, name, cat_code, unit_code, min_stock, reorder)
JOIN ingredient_category ic ON ic.category_code = v.cat_code
JOIN ingredient_unit iu ON iu.unit_code = v.unit_code
ON CONFLICT (ingredient_code) DO NOTHING;

------------------------------------------------------------
-- 10. GIÁ NGUYÊN LIỆU BAN ĐẦU
-- (INSERT trực tiếp thay vì qua fn_import_stock để không sinh
-- batch/stock ảo; kho thực tế sẽ vào qua 07_purchase.sql)
------------------------------------------------------------

INSERT INTO ingredient_price_history(ingredient_id, supplier_id, unit_price, note)
SELECT i.id, s.id, v.price, 'Giá khởi tạo ban đầu'
FROM
(
    VALUES
    ('ING-MATCHA', 800),
    ('ING-MILK', 25),
    ('ING-SUGAR', 15),
    ('ING-ICE', 3),
    ('ING-CUP', 800),
    ('ING-LID', 300),
    ('ING-STRAW', 150),
    ('ING-STICKER', 100)
) AS v(code, price)
JOIN ingredient i ON i.ingredient_code = v.code
CROSS JOIN (SELECT id FROM supplier WHERE supplier_code = 'SUP-001') s
WHERE NOT EXISTS
(
    SELECT 1 FROM ingredient_price_history iph WHERE iph.ingredient_id = i.id
);

------------------------------------------------------------
-- 11. SẢN PHẨM DEMO: MATCHA LATTE (Size M)
------------------------------------------------------------

INSERT INTO product(category_id, product_code, product_name, slug, short_description, is_active)
SELECT pc.id, 'PRD-MATCHA-LATTE', 'Matcha Latte', 'matcha-latte', 'Trà xanh Nhật Bản hoà cùng sữa tươi', TRUE
FROM product_category pc
WHERE pc.category_code = 'MATCHA'
ON CONFLICT (product_code) DO NOTHING;

INSERT INTO product_variant(product_id, size_id, sku, selling_price, is_default)
SELECT p.id, ps.id, 'SKU-MATCHA-LATTE-M', 45000, TRUE
FROM product p
JOIN product_size ps ON ps.size_code = 'M'
WHERE p.product_code = 'PRD-MATCHA-LATTE'
ON CONFLICT (sku) DO NOTHING;

------------------------------------------------------------
-- 12. RECIPE - MATCHA LATTE
-- Matcha 5g / Milk 120ml / Sugar 20ml / Cup 1 / Lid 1
------------------------------------------------------------

INSERT INTO recipe(recipe_code, recipe_name, product_variant_id)
SELECT 'RCP-MATCHA-LATTE-M', 'Công thức Matcha Latte (M)', pv.id
FROM product_variant pv
WHERE pv.sku = 'SKU-MATCHA-LATTE-M'
ON CONFLICT (recipe_code) DO NOTHING;

INSERT INTO recipe_version(recipe_id, version_no, version_name, is_current, approved_at)
SELECT r.id, 1, 'Phiên bản đầu tiên', TRUE, NOW()
FROM recipe r
WHERE r.recipe_code = 'RCP-MATCHA-LATTE-M'
ON CONFLICT (recipe_id, version_no) DO NOTHING;

INSERT INTO recipe_ingredient(recipe_version_id, ingredient_id, unit_id, quantity, display_order)
SELECT rv.id, i.id, iu.id, v.quantity, v.ord
FROM
(
    VALUES
    ('ING-MATCHA','G',5,1),
    ('ING-MILK','ML',120,2),
    ('ING-SUGAR','ML',20,3),
    ('ING-CUP','PCS',1,4),
    ('ING-LID','PCS',1,5)
) AS v(ing_code, unit_code, quantity, ord)
JOIN ingredient i ON i.ingredient_code = v.ing_code
JOIN ingredient_unit iu ON iu.unit_code = v.unit_code
CROSS JOIN
(
    SELECT rv.id
    FROM recipe_version rv
    JOIN recipe r ON r.id = rv.recipe_id
    WHERE r.recipe_code = 'RCP-MATCHA-LATTE-M' AND rv.is_current = TRUE
) rv
WHERE NOT EXISTS
(
    SELECT 1 FROM recipe_ingredient ri WHERE ri.recipe_version_id = rv.id AND ri.ingredient_id = i.id
);

INSERT INTO recipe_step(recipe_version_id, step_no, step_name, instruction, estimated_second)
SELECT rv.id, v.step_no, v.step_name, v.instruction, v.second
FROM
(
    VALUES
    (1,'Pha matcha','Đánh tan bột matcha với 30ml nước nóng cho tan hoàn toàn',60),
    (2,'Pha chế','Thêm đá, sữa tươi và đường vào ly, khuấy đều',60),
    (3,'Hoàn thiện','Đổ matcha đã đánh lên trên cùng, đậy nắp, dán sticker',30)
) AS v(step_no, step_name, instruction, second)
CROSS JOIN
(
    SELECT rv.id
    FROM recipe_version rv
    JOIN recipe r ON r.id = rv.recipe_id
    WHERE r.recipe_code = 'RCP-MATCHA-LATTE-M' AND rv.is_current = TRUE
) rv
WHERE NOT EXISTS
(
    SELECT 1 FROM recipe_step rs WHERE rs.recipe_version_id = rv.id AND rs.step_no = v.step_no
);

------------------------------------------------------------
-- 13. TÍNH GIÁ VỐN BAN ĐẦU CHO CÔNG THỨC DEMO
------------------------------------------------------------

INSERT INTO recipe_cost(recipe_version_id, ingredient_cost, total_cost)
SELECT rv.id, fn_calculate_recipe_cost(rv.id), fn_calculate_recipe_cost(rv.id)
FROM recipe_version rv
JOIN recipe r ON r.id = rv.recipe_id
WHERE r.recipe_code = 'RCP-MATCHA-LATTE-M' AND rv.is_current = TRUE
ON CONFLICT (recipe_version_id) DO NOTHING;

------------------------------------------------------------
-- 14. KHÁCH HÀNG DEMO
------------------------------------------------------------

INSERT INTO customer(customer_code, full_name, phone, gender)
VALUES
('CUS-000001','Nguyễn Văn A','0912345678','MALE')
ON CONFLICT (customer_code) DO NOTHING;