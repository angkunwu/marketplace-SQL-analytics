from pathlib import Path

import csv
import math
import os

import duckdb
import matplotlib
matplotlib.use("Agg")
import matplotlib.dates as mdates
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parent
MIN_ELIGIBLE = 100


def make_monthly_figure():
    # SQL source paths currently resolve relative to the repository root.
    connection = duckdb.connect()
    try:
        connection.execute(
            (ROOT / "SQL/order_analytics.sql").read_text()
        )
        result = connection.execute(
            (ROOT / "SQL/monthly_delivery_trends.sql").read_text()
        )
        columns = [column[0] for column in result.description]
        records = [
            dict(zip(columns, row))
            for row in result.fetchall()
        ]
    finally:
        connection.close()

    # Include missing calendar months so the line cannot bridge them.
    by_month = {
        record["purchase_month"]: record
        for record in records
    }
    months = []
    month = min(by_month)
    while month <= max(by_month):
        months.append(month)
        if month.month == 12:
            month = month.replace(year=month.year + 1, month=1)
        else:
            month = month.replace(month=month.month + 1)

    rates = []
    eligible_counts = []
    total_counts = []

    for month in months:
        record = by_month.get(month)
        if record is None:
            rates.append(float("nan"))
            eligible_counts.append(0)
            total_counts.append(0)
            continue

        eligible = record["eligible_delivery_orders"]
        rate = record["late_delivery_percentage"]
        rates.append(
            rate
            if eligible >= MIN_ELIGIBLE and rate is not None
            else float("nan")
        )
        eligible_counts.append(eligible)
        total_counts.append(record["total_orders"])

    fig, (rate_ax, volume_ax) = plt.subplots(
        2,
        1,
        figsize=(11, 7),
        sharex=True,
        gridspec_kw={"height_ratios": [2, 1]},
    )

    rate_ax.plot(
        months,
        rates,
        color="#176B87",
        marker="o",
        markersize=4,
        linewidth=1.8,
    )
    rate_ax.set_title(
        "Marketplace delivery reliability by purchase month",
        loc="left",
        pad=14,
    )
    rate_ax.set_ylabel("Late deliveries (%)")
    rate_ax.set_ylim(bottom=0)
    rate_ax.grid(axis="y", alpha=0.25)

    volume_ax.bar(
        months,
        total_counts,
        width=23,
        color="#D8DEE9",
        label="All orders",
    )
    volume_ax.bar(
        months,
        eligible_counts,
        width=23,
        color="#176B87",
        label="Eligible deliveries",
    )
    volume_ax.set_ylabel("Orders")
    volume_ax.set_xlabel("Purchase month")
    volume_ax.legend(frameon=False)
    volume_ax.grid(axis="y", alpha=0.2)
    volume_ax.set_axisbelow(True)

    volume_ax.xaxis.set_major_locator(
        mdates.MonthLocator(interval=3)
    )
    volume_ax.xaxis.set_major_formatter(
        mdates.DateFormatter("%b %Y")
    )
    plt.setp(
        volume_ax.get_xticklabels(),
        rotation=35,
        ha="right",
    )

    for ax in (rate_ax, volume_ax):
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)

    fig.text(
        0.08,
        0.025,
        "Source: Olist, Sep 2016–Oct 2018. Late = delivered after "
        "the estimated calendar date.\n"
        "Rate denominator: delivered orders with both delivery dates. "
        "Rates hidden when eligible n < 100.\n"
        "Missing months appear as gaps. Sparse boundary months and "
        "incomplete outcome coverage limit interpretation.",
        fontsize=8,
        color="#444444",
    )
    fig.tight_layout(rect=(0, 0.14, 1, 1))

    output = ROOT / "figures/monthly_delivery_reliability.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output, dpi=180, bbox_inches="tight")
    plt.close(fig)

    print(f"Saved: {output}")


