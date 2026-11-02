#!/usr/bin/env bash
# Test runner: uses a disposable copy, never mutates the submission project.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
command -v bc >/dev/null || { echo 'Install bc before running tests.'; exit 1; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
tar -C "$ROOT/.." -cf - "$(basename "$ROOT")" | tar -C "$TMP" -xf -
cd "$TMP/$(basename "$ROOT")"
rm -f data/draft.csv reports/sales.txt reports/cron_output.txt
: > logs/activity.log
: > logs/cron.log

printf '1\nI01\n2\nI02\n3\nDONE\n2\n3\n4\n5\nINV-000001\n6\n7\n8\n0\n' | ./main.sh > "$TMP/session.txt"
grep -q 'Draft saved with 2 line item(s)' "$TMP/session.txt"
grep -q 'Rs *169.80' "$TMP/session.txt"
grep -q 'Saved invoice: bills/INV-000001.txt' "$TMP/session.txt"
grep -q 'Invoices: 1' "$TMP/session.txt"
grep -q 'Invoice: INV-000001' bills/INV-000001.txt
grep -q '^INV-000001,' data/sales.csv
[[ "$(cat data/invoice_counter.txt)" == '1' ]]
[[ "$(find backups -maxdepth 1 -name '*.tar.gz' | wc -l)" -ge 1 ]]

./main.sh --cron > "$TMP/cron_once.txt"
./main.sh --cron > "$TMP/cron_twice.txt"
[[ "$(grep -c "$(date +%Y-%m-%d) |" reports/sales.txt)" == 1 ]]
grep -q 'total=Rs 169.80' reports/sales.txt

# Failure-path coverage and the second invoice sequence.
printf '1\nINVALID\nI05\n0\nI01\n1\nDONE\n3\n5\n../foo\n0\n' | ./main.sh > "$TMP/invalid.txt"
grep -q 'Item not found' "$TMP/invalid.txt"
grep -q 'Quantity must be a whole number' "$TMP/invalid.txt"
grep -q 'Saved invoice: bills/INV-000002.txt' "$TMP/invalid.txt"
grep -q 'Invalid format' "$TMP/invalid.txt"
[[ -f bills/INV-000002.txt ]]

# Verify archives and CLI argument handling.
./main.sh --backup > "$TMP/backup.txt"
for archive in backups/*.tar.gz; do tar -tzf "$archive" >/dev/null; done
./main.sh --help | grep -q -- '--cron'
if ./main.sh --badflag > "$TMP/badflag.txt" 2>&1; then
    echo 'Unknown CLI argument unexpectedly succeeded.' >&2
    exit 1
fi
printf 'PASS: menu, draft, GST, invoice save/search, sales, backup, logs, input validation, cron idempotency and CLI flags\n'
