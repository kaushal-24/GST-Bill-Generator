# L89 - GST Bill Generator (Linux Shell Scripting)

**Student:** PITHVA KAUSHAL VIPULKUMAR  
**Roll:** F31 | **Division:** G | **Enrollment:** 24004501210313

## Project overview

A terminal-based academic billing application for small shops. It uses Bash scripts and
CSV/text files (no database required) to create bills, calculate example GST, store
unique numbered invoices, summarize today's confirmed sales, search previous invoices,
back up data, and maintain activity logs.

**Disclaimer:** Sample item tax percentages are coursework/demo data. They are not
verified current Indian tax classifications. This is not a statutory GST invoice or
a production-ready tax/accounting system: it does not collect the GSTIN, tax place
of supply, seller/buyer legal details, or other compliance fields. Do not use the
sample invoices as legal tax invoices.

## Project layout

```
gstbill/
  main.sh                Main menu / CLI entry point
  lib/functions.sh       Feature functions and scheduled task
  data/items.csv         18 sample products: code,item,price,gst_percent
  data/sales.csv         Confirmed invoices: invoice,date,timestamp,subtotal,gst,total
  data/invoice_counter.txt  Last saved numeric invoice sequence
  data/draft.csv         Temporary draft (created when billing)
  bills/                 Saved INV-000001.txt, INV-000002.txt, ...
  reports/sales.txt      Daily totals, created by --cron
  reports/cron_output.txt Manual/scheduled report history
  backups/               .tar.gz backup archives
  logs/activity.log      All major operations
  logs/cron.log          Output from actual cron entry
  tests/run_tests.sh     Automated functional test suite
  README.md              This guide
  CRON_GUIDE.md          Scheduler setup and testing
```

## Requirements

- Ubuntu, Debian, or Ubuntu on Windows 11 via WSL.
- GNU Bash, common GNU utilities (`awk`, `grep`, `sort`, `tar`, `find`, `date`, `ls`).
- GNU **bc** for currency calculation (`sudo apt update && sudo apt install -y bc`).
- Optional: `cron` for automated report generation (`sudo apt install -y cron`).
- Runs as a normal user in your home directory; do not use `sudo ./main.sh`.

## Installation

From a supplied submission tar.gz:

```bash
sudo apt update && sudo apt install -y bc cron
mkdir -p ~/linux_project
cd ~/linux_project
tar -xzf ~/Downloads/F31_L89_gstbill.tar.gz
cd gstbill
chmod +x main.sh tests/run_tests.sh
./main.sh
```

If you downloaded the **single-file** `setup_gstbill_complete.sh` instead:

```bash
bash ~/Downloads/setup_gstbill_complete.sh
cd ~/linux_project/gstbill
./main.sh
```

Installer refuses to replace an existing `~/linux_project/gstbill` directory.

## 5 required features (menu 1-5)

1. **Create draft bill**: Enter item codes and quantities. Items are looked up in
   `items.csv`. Input validation rejects invalid codes, missing items and invalid quantities.
   Enter `DONE` when finished. No sale is recorded until saved with option 3.
2. **Calculate GST and grand total using `bc`**: Calculate price x quantity,
   tax per line, and total with two-decimal rounding; preview the draft without saving.
   The sample catalog treats unit prices as **excluding GST**.
3. **Save bill**: Write a sequential `bills/INV-000001.txt`, append the totals to
   `data/sales.csv`, and clear the saved draft. Distinct invoice IDs are used.
4. **Today's sales**: Sum only saved invoice totals with today's local date; print
   the invoice count and the total amount.
5. **Search by invoice number**: Input an exact ID such as `INV-000001`; the saved
   bill is displayed if it exists, otherwise a clear error message is displayed.

**Additional menu options:** 6 view catalog; 7 archive project data; 8 view last
20 activity-log lines; 0 exit.

## Quick demo workflow

```bash
cd ~/linux_project/gstbill
./main.sh
# 6: see catalog, e.g. I01 Notebook 60.00 12%
# 1: create draft: I01 quantity 2, I02 quantity 3, then DONE
# 2: preview: subtotal Rs 150.00; GST Rs 19.80; total Rs 169.80
# 3: save INV-000001.txt
# 4: see today's saved sales
# 5: enter INV-000001 to view the invoice
# 7: create a .tar.gz backup
# 8: view activity log
```

### Data format

`items.csv` contains **18 sample item records plus the header row**.

