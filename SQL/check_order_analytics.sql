-- Run after SQL/order_analytics.sql on the same DuckDB connection.
-- Check one row per order and coverage of the joined sources.
SELECT
    COUNT(*) AS total_orders,
    COUNT(DISTINCT order_id) AS distinct_orders,
    SUM(CASE WHEN has_items THEN 1 ELSE 0 END) AS orders_with_items,
    SUM(CASE WHEN has_payments THEN 1 ELSE 0 END) AS orders_with_payments,
    COUNT(is_late) AS eligible_delivery_orders,
    COUNT(is_low_review) AS reviewed_orders,
    SUM(CASE WHEN is_late THEN 1 ELSE 0 END) AS late_orders
FROM order_analytics;

-- Compare each joined monetary total with its original CSV source.
-- No status filter: this reconciles the full source population.
SELECT
    SUM(merchandise_value) AS joined_merchandise_total,
    (SELECT SUM(CAST(price AS DECIMAL(18,2)))
     FROM read_csv_auto('data/raw/olist_order_items_dataset.csv'))
        AS source_merchandise_total,
    SUM(freight_value) AS joined_freight_total,
    (SELECT SUM(CAST(freight_value AS DECIMAL(18,2)))
     FROM read_csv_auto('data/raw/olist_order_items_dataset.csv'))
        AS source_freight_total,
    SUM(payment_value) AS joined_payment_total,
    (SELECT SUM(CAST(payment_value AS DECIMAL(18,2)))
     FROM read_csv_auto('data/raw/olist_order_payments_dataset.csv'))
        AS source_payment_total
FROM order_analytics;
