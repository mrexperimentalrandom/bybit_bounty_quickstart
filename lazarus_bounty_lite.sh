#!/bin/bash

# Script Name: LazarusBountyLite.sh
# Purpose: Fetch and display Bybit Lazarus Bounty hacker addresses in a simple, readable format
# Requirements: Kali Linux Rolling, curl, jq

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# Default output directory
OUTPUT_DIR="./lazarus_bounty_lite"

# Usage function
usage() {
    echo -e "${BLUE}Usage: $0 [-o <output_dir>]${RESET}"
    echo "  -o  Output directory (default: ./lazarus_bounty_lite)"
    exit 1
}

# Parse arguments
while getopts "o:" opt; do
    case $opt in
        o) OUTPUT_DIR="$OPTARG";;
        ?) usage;;
    esac
done

# Create output directory
mkdir -p "$OUTPUT_DIR"
echo -e "${GREEN}[+] Output will be saved to $OUTPUT_DIR${RESET}"

# Function to fetch hacker addresses
fetch_hacker_addresses() {
    echo -e "${BLUE}[*] Fetching hacker addresses from Bybit HackBounty API${RESET}"
    curl -s "https://hackscan.hackbounty.io/public/hack-address.json" > "$OUTPUT_DIR/hack_addresses.json"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+] Successfully fetched hacker addresses${RESET}"
    else
        echo -e "${RED}[!] Failed to fetch hacker addresses${RESET}"
        exit 1
    fi
}

# Function to organize and display addresses
organize_addresses() {
    echo -e "${BLUE}[*] Organizing addresses by blockchain${RESET}"

    # Extract and save addresses by type
    jq -r '.["0221"].eth[]' "$OUTPUT_DIR/hack_addresses.json" > "$OUTPUT_DIR/eth_addresses.txt" 2>/dev/null
    jq -r '.["0221"].btc[]' "$OUTPUT_DIR/hack_addresses.json" > "$OUTPUT_DIR/btc_addresses.txt" 2>/dev/null
    jq -r '.["0221"].bsc[]' "$OUTPUT_DIR/hack_addresses.json" > "$OUTPUT_DIR/bsc_addresses.txt" 2>/dev/null
    jq -r '.["0221"].arbi[]' "$OUTPUT_DIR/hack_addresses.json" > "$OUTPUT_DIR/arbi_addresses.txt" 2>/dev/null

    # Count addresses for summary
    ETH_COUNT=$(wc -l < "$OUTPUT_DIR/eth_addresses.txt" 2>/dev/null || echo 0)
    BTC_COUNT=$(wc -l < "$OUTPUT_DIR/btc_addresses.txt" 2>/dev/null || echo 0)
    BSC_COUNT=$(wc -l < "$OUTPUT_DIR/bsc_addresses.txt" 2>/dev/null || echo 0)
    ARBI_COUNT=$(wc -l < "$OUTPUT_DIR/arbi_addresses.txt" 2>/dev/null || echo 0)

    # Display summary
    echo -e "${YELLOW}===== Hacker Address Summary ====${RESET}"
    echo -e "${GREEN}Ethereum (ETH): $ETH_COUNT addresses${RESET}"
    echo -e "${GREEN}Bitcoin (BTC): $BTC_COUNT addresses${RESET}"
    echo -e "${GREEN}Binance Smart Chain (BSC): $BSC_COUNT addresses${RESET}"
    echo -e "${GREEN}Arbitrum (ARBI): $ARBI_COUNT addresses${RESET}"
    echo -e "${YELLOW}============================${RESET}"

    # Show a sample of ETH addresses (if any)
    if [ $ETH_COUNT -gt 0 ]; then
        echo -e "${BLUE}[*] Sample of Ethereum addresses:${RESET}"
        head -n 5 "$OUTPUT_DIR/eth_addresses.txt" | while IFS= read -r addr; do
            echo -e "  $addr"
        done
    else
        echo -e "${RED}[!] No Ethereum addresses found${RESET}"
    fi
}

# Function to provide next steps
next_steps() {
    echo -e "${YELLOW}===== What to Do Next ====${RESET}"
    echo -e "${BLUE}1. Check Files:${RESET} Open $OUTPUT_DIR/*.txt for full address lists."
    echo -e "${BLUE}2. Trace Funds:${RESET} Use a blockchain explorer (e.g., Etherscan, Blockchain.com) to track these addresses."
    echo -e "${BLUE}3. Report Findings:${RESET} If you spot stolen funds moving to an exchange or mixer, submit to lazarusbounty.com for a 5% reward."
    echo -e "${YELLOW}========================${RESET}"
}

# Main execution
echo -e "${GREEN}[+] Starting Lazarus Bounty Lite${RESET}"

# Step 1: Fetch addresses
fetch_hacker_addresses

# Step 2: Organize and display
organize_addresses

# Step 3: Provide guidance
next_steps

echo -e "${GREEN}[+] Done! Happy hunting for that $140M bounty!${RESET}"
