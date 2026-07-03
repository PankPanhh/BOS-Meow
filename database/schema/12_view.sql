/*
===========================================================
Beverage Operating System
12_view.sql
Views phục vụ Admin Dashboard / Kitchen / API Report
===========================================================
*/

------------------------------------------------------------
-- VIEW: CÔNG THỨC HIỆN HÀNH + GIÁ VỐN
------------------------------------------------------------

CREATE OR REPLACE VIEW view_current_recipe AS
SELECT
    r.id                    AS recipe_id,
    r.recipe_code,
    r.recipe_name,
    r.product_variant_id,
    rv.id                    AS recipe_version_id,
    rv.version_no,
    rc.ingredient_cost,
    rc.packaging_cost,
    rc.labor_cost,
    rc.overhead_cost,
    rc.total_cost,
    rc.calculated_at
FROM recipe r
JOIN recipe_version rv ON rv.recipe_id = r.id AND rv.is_current = TRUE
LEFT JOIN recipe_cost rc ON rc.recipe_version_id = rv.id
WHERE r.deleted_at IS NULL;

------------------------------------------------------------
-- VIEW: MENU BÁN HÀNG (SẢN PHẨM + GIÁ + GIÁ VỐN + BIÊN LỢI NHUẬN)
------------------------------------------------------------

CREATE OR REPLACE VIEW view_product_menu AS
SELECT
    p.id                    AS product_id,
    p.product_name,
    pc.category_name,
    pv.id                    AS variant_id,
    ps.size_name,
    pv.selling_price,
    COALESCE(vr.total_cost,0) AS cost_price,
    pv.selling_price - COALESCE(vr.total_cost,0) AS gross_margin,
    CASE
        WHEN pv.selling_price > 0
        THEN ROUND(((pv.selling_price - COALESCE(vr.total_cost,0)) / pv.selling_price) * 100, 2)
        ELSE 0
    END AS margin_percent,
    pv.is_active,
    p.thumbnail
FROM product p
JOIN product_category pc ON pc.id = p.category_id
JOIN product_variant pv ON pv.product_id = p.id
JOIN product_size ps ON ps.id = pv.size_id
LEFT JOIN view_current_recipe vr ON vr.product_variant_id = pv.id
WHERE p.deleted_at IS NULL;

------------------------------------------------------------
-- VIEW: TỒN KHO HIỆN TẠI (THEO NGUYÊN LIỆU)
------------------------------------------------------------

CREATE OR REPLACE VIEW view_inventory_current AS
SELECT
    i.id                    AS ingredient_id,
    i.ingredient_code,
    i.ingredient_name,
    ic.category_name,
    iu.symbol                AS unit,
    ist.warehouse_id,
    w.warehouse_name,
    COALESCE(ist.quantity_on_hand,0) AS quantity_on_hand,
    i.minimum_stock,
    i.reorder_point,
    CASE
        WHEN COALESCE(ist.quantity_on_hand,0) <= i.minimum_stock THEN TRUE
        ELSE FALSE
    END AS is_low_stock
FROM ingredient i
JOIN ingredient_category ic ON ic.id = i.category_id
JOIN ingredient_unit iu ON iu.id = i.unit_id
LEFT JOIN inventory_stock ist ON ist.ingredient_id = i.id
LEFT JOIN warehouse w ON w.id = ist.warehouse_id
WHERE i.deleted_at IS NULL;

------------------------------------------------------------
-- VIEW: NGUYÊN LIỆU SẮP HẾT
------------------------------------------------------------

CREATE OR REPLACE VIEW view_low_stock AS
SELECT *
FROM view_inventory_current
WHERE is_low_stock = TRUE;

------------------------------------------------------------
-- VIEW: LÔ HÀNG SẮP HẾT HẠN (FEFO ALERT)
------------------------------------------------------------

CREATE OR REPLACE VIEW view_expiring_batch AS
SELECT
    ib.id                    AS batch_id,
    ib.batch_code,
    i.ingredient_name,
    w.warehouse_name,
    ib.remain_quantity,
    ib.expired_at,
    (ib.expired_at::DATE - CURRENT_DATE) AS day_remaining
FROM inventory_batch ib
JOIN ingredient i ON i.id = ib.ingredient_id
JOIN warehouse w ON w.id = ib.warehouse_id
WHERE ib.remain_quantity > 0
  AND ib.expired_at IS NOT NULL
  AND ib.expired_at::DATE - CURRENT_DATE <= 7
ORDER BY ib.expired_at ASC;

------------------------------------------------------------
-- VIEW: CHI TIẾT ĐƠN HÀNG (GỘP ITEM + TOPPING + MODIFIER)
------------------------------------------------------------

