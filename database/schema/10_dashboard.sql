/*
===========================================================
Beverage Operating System
10_dashboard.sql
Dashboard / Report Summary (bảng tổng hợp phục vụ đọc nhanh)

Toàn bộ Dashboard đều được "sinh ra" từ Recipe -> Inventory ->
Order -> Cost theo đúng triết lý Data First / Single Source
of Truth. Các bảng dưới đây chỉ là lớp cache tổng hợp
(denormalized) để tránh tính toán lại từ đầu mỗi lần load.
===========================================================
*/

------------------------------------------------------------
-- DAILY SALES SUMMARY
------------------------------------------------------------

CREATE TABLE daily_sales_summary
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    summary_date              DATE NOT NULL,

    warehouse_id                 UUID,

    total_order                    INT DEFAULT 0,

    total_customer                   INT DEFAULT 0,

    gross_revenue                      NUMERIC(18,2) DEFAULT 0,

    discount_amount                      NUMERIC(18,2) DEFAULT 0,

    net_revenue                            NUMERIC(18,2) DEFAULT 0,

    total_cost                               NUMERIC(18,2) DEFAULT 0,

    gross_profit                               NUMERIC(18,2) DEFAULT 0,

    created_at                                   TIMESTAMPTZ DEFAULT NOW(),

    updated_at                                     TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_daily_sales_warehouse
        FOREIGN KEY(warehouse_id)
        REFERENCES warehouse(id),

    CONSTRAINT uq_daily_sales_summary
        UNIQUE(summary_date, warehouse_id)
);

CREATE INDEX idx_daily_sales_date
ON daily_sales_summary(summary_date);

------------------------------------------------------------
-- PRODUCT SALES SUMMARY (TOP MÓN)
------------------------------------------------------------

CREATE TABLE product_sales_summary
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    summary_date              DATE NOT NULL,

    product_variant_id           UUID NOT NULL,

    quantity_sold                   NUMERIC(18,2) DEFAULT 0,

    revenue                           NUMERIC(18,2) DEFAULT 0,

    cost                                NUMERIC(18,2) DEFAULT 0,

    profit                                NUMERIC(18,2) DEFAULT 0,

    CONSTRAINT fk_product_sales_variant
        FOREIGN KEY(product_variant_id)
        REFERENCES product_variant(id),

    CONSTRAINT uq_product_sales_summary
        UNIQUE(summary_date, product_variant_id)
);

CREATE INDEX idx_product_sales_date
ON product_sales_summary(summary_date);

CREATE INDEX idx_product_sales_variant
ON product_sales_summary(product_variant_id);

------------------------------------------------------------
-- INGREDIENT USAGE SUMMARY (NGUYÊN LIỆU SẮP HẾT / DỰ BÁO NHẬP)
------------------------------------------------------------

CREATE TABLE ingredient_usage_summary
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    summary_date              DATE NOT NULL,

    ingredient_id                UUID NOT NULL,

    quantity_used                   NUMERIC(18,4) DEFAULT 0,

    usage_cost                        NUMERIC(18,2) DEFAULT 0,

    CONSTRAINT fk_ingredient_usage_ingredient
        FOREIGN KEY(ingredient_id)
        REFERENCES ingredient(id),

    CONSTRAINT uq_ingredient_usage_summary
        UNIQUE(summary_date, ingredient_id)
);

CREATE INDEX idx_ingredient_usage_date
ON ingredient_usage_summary(summary_date);

------------------------------------------------------------
-- CUSTOMER SALES SUMMARY (TOP KHÁCH)
------------------------------------------------------------

CREATE TABLE customer_sales_summary
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    summary_date              DATE NOT NULL,

    customer_id                  UUID NOT NULL,

    order_count                     INT DEFAULT 0,

    total_spent                       NUMERIC(18,2) DEFAULT 0,

    CONSTRAINT fk_customer_sales_customer
        FOREIGN KEY(customer_id)
        REFERENCES customer(id),

    CONSTRAINT uq_customer_sales_summary
        UNIQUE(summary_date, customer_id)
);

CREATE INDEX idx_customer_sales_date
ON customer_sales_summary(summary_date);

------------------------------------------------------------
-- DASHBOARD KPI SNAPSHOT (TỔNG QUAN NHANH)
------------------------------------------------------------

CREATE TABLE dashboard_kpi_snapshot
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    snapshot_date              DATE UNIQUE NOT NULL,

    total_revenue                 NUMERIC(18,2) DEFAULT 0,

    total_profit                     NUMERIC(18,2) DEFAULT 0,

    total_order                        INT DEFAULT 0,

    new_customer_count                   INT DEFAULT 0,

    low_stock_count                        INT DEFAULT 0,

    top_product_id                           UUID,

    created_at                                 TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_dashboard_top_product
        FOREIGN KEY(top_product_id)
        REFERENCES product_variant(id)
);

