-- Reusable regional model: one row per order with destination state.
-- Run after SQL/order_analytics.sql on the same DuckDB connection.

CREATE OR REPLACE TEMP VIEW order_region_analytics AS 
SELECT
    o.*,
    c.customer_state
FROM order_analytics AS o
LEFT JOIN read_csv_auto('data/raw/olist_customers_dataset.csv') AS c
    ON o.customer_id = c.customer_id;
