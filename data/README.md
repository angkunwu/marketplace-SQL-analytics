# Data source and local files

## Source and attribution

This project uses the **Brazilian E-Commerce Public Dataset by Olist**, published by Olist on Kaggle.

- Source: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
- Coverage described by the publisher: Brazilian marketplace orders from 2016–2018.
- Acquisition method: manual ZIP download from Kaggle, extracted into `data/raw/`.

Credit goes to Olist and the dataset contributors for making these data publicly available.

## Dataset license

The [Kaggle dataset page](https://www.kaggle.com/olistbr/brazilian-ecommerce/home/) lists **Creative Commons Attribution–NonCommercial–ShareAlike 4.0 International (CC BY-NC-SA 4.0)**.

See the [license terms](https://creativecommons.org/licenses/by-nc-sa/4.0/). The repository's MIT code license does not replace the dataset license. Raw CSVs are excluded from Git.

## Verified file inventory

Row counts exclude headers and were obtained by reading each file with DuckDB.

| File | Rows | Contents |
| --- | ---: | --- |
| `olist_customers_dataset.csv` | 99,441 | Customer identifiers and destination geography |
| `olist_geolocation_dataset.csv` | 1,000,163 | ZIP-code prefixes and geographic coordinates |
| `olist_order_items_dataset.csv` | 112,650 | Order line items, products, sellers, prices, and freight |
| `olist_order_payments_dataset.csv` | 103,886 | Payment records |
| `olist_order_reviews_dataset.csv` | 99,224 | Review scores, text, and timestamps |
| `olist_orders_dataset.csv` | 99,441 | Order statuses and lifecycle timestamps |
| `olist_products_dataset.csv` | 32,951 | Product categories and attributes |
| `olist_sellers_dataset.csv` | 3,095 | Seller identifiers and geography |
| `product_category_name_translation.csv` | 71 | Portuguese-to-English category names |

For the three reported analyses, download the orders, customers, items, payments,
and reviews CSVs. Other files support additional source exploration. Geolocation
is optional and is not used in the reported findings.

The exact acquisition date and publisher version were not recorded. The committed
[SHA-256 manifest](checksums.sha256) identifies the local extract used for this
analysis. From `data/raw/`, verify it with `shasum -a 256 -c ../checksums.sha256`
(or `sha256sum -c ../checksums.sha256` on Linux). The manifest lists all nine local
CSVs; all nine are required only for a complete manifest check.

## Initial profiling

The query in [profile_sources.sql](../SQL/profile_sources.sql), run from the repository root with `python run_duckdb.py` in the project's virtual environment, returns:

| Item rows | Distinct orders in items | Distinct sellers in items |
| ---: | ---: | ---: |
| 112,650 | 98,666 | 3,095 |

The item table has one row per order line item, not one row per order. An order can contain multiple items and sellers, so counting rows after joining orders to items can inflate an order count.

Initial checks found no duplicate key combinations for:

- Orders: `order_id`.
- Customers: `customer_id`.
- Order items: `(order_id, order_item_id)`.

The orders table has 99,441 rows, while items represent 98,666 distinct order IDs. The order model uses left joins to retain source orders without items. Automated checks reconcile source monetary totals and preserve the order population; see [validation](../docs/validation.md) for coverage and limits.

For repeat-customer analysis, use `customer_unique_id`; `customer_id` identifies the order-linked customer record. The order model aggregates payments and selects one review per order before joining.
