DESCRIBE
SELECT *
FROM read_csv_auto('data/raw/olist_orders_dataset.csv');

-- Check delivery-date coverage for each order status
SELECT
    order_status,
    COUNT(*) AS order_count,
    COUNT(*) - COUNT(order_delivered_customer_date)
        AS missing_actual_delivery_dates,
    COUNT(*) - COUNT(order_estimated_delivery_date)
        AS missing_estimated_delivery_dates
FROM read_csv_auto('data/raw/olist_orders_dataset.csv')
GROUP BY order_status
ORDER BY order_count DESC;