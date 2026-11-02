# Cron setup - L89 GST Bill Generator

## 1. Test the task before scheduling

```bash
cd ~/linux_project/gstbill
./main.sh --cron
cat reports/sales.txt
```

## 2. Enable cron, if needed

```bash
sudo apt update
sudo apt install -y bc cron
sudo service cron start
```

On WSL, ensure the Linux instance stays running when the job is due; an inactive
or shut-down WSL distribution will not run scheduled cron jobs.

## 3. Install user crontab

```bash
crontab -e
```

Append this *one line*:

```cron
0 23 * * * /bin/bash $HOME/linux_project/gstbill/main.sh --cron >> $HOME/linux_project/gstbill/logs/cron.log 2>&1
```

`0` = minute, `23` = hour (11 PM), and `* * *` = every day, month, weekday.
Cron follows the configured Linux timezone (`date` shows it).

## 4. Verify scheduler entry and output

```bash
crontab -l
cat ~/linux_project/gstbill/reports/sales.txt
cat ~/linux_project/gstbill/logs/cron.log
```

For a fast *real cron test*, temporarily change `0 23 * * *` to a minute or two
in the future, capture the scheduled result, and change it back to 11 PM.
Do not claim `crontab` ran simply because `./main.sh --cron` ran by hand.

## Screenshots required for college submission

- Terminal with `crontab -l` displaying the scheduled line.
- Terminal showing `logs/cron.log` after cron executed.
- Terminal showing `reports/sales.txt` for the generated sales report.

The starter package cannot pre-populate proof of an actual cron execution on
someone else's Ubuntu machine. Generate those screenshots on your own system.