def query_results(connection, file_name):
    """Run a SQL file and return its SELECT outputs as lists of dictionaries."""
    outputs = []
    for statement in connection.extract_statements((ROOT / file_name).read_text()):
        cursor = connection.execute(statement.query)
        names = [column[0] for column in cursor.description]
        rows = [dict(zip(names, row)) for row in cursor.fetchall()]
        if rows:
            outputs.append(rows)
    return outputs


def select_output(outputs, required):
    matches = [rows for rows in outputs if required <= rows[0].keys()]
    if len(matches) != 1:
        raise ValueError(f"Expected one SQL result containing {required}, found {len(matches)}")
    return matches[0]


def export_results(name, rows):
    path = ROOT / "reports" / "results" / f"{name}.csv"
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def wilson_interval(successes, total):
    """95% Wilson binomial interval, in percentage units."""
    if total <= 0 or not 0 <= successes <= total:
        raise ValueError("A binomial interval requires 0 <= successes <= total and total > 0")
    z = 1.959963984540054
    p = successes / total
    denominator = 1 + z * z / total
    center = (p + z * z / (2 * total)) / denominator
    half = z * math.sqrt(p * (1 - p) / total + z * z / (4 * total * total)) / denominator
    return 100 * p, 100 * max(0, center - half), 100 * min(1, center + half)


def style_axis(ax):
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.set_axisbelow(True)
    ax.grid(axis="y", alpha=0.2)


def save_figure(fig, name, footer):
    fig.text(0.08, 0.025, footer, fontsize=8, color="#444444", va="bottom")
    fig.tight_layout(rect=(0, 0.16, 1, 0.94))
    path = ROOT / "figures" / name
    path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(path, dpi=180, bbox_inches="tight")
    plt.close(fig)
    print(f"Saved: {path}")


def make_review_figure(bands, all_reviews, post_delivery):
    fig, axes = plt.subplots(1, 2, figsize=(13, 6.5))
    fig.suptitle("Low review scores are associated with delivery delay; review timing matters", y=0.97)
    ax = axes[0]
    for x, row in enumerate(bands):
        value, low, high = wilson_interval(row["low_review_orders"], row["reviewed_orders"])
        ax.errorbar(x, value, yerr=[[value - low], [high - value]],
                    fmt="o", color="#176B87", capsize=4, markersize=7)
        ax.text(x, high + 4, f"{value:.1f}%", ha="center", fontsize=9)
    ax.set_xticks(range(len(bands)), [
        row["delay_band"].replace("On time or early", "On time\nor early")
        + f"\nn={row['reviewed_orders']:,}" for row in bands
    ])
    ax.set_title("All selected reviews, by delay band", fontsize=11)
    ax.set_ylabel("Low reviews among reviewed orders (%)")
    ax.set_ylim(0, 100)
    ax.set_xlim(-0.5, len(bands) - 0.5)
    ax = axes[1]
    for offset, rows, color, label in [
        (-0.12, all_reviews, "#176B87", "All selected reviews"),
        (0.12, post_delivery, "#C36A31", "Answered at/after delivery"),
    ]:
        for row in rows:
            x = int(row["is_late"]) + offset
            value, low, high = wilson_interval(row["low_review_orders"], row["reviewed_orders"])
            ax.errorbar(x, value, yerr=[[value - low], [high - value]], fmt="o",
                        color=color, capsize=4, markersize=7,
                        label=label if not row["is_late"] else None)
            ax.annotate(f"{value:.1f}%\nn={row['reviewed_orders']:,}",
                        (x, high), xytext=(0, 9), textcoords="offset points",
                        ha="center", fontsize=8, color=color)
    ax.set_xticks([0, 1], ["On time or early", "Late"])
    ax.set_xlim(-0.5, 1.5)
    ax.set_ylim(0, 100)
    ax.set_title("Timing sensitivity: different review populations", fontsize=11)
    ax.legend(loc="upper left", frameon=False, fontsize=8)
    for ax in axes:
        style_axis(ax)
    save_figure(fig, "review_outcomes.png",
        "Source: Olist, purchases Sep 2016–Oct 2018. Low review = score 1–2; n = reviewed eligible orders.\n"
        "One selected review per order. Bars show 95% Wilson intervals under an independent-order binomial model.\n"
        "Intervals omit seller/time clustering and selection bias. Timing restriction changes the population; associations are not causal.")


