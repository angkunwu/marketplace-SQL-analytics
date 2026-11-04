"""Validate current full-data results; failures raise exceptions and exit nonzero."""
from pathlib import Path
import os

import duckdb

ROOT = Path(__file__).resolve().parent


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def main():
    os.chdir(ROOT)
    c = duckdb.connect()
    try:
        for name in ["order_analytics", "region_analytics"]:
            c.execute((ROOT / f"SQL/{name}.sql").read_text())
        statements = c.extract_statements((ROOT / "SQL/check_region_analytics.sql").read_text())
        require(len(statements) == 7, "Regional check contract changed: expected seven queries")
        for number, statement in enumerate(statements, 1):
            rows = c.execute(statement.query).fetchall()
            if number == 5:
                require(len(rows) == 1 and rows[0][0] is not None and rows[0][0] == rows[0][1],
                        "Regional merchandise totals differ")
            else:
                require(not rows, f"Regional check {number} returned failures")
        checks = c.extract_statements((ROOT / "SQL/check_order_analytics.sql").read_text())
        summary = c.execute(checks[0].query).fetchone()
        require(summary[0] == summary[1], "Order IDs are duplicated")
        money = c.execute(checks[1].query).fetchone()
        require(all(money[i] == money[i + 1] for i in range(0, len(money), 2)),
                "Order monetary totals differ from CSV sources")
        cur = c.execute((ROOT / "SQL/monthly_delivery_trends.sql").read_text())
        names = [col[0] for col in cur.description]
        months = [dict(zip(names, row)) for row in cur.fetchall()]
        require(len({r["purchase_month"] for r in months}) == len(months), "Duplicate monthly rows")
        require(sum(r["total_orders"] for r in months) == summary[0], "Monthly population differs")
        require(sum(r["eligible_delivery_orders"] for r in months) == summary[4], "Monthly eligibility differs")
        require(sum(r["late_orders"] for r in months) == summary[6], "Monthly late total differs")
        previous = None
        for row in months:
            n, k, total = (row[key] for key in ["eligible_delivery_orders", "late_orders", "total_orders"])
            require(0 <= k <= n <= total, "Invalid monthly counts")
            rate = row["late_delivery_percentage"]
            require(rate is None if n == 0 else abs(rate - 100 * k / n) <= 0.00501,
                    "Incorrect monthly rate or zero-denominator behavior")
            adjacent = previous is not None and (
                (row["purchase_month"].year - previous["purchase_month"].year) * 12
                + row["purchase_month"].month - previous["purchase_month"].month == 1)
            supported = bool(adjacent and n >= 100 and previous["eligible_delivery_orders"] >= 100)
            require(row["meets_comparison_support"] == supported, "Incorrect support flag")
            if not adjacent:
                require(row["month_over_month_change_pp"] is None, "Calendar gap has a monthly change")
            previous = row
        print(f"PASS: seven regional checks, order reconciliation, and {len(months)} monthly rows")
    finally:
        c.close()


if __name__ == "__main__":
    main()
