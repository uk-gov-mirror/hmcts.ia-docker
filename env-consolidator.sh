#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Input files in order of precedence (last one wins)
FILES=(".local_env" ".wa-env" ".hmc-env" ".env-ft")
OUTPUT_FILE="iac-ft.env"
STATS_FILE="env_stats.txt"
TEMP_DIR=$(mktemp -d)
VARS_FILE="$TEMP_DIR/vars.txt"
STATS_TEMP="$TEMP_DIR/stats.txt"

cleanup() {
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

echo "Starting environment file consolidation..."

# Function to extract variable name from export statement
get_var_name() {
    local line=$1
    echo "$line" | sed -n 's/^export \([^=]*\)=.*/\1/p'
}

# Function to extract variable value from export statement
get_var_value() {
    local line=$1
    echo "$line" | sed -n 's/^export [^=]*=\(.*\)/\1/p'
}

# Process each file
for file in "${FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}Warning: File $file not found${NC}"
        continue
    fi

    echo -e "${GREEN}Processing $file...${NC}"

    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        if [[ $line =~ ^[[:space:]]*# ]] || [[ -z $line ]] || [[ $line =~ ^[[:space:]]*$ ]]; then
            continue
        fi

        # Skip if and fi statements
        if [[ $line =~ ^[[:space:]]*if ]] || [[ $line =~ ^[[:space:]]*fi ]]; then
            continue
        fi

        # Only process export statements
        if [[ $line =~ ^export ]]; then
            var_name=$(get_var_name "$line")
            var_value=$(get_var_value "$line")

            if [ -n "$var_name" ]; then
                # Store variable information
                echo "$var_name|$var_value|$line|$file" >> "$VARS_FILE"
            fi
        fi
    done < "$file"
done

# Generate consolidated environment file
echo "# Consolidated environment variables for IAC-FT" > "$OUTPUT_FILE"
echo "# Generated on $(date)" >> "$OUTPUT_FILE"
echo "# Source files (in order of precedence): ${FILES[*]}" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Process variables file to find duplicates and generate statistics
echo "Environment Variable Statistics" > "$STATS_FILE"
echo "=============================" >> "$STATS_FILE"
echo "Generated on $(date)" >> "$STATS_FILE"
echo "" >> "$STATS_FILE"

# Create a sorted unique list of variable names
cut -d'|' -f1 "$VARS_FILE" | sort | uniq > "$TEMP_DIR/unique_vars.txt"
total_vars=$(wc -l < "$TEMP_DIR/unique_vars.txt")

# Find duplicates and their details
total_duplicates=0
while IFS= read -r var_name; do
    # Count occurrences
    count=$(grep "^$var_name|" "$VARS_FILE" | wc -l)

    if [ "$count" -gt 1 ]; then
        ((total_duplicates++))
        echo "Variable: $var_name" >> "$STATS_TEMP"
        echo "Occurrences: $count" >> "$STATS_TEMP"

        # Get all values for this variable
        echo "Values from each file:" >> "$STATS_TEMP"
        grep "^$var_name|" "$VARS_FILE" | while IFS='|' read -r _ value _ source; do
            echo "  $source: $value" >> "$STATS_TEMP"
        done
        echo "-------------------------" >> "$STATS_TEMP"
    fi
done < "$TEMP_DIR/unique_vars.txt"

# Write statistics
echo "Total unique variables: $total_vars" >> "$STATS_FILE"
echo "Variables with duplicates: $total_duplicates" >> "$STATS_FILE"
echo "" >> "$STATS_FILE"
echo "Duplicate Variables Analysis" >> "$STATS_FILE"
echo "-------------------------" >> "$STATS_FILE"
cat "$STATS_TEMP" >> "$STATS_FILE"

# Write consolidated environment file grouped by source files
for file in "${FILES[@]}"; do
    echo "# Variables from $file" >> "$OUTPUT_FILE"
    grep "|$file\$" "$VARS_FILE" | while IFS='|' read -r _ _ line _; do
        echo "$line" >> "$OUTPUT_FILE"
    done
    echo "" >> "$OUTPUT_FILE"
done

echo -e "${GREEN}Consolidation complete!${NC}"
echo -e "Generated files:"
echo -e "${YELLOW}- $OUTPUT_FILE ${NC}(consolidated environment variables)"
echo -e "${YELLOW}- $STATS_FILE ${NC}(duplication statistics)"
