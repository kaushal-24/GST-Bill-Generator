#!/usr/bin/env bash
# L89 GST Bill Generator - functions (sourced by main.sh)
# All paths are relative to project root (main.sh changes to that directory).
DATA="data/items.csv"
DRAFT="data/draft.csv"
SALES="data/sales.csv"
COUNTER="data/invoice_counter.txt"
LOG="logs/activity.log"

log() {
    printf '%s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"
}

check_data() {
    if [[ ! -f "$DATA" || ! -r "$DATA" ]]; then
        echo "ERROR: Missing or unreadable product file: $DATA" >&2
        return 1
    fi
    if [[ ! -f "$SALES" || ! -w "$SALES" ]]; then
        echo "ERROR: Missing or unwritable sales file: $SALES" >&2
        return 1
    fi
}

check_bc() {
    if ! command -v bc >/dev/null 2>&1; then
        echo 'ERROR: bc is required. On Ubuntu: sudo apt update && sudo apt install bc' >&2
        return 1
    fi
}

# Exact-money calculations for nonnegative example prices; round half up to 2dp.
# Input values are validated before they reach bc.
round_money() {
    local result
    result="$(printf 'scale=6; v=(%s); v=v+0.005; scale=2; v/1\n' "$1" | bc)" || return 1
    [[ "$result" == .* ]] && result="0$result"
    printf '%s\n' "$result"
}

