# Validation

## Local synthetic tests

```bash
.venv/bin/python -m unittest discover -s tests -v
```

After installing the dependencies from `requirements.txt`, run the command above from the repository root. Tests generate small, explicitly synthetic CSVs in a temporary directory and execute the repository SQL unchanged, resolving its relative source paths against those fixtures. They require DuckDB but no downloaded data. Each test gets an isolated connection and fixture directory.

Coverage includes:

- Multiple items and payments on the same order: exact merchandise, freight, and payment totals without fan-out.
- Multiple reviews: latest timestamp selection and review-ID tie-breaking.
- Absent items, payments, and reviews: source order retained with null values and false coverage flags.
- Missing actual or estimated dates, canceled status, and same-day delivery: correct eligibility and calendar-date behavior.
- Missing customer match and null state: orders retained; the existing regional missing-state check identifies them.
- Multiple sellers: distinct order-seller grain, actual seller values, shared order outcomes.
- Missing calendar month and zero eligible deliveries: null rates, changes, and support flags.
- Adjacent months at the 100-delivery support threshold: expected rates, percentage-point changes, and support flags.

These targeted checks cover selected transformation contracts; they do not exhaust every possible source anomaly.

## Full-data checks

```bash
.venv/bin/python validate_analysis.py
```

Checks seven regional query results, order uniqueness, source monetary reconciliation, monthly population/eligibility/late-count reconciliation, rates, and comparison support flags. A failure exits nonzero. The current dataset has no missing destination states; the synthetic fixture intentionally includes them and verifies detection rather than treating them as acceptable in the full-data release.

## Reproduction check

Verified on 2026-11-04 using a separate Python 3.11.6 environment installed from `requirements.txt` on macOS ARM64. All eight synthetic tests and the full-data checks passed in a clean copy of the public files, with raw CSVs supplied through a local directory link. Figure generation and the documented monthly display command succeeded; all five exported CSVs matched the existing result tables byte for byte. The three rendered charts were visually inspected for labels and layout. See the [installed package versions](tested_environment.txt).

The raw-data download requires manual access to the dataset publisher. Local file hashes in `data/checksums.sha256` identify the analyzed extract; they do not establish a publisher version or download date.