CREATE OR REPLACE VIEW view_order_detail AS
SELECT
    o.id                    AS order_id,
    o.order_code,
    o.status,
    o.payment_status,
    o.order_type,
    o.total_amount,
    c.full_name              AS customer_name,
    c.phone                  AS customer_phone,
    oi.id                     AS order_item_id,
    p.product_name,
    ps.size_name,
    oi.quantity,
    oi.unit_price,
    oi.ingredient_cost_amount,
    oi.total_price,
    (
        SELECT STRING_AGG(t.topping_name, ', ')
        FROM order_item_topping oit
        JOIN topping t ON t.id = oit.topping_id
        WHERE oit.order_item_id = oi.id
    ) AS toppings,
    o.created_at
FROM orders o
JOIN order_item oi ON oi.order_id = o.id
JOIN product_variant pv ON pv.id = oi.product_variant_id
JOIN product p ON p.id = pv.product_id
JOIN product_size ps ON ps.id = pv.size_id
LEFT JOIN customer c ON c.id = o.customer_id;

------------------------------------------------------------
-- VIEW: ĐƠN HÀNG CHO MÀN HÌNH KITCHEN
------------------------------------------------------------

CREATE OR REPLACE VIEW view_kitchen_queue AS
SELECT
    o.id                    AS order_id,
    o.order_code,
    o.table_no,
    o.order_type,
    o.status,
    o.created_at,
    p.product_name,
    ps.size_name,
    oi.quantity,
    oi.note
FROM orders o
JOIN order_item oi ON oi.order_id = o.id
JOIN product_variant pv ON pv.id = oi.product_variant_id
JOIN product p ON p.id = pv.product_id
JOIN product_size ps ON ps.id = pv.size_id
WHERE o.status IN ('CONFIRMED','PREPARING')
ORDER BY o.created_at ASC;

------------------------------------------------------------
-- VIEW: TRẠNG THÁI GIAO HÀNG
------------------------------------------------------------

CREATE OR REPLACE VIEW view_delivery_status AS
SELECT
    d.id                    AS delivery_id,
    d.delivery_code,
    o.order_code,
    d.status,
    u.full_name              AS delivery_staff,
    d.receiver_name,
    d.receiver_phone,
    d.address,
    d.delivery_fee,
    d.assigned_at,
    d.delivered_at
FROM delivery d
JOIN orders o ON o.id = d.order_id
LEFT JOIN app_user u ON u.id = d.delivery_user_id;

------------------------------------------------------------
-- VIEW: DOANH THU THEO NGÀY (30 NGÀY GẦN NHẤT)
------------------------------------------------------------

CREATE OR REPLACE VIEW view_daily_revenue AS
SELECT
    summary_date,
    SUM(net_revenue)   AS net_revenue,
    SUM(total_cost)    AS total_cost,
    SUM(gross_profit)  AS gross_profit,
    SUM(total_order)   AS total_order
FROM daily_sales_summary
WHERE summary_date >= CURRENT_DATE - INTERVAL '30 day'
GROUP BY summary_date
ORDER BY summary_date DESC;

------------------------------------------------------------
-- VIEW: TOP 10 SẢN PHẨM BÁN CHẠY (30 NGÀY)
------------------------------------------------------------

CREATE OR REPLACE VIEW view_top_products AS
SELECT
    pv.id                    AS variant_id,
    p.product_name,
    ps.size_name,
    SUM(pss.quantity_sold)     AS total_quantity,
    SUM(pss.revenue)             AS total_revenue,
    SUM(pss.profit)                AS total_profit
FROM product_sales_summary pss
JOIN product_variant pv ON pv.id = pss.product_variant_id
JOIN product p ON p.id = pv.product_id
JOIN product_size ps ON ps.id = pv.size_id
WHERE pss.summary_date >= CURRENT_DATE - INTERVAL '30 day'
GROUP BY pv.id, p.product_name, ps.size_name
ORDER BY total_quantity DESC
LIMIT 10;

------------------------------------------------------------
-- VIEW: TOP 10 KHÁCH HÀNG THÂN THIẾT (30 NGÀY)
------------------------------------------------------------

CREATE OR REPLACE VIEW view_top_customers AS
SELECT
    c.id                    AS customer_id,
    c.full_name,
    c.phone,
    c.loyalty_point,
    SUM(css.order_count)       AS total_order,
    SUM(css.total_spent)         AS total_spent
FROM customer_sales_summary css
JOIN customer c ON c.id = css.customer_id
WHERE css.summary_date >= CURRENT_DATE - INTERVAL '30 day'
GROUP BY c.id, c.full_name, c.phone, c.loyalty_point
ORDER BY total_spent DESC
LIMIT 10;