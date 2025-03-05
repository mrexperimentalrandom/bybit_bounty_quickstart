#!/bin/bash

# Script Name: LazarusTrackerRandom.sh
# Purpose: Track 10 random unique addresses from Bybit Lazarus Bounty files from the other script, you should have lots of addresses saved now
# Requirements: Kali Linux Rolling, curl, jq, shuf

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RESET='\033[0m'

WORKING_DIR="./lazarus_bounty_lite"
OUTPUT_DIR="$WORKING_DIR/tracking_random"

usage() {
    echo -e "${BLUE}Usage: $0 [-d <directory>]${RESET}"
    echo "  -d  Directory with address files (default: ./lazarus_bounty_lite)"
    exit 1
}

while getopts "d:" opt; do
    case $opt in
        d) WORKING_DIR="$OPTARG";;
        ?) usage;;
    esac
done

if [ ! -d "$WORKING_DIR" ] || [ ! -f "$WORKING_DIR/eth_addresses.txt" ]; then
    echo -e "${RED}[!] Directory $WORKING_DIR not found or missing address files${RESET}"
    echo -e "${BLUE}[*] Run LazarusBountyLite.sh first${RESET}"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
echo -e "${GREEN}[+] Tracking results will be saved to $OUTPUT_DIR${RESET}"

select_random_addresses() {
    echo -e "${BLUE}[*] Selecting 10 random unique addresses${RESET}"
    > "$OUTPUT_DIR/all_addresses.txt"
    [ -s "$WORKING_DIR/eth_addresses.txt" ] && sed 's/^/ETH:/' "$WORKING_DIR/eth_addresses.txt" >> "$OUTPUT_DIR/all_addresses.txt"
    [ -s "$WORKING_DIR/btc_addresses.txt" ] && sed 's/^/BTC:/' "$WORKING_DIR/btc_addresses.txt" >> "$OUTPUT_DIR/all_addresses.txt"
    [ -s "$WORKING_DIR/bsc_addresses.txt" ] && sed 's/^/BSC:/' "$WORKING_DIR/bsc_addresses.txt" >> "$OUTPUT_DIR/all_addresses.txt"
    [ -s "$WORKING_DIR/arbi_addresses.txt" ] && sed 's/^/ARBI:/' "$WORKING_DIR/arbi_addresses.txt" >> "$OUTPUT_DIR/all_addresses.txt"

    total_addresses=$(wc -l < "$OUTPUT_DIR/all_addresses.txt")
    if [ $total_addresses -lt 1 ]; then
        echo -e "${RED}[!] No addresses found${RESET}"
        exit 1
    fi
    if [ $total_addresses -lt 10 ]; then
        echo -e "${YELLOW}[!] Only $total_addresses addresses available, using all${RESET}"
        cp "$OUTPUT_DIR/all_addresses.txt" "$OUTPUT_DIR/selected_addresses.txt"
    else
        shuf -n 10 "$OUTPUT_DIR/all_addresses.txt" > "$OUTPUT_DIR/selected_addresses.txt"
    fi
    echo -e "${GREEN}[+] Selected $(wc -l < "$OUTPUT_DIR/selected_addresses.txt") unique addresses${RESET}"
}

track_transactions() {
    echo -e "${BLUE}[*] Tracking recent transactions${RESET}"
    while IFS= read -r line; do
        chain=$(echo "$line" | cut -d':' -f1)
        address=$(echo "$line" | cut -d':' -f2-)
        case $chain in
            "ETH") chain_api="ethereum"; chain_name="ETH"; divisor=1000000000000000000;;
            "BTC") chain_api="bitcoin"; chain_name="BTC"; divisor=1;;  # BTC values are already in BTC
            "BSC") chain_api="binance-smart-chain"; chain_name="BSC"; divisor=1000000000000000000;;
            "ARBI") chain_api="arbitrum"; chain_name="ARBI"; divisor=1000000000000000000;;
            *) continue;;
        esac

        echo -e "${YELLOW}[+] Checking $chain_name: $address${RESET}"
        curl -s "https://api.blockchair.com/$chain_api/dashboards/address/$address?limit=5" > "$OUTPUT_DIR/${chain}_${address}.json"
        if [ $? -eq 0 ] && jq -e '.data' "$OUTPUT_DIR/${chain}_${address}.json" > /dev/null 2>&1; then
            tx_count=$(jq '.data["'"$address"'"].address.transaction_count' "$OUTPUT_DIR/${chain}_${address}.json")
            echo -e "${GREEN}  - Total transactions: $tx_count${RESET}"

            if [ "$chain" = "BTC" ]; then
                jq -r '.data["'"$address"'"].transactions[]' "$OUTPUT_DIR/${chain}_${address}.json" | while IFS= read -r tx_hash; do
                    curl -s "https://api.blockchair.com/$chain_api/raw/transaction/$tx_hash" > "$OUTPUT_DIR/${chain}_${address}_${tx_hash}.json"
                    if jq -e '.data["'"$tx_hash"'"]' "$OUTPUT_DIR/${chain}_${address}_${tx_hash}.json" > /dev/null 2>&1; then
                        time=$(jq -r '.data["'"$tx_hash"'"].decoded_raw_transaction.time' "$OUTPUT_DIR/${chain}_${address}_${tx_hash}.json")
                        value=$(jq -r '[.data["'"$tx_hash"'"].decoded_raw_transaction.vout[].value] | add / '"$divisor"' | tostring + " '"$chain_name"'"' "$OUTPUT_DIR/${chain}_${address}_${tx_hash}.json")
                        echo -e "    $time | $tx_hash | $value"
                    fi
                done
            else
                if jq -e '.data["'"$address"'"].transactions' "$OUTPUT_DIR/${chain}_${address}.json" > /dev/null 2>&1 && \
                   [ "$(jq '.data["'"$address"'"].transactions | length' "$OUTPUT_DIR/${chain}_${address}.json")" -gt 0 ]; then
                    jq -r '.data["'"$address"'"].transactions[] | [.time, .hash, (.value / '"$divisor"' | tostring + " '"$chain_name"'")] | join(" | ")' \
                        "$OUTPUT_DIR/${chain}_${address}.json" | while IFS= read -r tx; do
                        echo -e "    $tx"
                    done
                else
                    echo -e "${RED}  - No recent transactions available${RESET}"
                fi
            fi
        else
            echo -e "${RED}  - API error or no data${RESET}"
        fi
    done < "$OUTPUT_DIR/selected_addresses.txt"
}

echo -e "${GREEN}[+] Starting Lazarus Random Tracker${RESET}"
select_random_addresses
track_transactions

echo -e "${YELLOW}===== Next Steps ====${RESET}"
echo -e "${BLUE}1. Review:${RESET} Check $OUTPUT_DIR/*.json for full data."
echo -e "${BLUE}2. Investigate:${RESET} See $OUTPUT_DIR/selected_addresses.txt for tracked addresses."
echo -e "${BLUE}3. Report:${RESET} Submit active addresses to lazarusbounty.com if funds move."
echo -e "${YELLOW}===================${RESET}"

echo -e "${GREEN}[+] Tracking complete!${RESET}"

