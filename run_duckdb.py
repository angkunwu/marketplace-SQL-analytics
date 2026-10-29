from pathlib import Path
import duckdb
import argparse

def show_result(cursor):
    headers = [column[0] for column in cursor.description]
    rows = [
        [str(value) if value is not None else "NULL" for value in row]
        for row in cursor.fetchall()
    ]
    widths = [
        max(len(row[index]) for row in [headers, *rows])
        for index in range(len(headers))
    ]

    def format_row(row):
        return " | ".join(value.ljust(width) for value, width in zip(row, widths))

    print(format_row(headers))
    print("-+-".join("-" * width for width in widths))
    for row in rows:
        print(format_row(row))

#file_name = "SQL/delivery_reliability.sql" #"SQL/profile_sources.sql"
parser = argparse.ArgumentParser(description="Run a SQL file with DuckDB.")
parser.add_argument("file_name", help="Path to the SQL file to run (no quotes)")
args = parser.parse_args()

file_name = args.file_name
sql = Path(file_name).read_text()
connection = duckdb.connect()

try:
    for number, statement in enumerate(connection.extract_statements(sql), start=1):
        print(f"\nQuery {number}:")
        show_result(connection.execute(statement.query))
finally:
    connection.close()