def make_region_figure(regions):
    fig, (scatter, counts) = plt.subplots(1, 2, figsize=(12, 6.5))
    fig.suptitle("Regional investigation priorities differ by rate and volume", y=0.97)
    for row in regions:
        value, low, high = wilson_interval(row["late_orders"], row["eligible_delivery_orders"])
        x = row["eligible_delivery_orders"]
        scatter.errorbar(x, value, yerr=[[value - low], [high - value]],
                         fmt="o", color="#176B87", alpha=0.7, capsize=2, markersize=4)
        if row["customer_state"] in {"SP", "RJ", "AL", "MA", "SE"}:
            scatter.annotate(row["customer_state"], (x, value), xytext=(5, 5),
                             textcoords="offset points", fontsize=9)
    scatter.set_xscale("log")
    scatter.set_xlabel("Eligible deliveries (log scale)")
    scatter.set_ylabel("Late deliveries (%)")
    scatter.set_title("Rate versus eligible order volume", fontsize=11)
    scatter.set_ylim(bottom=0)
    ordered = sorted(regions, key=lambda row: (-row["late_orders"], row["customer_state"]))
    top = ordered[:8]
    counts.barh([row["customer_state"] for row in top],
                [row["late_orders"] for row in top], color="#176B87")
    counts.invert_yaxis()
    for i, row in enumerate(top):
        counts.text(row["late_orders"] + 20, i, f"{row['late_orders']:,}", va="center", fontsize=9)
    counts.set_xlim(0, max(row["late_orders"] for row in top) * 1.23)
    counts.set_xlabel("Late orders")
    total = sum(row["late_orders"] for row in regions)
    top_count = sum(row["late_orders"] for row in top)
    counts.set_title(f"Top eight: {100 * top_count / total:.2f}% of qualifying late orders", fontsize=11)
    for ax in (scatter, counts):
        style_axis(ax)
    save_figure(fig, "regional_priorities.png",
        "Source: Olist, purchases Sep 2016–Oct 2018. Only destination states with at least 100 eligible deliveries.\n"
        "Left: 95% Wilson intervals under an independent-order binomial model; seller/time clustering is not included.\n"
        "Right: denominator for the share is late orders across qualifying states. Destination state does not identify responsibility.")


def main():
    # Existing SQL paths refer to data/raw relative to this repository.
    os.chdir(ROOT)
    make_monthly_figure()
    connection = duckdb.connect()
    try:
        connection.execute((ROOT / "SQL/order_analytics.sql").read_text())
        connection.execute((ROOT / "SQL/region_analytics.sql").read_text())
        monthly = query_results(connection, "SQL/monthly_delivery_trends.sql")[0]
        reviews = query_results(connection, "SQL/review_outcomes.sql")
        bands = select_output(reviews, {"delay_band"})
        all_reviews = select_output(reviews, {"is_late", "review_coverage_percentage"})
        post_delivery = next(rows for rows in reviews if set(rows[0]) == {
            "is_late", "reviewed_orders", "low_review_orders", "low_review_percentage"
        })
        regional_outputs = query_results(connection, "SQL/practice_region_analytics.sql")
        regions = select_output(regional_outputs, {
            "customer_state", "total_orders", "eligible_delivery_orders", "late_orders"
        })
        for name, rows in [("monthly_delivery_trends", monthly),
                           ("review_delay_bands", bands), ("review_all", all_reviews),
                           ("review_at_or_after_delivery", post_delivery),
                           ("regional_delivery", regions)]:
            export_results(name, rows)
        make_review_figure(bands, all_reviews, post_delivery)
        make_region_figure(regions)
    finally:
        connection.close()


if __name__ == "__main__":
    main()