is_money() { [[ "$1" =~ ^[0-9]+([.][0-9]{1,2})?$ ]]; }
is_rate() { [[ "$1" =~ ^[0-9]+([.][0-9]{1,2})?$ ]] && [[ "$(printf 'scale=0; %s <= 100\n' "$1" | bc)" == 1 ]]; }
is_qty() { [[ "$1" =~ ^[1-9][0-9]{0,4}$ ]] && (( 10#$1 <= 10000 )); }

show_help() {
    cat <<'HELP'
L89 GST Bill Generator - Ubuntu / WSL Bash project
Usage: ./main.sh            interactive menu
       ./main.sh --help     print help
       ./main.sh --backup   backup project data and invoices
       ./main.sh --cron     save today's sales in reports/sales.txt
Menu: 1 Create draft  2 Calculate GST  3 Save invoice
      4 Today's sales 5 Search invoice 6 Products
      7 Backup 8 Activity log 0 Exit
HELP
}

view_data() {
    check_data || return 1
    echo '==================== PRODUCT CATALOG ===================='
    printf '%-7s %-25s %10s %8s\n' 'CODE' 'ITEM' 'PRICE(Rs)' 'GST %'
    while IFS=, read -r code name price gst; do
        [[ "$code" == code ]] && continue
        printf '%-7s %-25s %10s %8s\n' "$code" "$name" "$price" "$gst"
    done < "$DATA"
    log 'product catalog viewed'
}

# Resolve an item code against the trusted local catalog, not an internet service.
lookup_item() {
    local code="$1"
    awk -F',' -v k="$code" 'NR>1 && toupper($1)==toupper(k) { print; exit }' "$DATA"
}

has_draft() { [[ -s "$DRAFT" ]] && (( $(wc -l < "$DRAFT") > 1 )); }

# Feature 1: enter products and quantities into a pending invoice.
feature_1() {
    check_data || return 1
    echo '===== FEATURE 1: CREATE BILL (DRAFT) ====='
    if has_draft; then
        local answer
        read -r -p 'Replace existing unsaved draft? [y/N]: ' answer || return 1
        [[ "$answer" =~ ^[Yy]$ ]] || { echo 'Existing draft kept.'; return 0; }
    fi
    printf 'code,item,quantity,unit_price,gst_percent\n' > "$DRAFT" || return 1
    local code quantity record product_code item price rate extra count=0
    echo "Choose codes from option 6. Enter DONE when finished."
    while true; do
        read -r -p 'Item code (or DONE): ' code || break
        [[ "${code^^}" == DONE ]] && break
        if [[ ! "$code" =~ ^[A-Za-z0-9_-]{2,20}$ ]]; then
            echo 'Invalid code. Use catalog item codes such as I01.'
            continue
        fi
        record="$(lookup_item "$code")"
        if [[ -z "$record" ]]; then echo 'Item not found. Try again.'; continue; fi
        IFS=, read -r product_code item price rate extra <<< "$record"
        if ! is_money "$price" || ! is_rate "$rate"; then
            echo 'Invalid catalog price or GST rate; item ignored.'; continue
        fi
        read -r -p "Quantity for $item: " quantity || break
        if ! is_qty "$quantity"; then
            echo 'Quantity must be a whole number between 1 and 10000.'
            continue
        fi
        printf '%s,%s,%d,%s,%s\n' "$product_code" "$item" "$((10#$quantity))" "$price" "$rate" >> "$DRAFT" || return 1
        ((count+=1))
        echo "Added: $quantity x $item"
    done
    if ! has_draft; then
        rm -f -- "$DRAFT"
        echo 'No items added. Draft discarded.'
        log 'empty draft discarded'
    else
        echo "Draft saved with $count line item(s). Use option 2 to preview GST and option 3 to save the invoice."
        log "draft created with $count lines"
    fi
}

# Populates SUBTOTAL, GST_TOTAL, GRAND_TOTAL and LINE_ROWS (for later invoice save).
# bc is used for every financial calculation; GST is rounded for each line.
calculate_draft() {
    check_bc || return 1
    if ! has_draft; then echo 'No draft available. Use option 1 first.'; return 1; fi
    local code item quantity price rate base tax gross row
    SUBTOTAL='0.00'; GST_TOTAL='0.00'; GRAND_TOTAL='0.00'
    LINE_ROWS=()
    while IFS=, read -r code item quantity price rate; do
        [[ "$code" == code ]] && continue
        if ! is_qty "$quantity" || ! is_money "$price" || ! is_rate "$rate"; then
            echo "Invalid draft row for item $code. Recreate draft." >&2
            return 1
        fi
        base="$(round_money "$price * $quantity")" || return 1
        tax="$(round_money "$base * $rate / 100")" || return 1
        gross="$(round_money "$base + $tax")" || return 1
        SUBTOTAL="$(round_money "$SUBTOTAL + $base")" || return 1
        GST_TOTAL="$(round_money "$GST_TOTAL + $tax")" || return 1
        GRAND_TOTAL="$(round_money "$GRAND_TOTAL + $gross")" || return 1
        row="$(printf '%-6s %-20.20s %5s %9.2f %7s%% %10.2f %10.2f' "$code" "$item" "$quantity" "$price" "$rate" "$tax" "$gross")"
        LINE_ROWS+=("$row")
    done < "$DRAFT"
    (( ${#LINE_ROWS[@]} > 0 ))
}

show_calculation() {
    printf '\n%-6s %-20s %5s %9s %8s %10s %10s\n' CODE ITEM QTY PRICE 'GST%' TAX TOTAL
    printf '%s\n' '-------------------------------------------------------------------------------'
    printf '%s\n' "${LINE_ROWS[@]}"
    printf '%s\n' '-------------------------------------------------------------------------------'
    printf '%-57s Rs %10.2f\n' 'Taxable subtotal:' "$SUBTOTAL"
    printf '%-57s Rs %10.2f\n' 'GST total:' "$GST_TOTAL"
    printf '%-57s Rs %10.2f\n' 'Grand total:' "$GRAND_TOTAL"
}

# Feature 2: preview the bill; do not count it as a sale until option 3.
feature_2() {
    echo '===== FEATURE 2: GST & GRAND TOTAL (bc) ====='
    calculate_draft || return 1
    show_calculation
    log "draft calculated, preview total Rs $GRAND_TOTAL"
}

# Feature 3: save unique invoice number and register its sale once.
feature_3() {
    echo '===== FEATURE 3: SAVE INVOICE ====='
    check_data || return 1
    calculate_draft || return 1
    mkdir -p bills
    local count invoice number fname tmp stamp dateonly
    count="$(cat "$COUNTER" 2>/dev/null)"
    [[ "$count" =~ ^[0-9]+$ ]] || { echo 'Invoice counter is invalid.'; return 1; }
    number=$((10#$count + 1))
    invoice="$(printf 'INV-%06d' "$number")"
    fname="bills/${invoice}.txt"
    while [[ -e "$fname" ]]; do
        ((number+=1))
        invoice="$(printf 'INV-%06d' "$number")"
        fname="bills/${invoice}.txt"
    done
    stamp="$(date '+%Y-%m-%d %H:%M:%S')"
    dateonly="${stamp%% *}"
    tmp="$(mktemp bills/.invoice.XXXXXXXX)" || return 1
    {
        printf '%s\n' '======================================================='
        printf '                 GST BILL GENERATOR                    \n'
        printf '                SAMPLE SHOP INVOICE                   \n'
        printf '%s\n' '======================================================='
        printf 'Invoice: %s\nDate: %s\n' "$invoice" "$stamp"
        printf '%s\n' '-------------------------------------------------------'
        show_calculation
        printf '%s\n' '======================================================='
        printf 'Sample academic invoice, not a statutory tax invoice.\n'
    } > "$tmp" || { rm -f "$tmp"; return 1; }
    if ! mv -- "$tmp" "$fname"; then rm -f -- "$tmp"; return 1; fi
    if ! printf '%s,%s,%s,%s,%s,%s\n' "$invoice" "$dateonly" "$stamp" "$SUBTOTAL" "$GST_TOTAL" "$GRAND_TOTAL" >> "$SALES"; then
        rm -f -- "$fname"; return 1
    fi
    printf '%s\n' "$number" > "$COUNTER"
    rm -f -- "$DRAFT"
    printf 'Saved invoice: %s\n' "$fname"
    printf 'Invoice total: Rs %0.2f\n' "$GRAND_TOTAL"
    log "invoice $invoice saved; total Rs $GRAND_TOTAL"
}

# Extract one date's saved invoices. Populate COUNT, SALES_TOTAL.
daily_sales() {
    local day="$1" id date stamp base tax grand
    COUNT=0; SALES_TOTAL='0.00'
    check_bc || return 1
    while IFS=, read -r id date stamp base tax grand; do
        [[ "$id" == invoice ]] && continue
        if [[ "$date" == "$day" ]]; then
            if ! is_money "$grand"; then echo 'Invalid sales record.' >&2; return 1; fi
            SALES_TOTAL="$(round_money "$SALES_TOTAL + $grand")" || return 1
            ((COUNT+=1))
        fi
    done < "$SALES"
}

# Feature 4: summarize only saved invoices (not unsaved drafts).
feature_4() {
    echo "===== FEATURE 4: TODAY'S TOTAL SALES ====="
    check_data || return 1
    local day="$(date '+%Y-%m-%d')"
    daily_sales "$day" || return 1
    printf 'Date: %s\nInvoices: %d\nSales total: Rs %.2f\n' "$day" "$COUNT" "$SALES_TOTAL"
    log "today sales viewed: $COUNT invoices Rs $SALES_TOTAL"
}

# Feature 5: read only an exact invoice ID, no unsafe user-provided paths.
feature_5() {
    echo '===== FEATURE 5: SEARCH INVOICE ====='
    local inv file
    read -r -p 'Invoice ID (example INV-000001): ' inv || return 1
    inv="${inv^^}"
    if [[ ! "$inv" =~ ^INV-[0-9]{6,}$ ]]; then
        echo 'Invalid format. Example: INV-000001'
        return 1
    fi
    file="bills/${inv}.txt"
    if [[ -f "$file" ]]; then
        cat -- "$file"
        log "invoice $inv viewed"
    else
        echo "Invoice not found: $inv"
        log "invoice $inv not found"
    fi
}

do_backup() {
    mkdir -p backups
    local backup="backups/data_$(date +%Y%m%d_%H%M%S)_$$.tar.gz"
    if tar -czf "$backup" data/ bills/ reports/ logs/; then
        printf 'Backup created: %s\n' "$backup"
        ls -lh "$backup"
        log "backup created $backup"
    else
        echo 'Backup failed.' >&2
        rm -f -- "$backup"
        return 1
    fi
}

view_log() {
    echo '===== RECENT ACTIVITY ====='
    if [[ -s "$LOG" ]]; then tail -n 20 "$LOG"; else echo 'No activity yet.'; fi
}

# Cron task: snapshot today's sales into reports/sales.txt once per date.
# Called each day at 23:00, or manually: ./main.sh --cron.
cron_task() {
    check_data || return 1
    local day tmp line
    day="$(date '+%Y-%m-%d')"
    daily_sales "$day" || return 1
    mkdir -p reports logs
    line="${day} | invoices=${COUNT} | total=Rs ${SALES_TOTAL} | generated=$(date '+%H:%M:%S')"
    tmp="$(mktemp reports/.sales.XXXXXXXX)" || return 1
    if [[ -f reports/sales.txt ]]; then
        grep -v -F "${day} |" reports/sales.txt > "$tmp" || true
    fi
    printf '%s\n' "$line" >> "$tmp"
    sort -o "$tmp" "$tmp"
    mv -f -- "$tmp" reports/sales.txt
    printf '%s | daily report updated: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line" >> reports/cron_output.txt
    log "cron task: $line"
    printf 'Daily sales report written: %s\n' "$line"
}
