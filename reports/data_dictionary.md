# Analytical data dictionary

## Models and grain

| Model | Grain and key | Construction |
| --- | --- | --- |
| `order_analytics` | One row per `order_id` | All source orders; separately aggregate items/payments; select one review |
| `order_region_analytics` | One row per `order_id` | Left join order-linked customer ID to customer destination state |
| `order_seller_summary` / `order_seller_analytics` | One row per `(order_id, seller_id)` | Aggregate actual seller item values; attach shared order outcomes |
| Monthly result | One row per observed purchase month | Aggregate the full order population by purchase timestamp |

Temporary views last only for the current DuckDB connection. `customer_id` is the
order-linked customer identifier; `customer_unique_id` is the persistent customer identifier.
Seller delivery/review outcomes are shared order outcomes on multi-seller orders;
summing seller order counts does not give unique marketplace orders.

## Measures and coverage

| Field | Definition |
| --- | --- |
| `merchandise_value` | Sum of item prices, decimal with two fractional digits; no status filter in reconciliation |
| `freight_value` | Sum of item freight charges, separate from merchandise |
| `payment_value` | Sum of payment records per order, separate from item values |
| `signed_delay_days` | Actual delivery calendar date minus estimated delivery calendar date, for delivered status with both dates; otherwise null |
| `is_late` | Signed delay > 0; false includes early/same-day delivery; null means ineligible |
| `review_score` | Selected review score; latest answer timestamp, then review ID ascending for ties |
| `is_low_review` | Selected score <= 2; null for missing score |
| `has_items`, `has_payments`, `has_review` | Whether the corresponding source record exists |
| `has_actual_delivery_date`, `has_estimated_delivery_date` | Timestamp coverage indicators |
| `customer_state` | Customer destination state; not seller location or a carrier route |
| `eligible_delivery_orders` | Count of non-null `is_late`, including both true and false |
| `late_delivery_percentage` | 100 × late orders / eligible deliveries; null for a zero denominator |
| `eligible_order_percentage` | 100 × eligible deliveries / all orders purchased that month |
| Low-review percentage | 100 × low-score orders / reviewed orders in the specified eligible subset |
| Review coverage | 100 × reviewed orders / eligible orders in the specified group |
| `previous_observed_late_percentage` | Rate on the previous observed monthly row, including null values |
| `change_from_previous_observed_pp` | Current minus previous observed rate, in percentage points |
| `month_over_month_change_pp` | Same difference only when months are adjacent; otherwise null |
| `meets_comparison_support` | Adjacent months, each with at least 100 eligible deliveries |

All date, delivery, and review outcomes are retrospective analysis fields. They
must not be used as purchase-time predictive features. Monthly rate calculations
remain unrounded until presentation. Source months with no orders are absent
from SQL output and inserted as plot gaps by Python; zero eligible deliveries
also give no rate. Regional plots require at least 100 eligible deliveries;
state review comparisons require at least 30 reviewed orders in each group.

The reporting generator exports source SQL result tables into `reports/results/`.
Uncertainty intervals are computed from integer counts in Python using the 95%
Wilson formula, with assumptions described in the findings report.
