#!/usr/bin/env bash
# L89 - GST Bill Generator (menu-driven Bash project)
cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1
source lib/functions.sh
mkdir -p bills backups reports logs

case "${1:-}" in
    --help) show_help; exit 0 ;;
    --backup) do_backup; exit $? ;;
    --cron) cron_task; exit $? ;;
    '') ;;
    *) echo "Unknown argument: $1" >&2; show_help; exit 2 ;;
esac

while true; do
    echo
    echo '================ GST BILL GENERATOR By Kaushal ================'
    echo ' 1) Create a bill by entering item codes and quantities'
    echo ' 2) Calculate GST and grand total with bc'
    echo ' 3) Save each bill as bills/INV-<number>.txt' 
    echo " 4) Show today's total sales"
    echo ' 5) Search a bill by invoice number'
    echo ' 6) View item catalog'
    echo ' 7) Backup data (tar.gz)'
    echo ' 8) View activity log'
    echo ' 0) Exit'
    if ! read -r -p 'Choose an option: ' ch; then
        echo; break
    fi
    case "$ch" in
        1) feature_1 ;;
        2) feature_2 ;;
        3) feature_3 ;;
        4) feature_4 ;;
        5) feature_5 ;;
        6) view_data ;;
        7) do_backup ;;
        8) view_log ;;
        0) echo 'Goodbye!'; break ;;
        *) echo 'Invalid choice. Select a number from 0 to 8.' ;;
    esac
done
