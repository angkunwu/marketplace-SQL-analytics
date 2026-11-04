"""Execute the repository SQL against isolated synthetic CSVs."""
import csv
import os
from decimal import Decimal
from pathlib import Path
import tempfile
import unittest

import duckdb

ROOT = Path(__file__).resolve().parents[1]


class SQLModelTests(unittest.TestCase):
    def setUp(self):
        self.previous_cwd = Path.cwd()
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.addCleanup(os.chdir, self.previous_cwd)
        os.chdir(self.temp.name)
        Path("data/raw").mkdir(parents=True)
        self.connection = duckdb.connect()
        self.addCleanup(self.connection.close)
        self.orders = [
            ["o1", "c1", "delivered", "2018-01-01", "2018-01-12 12:00:00", "2018-01-10 00:00:00"],
            ["o2", "c2", "delivered", "2018-01-02", "2018-01-10 23:00:00", "2018-01-10 00:00:00"],
            ["o3", "missing", "delivered", "2018-03-01", "", "2018-03-10 00:00:00"],
            ["o4", "c4", "canceled", "2018-04-01", "2018-04-12 00:00:00", "2018-04-10 00:00:00"],
            ["o5", "c5", "delivered", "2018-04-02", "2018-04-12 00:00:00", ""],
        ]
        self.write_orders()
        self.write_csv("order_items", ["order_id", "seller_id", "price", "freight_value"], [
            ["o1", "s1", "10.00", "1.00"], ["o1", "s2", "20.00", "2.00"],
            ["o1", "s1", "5.00", "0.50"], ["o2", "s1", "7.00", "1.00"],
        ])
        self.write_csv("order_payments", ["order_id", "payment_value"], [
            ["o1", "12.00"], ["o1", "26.50"], ["o2", "8.00"],
        ])
        self.write_csv("order_reviews", ["order_id", "review_id", "review_score", "review_answer_timestamp"], [
            ["o1", "old", 1, "2018-01-11 00:00:00"],
            ["o1", "b", 2, "2018-01-13 00:00:00"],
            ["o1", "a", 5, "2018-01-13 00:00:00"],
            ["o2", "r2", 4, "2018-01-11 00:00:00"],
        ])
        self.write_csv("customers", ["customer_id", "customer_state"], [
            ["c1", "SP"], ["c2", "RJ"], ["c4", ""], ["c5", "MG"],
        ])
        self.run_sql("order_analytics")

    def write_csv(self, name, headers, rows):
        with Path(f"data/raw/olist_{name}_dataset.csv").open("w", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(headers)
            writer.writerows(rows)

    def write_orders(self):
        self.write_csv("orders", [
            "order_id", "customer_id", "order_status", "order_purchase_timestamp",
            "order_delivered_customer_date", "order_estimated_delivery_date",
        ], self.orders)

    def run_sql(self, name):
        return self.connection.execute((ROOT / f"SQL/{name}.sql").read_text())

    def test_independent_aggregations_preserve_money_and_grain(self):
        rows = self.connection.execute(
            "SELECT order_id, item_count, seller_count, merchandise_value, freight_value, "
            "payment_value FROM order_analytics ORDER BY order_id"
        ).fetchall()
        self.assertEqual(len(rows), 5)
        self.assertEqual(len({row[0] for row in rows}), 5)
        self.assertEqual(rows[0], ("o1", 3, 2, Decimal("35.00"), Decimal("3.50"), Decimal("38.50")))
        self.assertEqual(self.connection.execute(
            "SELECT SUM(merchandise_value), SUM(freight_value), SUM(payment_value) FROM order_analytics"
        ).fetchone(), (Decimal("42.00"), Decimal("4.50"), Decimal("46.50")))

    def test_latest_review_and_deterministic_tie_break(self):
        self.assertEqual(self.connection.execute(
            "SELECT review_score, is_low_review FROM order_analytics WHERE order_id = 'o1'"
        ).fetchone(), (5, False))

    def test_missing_related_records_remain_visible(self):
        self.assertEqual(self.connection.execute(
            "SELECT has_items, has_payments, has_review, merchandise_value, payment_value, "
            "review_score, is_low_review FROM order_analytics WHERE order_id = 'o3'"
        ).fetchone(), (False, False, False, None, None, None, None))

    def test_delivery_eligibility_and_calendar_dates(self):
        self.assertEqual(self.connection.execute(
            "SELECT order_id, signed_delay_days, is_late FROM order_analytics ORDER BY order_id"
        ).fetchall(), [("o1", 2, True), ("o2", 0, False), ("o3", None, None),
                       ("o4", None, None), ("o5", None, None)])

    def test_regional_join_preserves_orders_and_flags_missing_states(self):
        self.run_sql("region_analytics")
        self.assertEqual(self.connection.execute(
            "SELECT COUNT(*), COUNT(DISTINCT order_id), SUM(merchandise_value) FROM order_region_analytics"
        ).fetchone(), (5, 5, Decimal("42.00")))
        checks = self.connection.extract_statements((ROOT / "SQL/check_region_analytics.sql").read_text())
        for index in [0, 1, 2, 5, 6]:
            self.assertEqual(self.connection.execute(checks[index].query).fetchall(), [])
        self.assertEqual({row[0] for row in self.connection.execute(checks[3].query).fetchall()}, {"o3", "o4"})
        self.assertEqual(self.connection.execute(checks[4].query).fetchone(), (Decimal("42.00"), Decimal("42.00")))

    def test_multi_seller_values_and_shared_outcomes(self):
        self.run_sql("order_seller_analytics")
        self.assertEqual(self.connection.execute(
            "SELECT seller_id, item_count, merchandise_value, is_late, review_score "
            "FROM order_seller_analytics WHERE order_id = 'o1' ORDER BY seller_id"
        ).fetchall(), [("s1", 2, Decimal("15.00"), True, 5), ("s2", 1, Decimal("20.00"), True, 5)])
        self.assertEqual(self.connection.execute(
            "SELECT COUNT(*), COUNT(DISTINCT (order_id, seller_id)), SUM(merchandise_value) "
            "FROM order_seller_analytics"
        ).fetchone(), (3, 3, Decimal("42.00")))

    def monthly_rows(self):
        cursor = self.run_sql("monthly_delivery_trends")
        names = [column[0] for column in cursor.description]
        return [dict(zip(names, row)) for row in cursor.fetchall()]

    def test_monthly_gaps_zero_denominators_and_population(self):
        rows = self.monthly_rows()
        self.assertEqual([row["purchase_month"].month for row in rows], [1, 3, 4])
        self.assertEqual(sum(row["total_orders"] for row in rows), 5)
        self.assertEqual(rows[0]["late_delivery_percentage"], 50.0)
        for row in rows[1:]:
            self.assertIsNone(row["late_delivery_percentage"])
            self.assertIsNone(row["month_over_month_change_pp"])
            self.assertFalse(row["meets_comparison_support"])
        # A gap between two eligible months still has an observed-row change,
        # but no consecutive-calendar-month change.
        self.orders[2][4] = "2018-03-09 00:00:00"
        self.write_orders()
        self.run_sql("order_analytics")
        march = self.monthly_rows()[1]
        self.assertEqual(march["change_from_previous_observed_pp"], -50.0)
        self.assertIsNone(march["month_over_month_change_pp"])
        self.assertFalse(march["meets_comparison_support"])

    def test_adjacent_month_support_threshold_and_changes(self):
        self.orders = []
        for month, late_count in [(1, 25), (2, 50)]:
            for index in range(100):
                self.orders.append([
                    f"m{month}_{index}", "c1", "delivered", f"2018-{month:02d}-01",
                    f"2018-{month:02d}-{12 if index < late_count else 10} 00:00:00",
                    f"2018-{month:02d}-10 00:00:00",
                ])
        self.write_orders()
        self.run_sql("order_analytics")
        january, february = self.monthly_rows()
        self.assertEqual(january["late_delivery_percentage"], 25.0)
        self.assertFalse(january["meets_comparison_support"])
        self.assertEqual(february["late_delivery_percentage"], 50.0)
        self.assertEqual(february["month_over_month_change_pp"], 25.0)
        self.assertTrue(february["meets_comparison_support"])
        self.orders.pop()
        self.write_orders()
        self.run_sql("order_analytics")
        self.assertFalse(self.monthly_rows()[1]["meets_comparison_support"])


if __name__ == "__main__":
    unittest.main()