| Column | Meaning | Example |
|---|---|---|
| `code` | Catalog code | `I01` |
| `item` | Item name (no commas) | `Notebook` |
| `price` | Unit price excluding tax, rupees | `60.00` |
| `gst_percent` | Percentage for illustration | `12` |

The sample catalog is intentionally simple; commas in item names are unsupported.
Invoices use per-line tax rounding. The application assumes a single-user lab
session and does not implement simultaneous cashier transaction locking.

## Command line and backups

```bash
./main.sh --help
./main.sh --backup
ls -lh backups/
tar -tzf backups/$(ls -t backups/ | head -1) | head
./main.sh --cron
cat reports/sales.txt
```

The `--backup` command archives `data/`, `bills/`, `reports/`, and `logs/`. Do not
extract untrusted third-party archives into sensitive directories.

## 11 project steps mapped to deliverables

1. Open the menu -> `main.sh`.
2. Inspect and expand CSV -> `data/items.csv` (18 items).
3. Create a bill -> `feature_1()` in `lib/functions.sh`.
4. Calculate GST -> `feature_2()` using `bc`.
5. Save invoice -> `feature_3()` and `bills/`.
6. Today's sales -> `feature_4()`.
7. Invoice search -> `feature_5()`.
8. Validation and logging -> `check_data()`, `is_qty()` and `log()`.
9. Backups and CLI options -> `do_backup()`, `--help` and `--backup`.
10. Cron -> `cron_task()`, `--cron` and `CRON_GUIDE.md`.
11. Submit tar.gz and PDF; collect real lab-system screenshots.

## How to test

```bash
cd ~/linux_project/gstbill
bash -n main.sh lib/functions.sh
./tests/run_tests.sh
```

The tests run on a temporary copy of the project, leaving your real project data
untouched. Requires installed `bc` on the computer where you run it.

## Crontab: daily sales report at 11:00 PM

See `CRON_GUIDE.md`. Use **user crontab** rather than `sudo crontab`:

```text
0 23 * * * /bin/bash $HOME/linux_project/gstbill/main.sh --cron >> $HOME/linux_project/gstbill/logs/cron.log 2>&1
```

The output in `reports/sales.txt` has one entry per calendar day. Running `--cron`
again on the same date replaces that day's entry instead of duplicating it.

## What I learned (example to adapt before submission)

I practiced creating Bash functions and menu-driven programs using `while`,
`read`, `case` and conditionals. I learned how to use `grep`, `awk`, `bc`,
`printf`, `date` and `ls` to validate data and generate bills. I created CSV
records, used `tar` for backups, and organized activity logs. I also learned how
`crontab` can trigger automatic jobs without requiring a graphical interface.

## Viva questions

1. What does `#!/usr/bin/env bash` mean? How is it related to `#!/bin/bash`?
2. What does `chmod +x main.sh` change?
3. Explain the `while` loop and `case` block in the menu.
4. Explain `while IFS=, read -r ...` for parsing CSV.
5. Why do we use `bc` instead of Bash integer arithmetic for GST amounts?
6. What does the `round_money()` function do?
7. What is the difference between `>` and `>>`?
8. What do `$0`, `$1`, `$?`, and `$#` mean?
9. What does `grep`, `awk`, `date`, and `ls` do in this project?
10. Why do we write an invoice only when the user chooses option 3?
11. What do `tar -czf` and `tar -tzf` do?
12. Explain all five fields of `0 23 * * *`.
13. How do `crontab -e` and `crontab -l` work?
14. How can you debug an error using `bash -x main.sh`?
15. What are the limitations of a local CSV-based billing program?

## Submission checklist

- [ ] Demonstrate options 1-8 on Ubuntu/WSL and capture screenshots.
- [ ] Check `wc -l data/items.csv` returns `19` (18 items + header).
- [ ] Run `./tests/run_tests.sh` successfully on Ubuntu with `bc` installed.
- [ ] Manually test `./main.sh --cron` and confirm reports/sales.txt.
- [ ] Install cron in user crontab and show `crontab -l` screenshot.
- [ ] Show `logs/cron.log` populated by the scheduled task (not just a manual call).
- [ ] Personalize the PDF report with **your actual Ubuntu terminal screenshots**.
- [ ] Package folder: `tar -czf F31_L89_gstbill.tar.gz gstbill/` from `~/linux_project`.
- [ ] Be prepared to explain and run all functions during viva.