------------------------------------------------------------
-- FUNCTION: REFRESH DASHBOARD THEO NGÀY
-- Được gọi bởi scheduler (cron / pg_cron) hoặc trigger cuối
-- ngày; cũng có thể gọi thủ công để backfill dữ liệu cũ
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_refresh_daily_dashboard
(
    p_date DATE
)
RETURNS VOID
LANGUAGE plpgsql
AS
$$
BEGIN

    -- 1. Doanh thu / lợi nhuận theo kho
    INSERT INTO daily_sales_summary
    (
        summary_date, warehouse_id, total_order, total_customer,
        gross_revenue, discount_amount, net_revenue, total_cost, gross_profit
    )
    SELECT
        p_date,
        o.warehouse_id,
        COUNT(DISTINCT o.id),
        COUNT(DISTINCT o.customer_id),
        COALESCE(SUM(oi.total_price + oi.discount_amount),0),
        COALESCE(SUM(oi.discount_amount),0),
        COALESCE(SUM(oi.total_price),0),
        COALESCE(SUM(oi.ingredient_cost_amount),0),
        COALESCE(SUM(oi.total_price - oi.ingredient_cost_amount),0)
    FROM orders o
    JOIN order_item oi ON oi.order_id = o.id
    WHERE o.status = 'COMPLETED'
      AND DATE(o.completed_at) = p_date
    GROUP BY o.warehouse_id
    ON CONFLICT(summary_date, warehouse_id)
    DO UPDATE
    SET
        total_order = EXCLUDED.total_order,
        total_customer = EXCLUDED.total_customer,
        gross_revenue = EXCLUDED.gross_revenue,
        discount_amount = EXCLUDED.discount_amount,
        net_revenue = EXCLUDED.net_revenue,
        total_cost = EXCLUDED.total_cost,
        gross_profit = EXCLUDED.gross_profit,
        updated_at = NOW();

    -- 2. Top món
    INSERT INTO product_sales_summary
    (
        summary_date, product_variant_id, quantity_sold, revenue, cost, profit
    )
    SELECT
        p_date,
        oi.product_variant_id,
        SUM(oi.quantity),
        SUM(oi.total_price),
        SUM(oi.ingredient_cost_amount),
        SUM(oi.total_price - oi.ingredient_cost_amount)
    FROM orders o
    JOIN order_item oi ON oi.order_id = o.id
    WHERE o.status = 'COMPLETED'
      AND DATE(o.completed_at) = p_date
    GROUP BY oi.product_variant_id
    ON CONFLICT(summary_date, product_variant_id)
    DO UPDATE
    SET
        quantity_sold = EXCLUDED.quantity_sold,
        revenue = EXCLUDED.revenue,
        cost = EXCLUDED.cost,
        profit = EXCLUDED.profit;

    -- 3. Nguyên liệu tiêu thụ
    INSERT INTO ingredient_usage_summary
    (
        summary_date, ingredient_id, quantity_used, usage_cost
    )
    SELECT
        p_date,
        sm.ingredient_id,
        SUM(sm.quantity),
        SUM(sm.quantity * sm.unit_cost)
    FROM stock_movement sm
    WHERE sm.movement_type = 'ORDER_CONSUME'
      AND DATE(sm.created_at) = p_date
    GROUP BY sm.ingredient_id
    ON CONFLICT(summary_date, ingredient_id)
    DO UPDATE
    SET
        quantity_used = EXCLUDED.quantity_used,
        usage_cost = EXCLUDED.usage_cost;

    -- 4. Top khách
    INSERT INTO customer_sales_summary
    (
        summary_date, customer_id, order_count, total_spent
    )
    SELECT
        p_date,
        o.customer_id,
        COUNT(DISTINCT o.id),
        SUM(o.total_amount)
    FROM orders o
    WHERE o.status = 'COMPLETED'
      AND o.customer_id IS NOT NULL
      AND DATE(o.completed_at) = p_date
    GROUP BY o.customer_id
    ON CONFLICT(summary_date, customer_id)
    DO UPDATE
    SET
        order_count = EXCLUDED.order_count,
        total_spent = EXCLUDED.total_spent;

    -- 5. KPI tổng quan
    INSERT INTO dashboard_kpi_snapshot
    (
        snapshot_date, total_revenue, total_profit, total_order,
        new_customer_count, low_stock_count, top_product_id
    )
    SELECT
        p_date,
        COALESCE((SELECT SUM(net_revenue) FROM daily_sales_summary WHERE summary_date = p_date),0),
        COALESCE((SELECT SUM(gross_profit) FROM daily_sales_summary WHERE summary_date = p_date),0),
        COALESCE((SELECT SUM(total_order) FROM daily_sales_summary WHERE summary_date = p_date),0),
        COALESCE((SELECT COUNT(*) FROM customer WHERE DATE(created_at) = p_date),0),
        COALESCE((SELECT COUNT(*) FROM inventory_stock ist JOIN ingredient i ON i.id = ist.ingredient_id WHERE ist.quantity_on_hand <= i.minimum_stock),0),
        (SELECT product_variant_id FROM product_sales_summary WHERE summary_date = p_date ORDER BY quantity_sold DESC LIMIT 1)
    ON CONFLICT(snapshot_date)
    DO UPDATE
    SET
        total_revenue = EXCLUDED.total_revenue,
        total_profit = EXCLUDED.total_profit,
        total_order = EXCLUDED.total_order,
        new_customer_count = EXCLUDED.new_customer_count,
        low_stock_count = EXCLUDED.low_stock_count,
        top_product_id = EXCLUDED.top_product_id;

END;
$$;