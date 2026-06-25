#!/bin/bash
# ============================================================
# Step 7: Generate summary tables for the paper Results section
# ============================================================
set -euo pipefail
source "$(dirname "$0")/00_setup.sh"
start_log "07_summary_report"

FINAL_VCF="$OUT_DIR/filtered/final_filtered.vcf.gz"
REPORT="$OUT_DIR/summary_report.txt"

echo "=====================================================" > "$REPORT"
echo " Variant Summary Report — Chelonia mydas WGS (n=6)  " >> "$REPORT"
echo "=====================================================" >> "$REPORT"
echo "" >> "$REPORT"

# Per-sample read counts from flagstat
echo "--- Read Alignment Summary ---" >> "$REPORT"
printf "%-12s %-18s %-18s %-10s\n" "Sample" "Total Reads" "Mapped Reads" "Map%" >> "$REPORT"
for SAMPLE in $SAMPLES; do
    FLAGSTAT="$OUT_DIR/qc/${SAMPLE}.flagstat.txt"
    if [ -f "$FLAGSTAT" ]; then
        TOTAL=$(grep "in total" "$FLAGSTAT" | awk '{print $1}')
        MAPPED=$(grep "mapped (" "$FLAGSTAT" | head -1 | awk '{print $1}')
        MAP_PCT=$(grep "mapped (" "$FLAGSTAT" | head -1 | grep -oP '\(\K[^%]+')
        printf "%-12s %-18s %-18s %-10s\n" "$SAMPLE" "$TOTAL" "$MAPPED" "${MAP_PCT}%" >> "$REPORT"
    fi
done
echo "" >> "$REPORT"

# Variant counts from final VCF
echo "--- Variant Counts (post-filter) ---" >> "$REPORT"
if [ -f "$FINAL_VCF" ]; then
    bcftools stats "$FINAL_VCF" | grep "^SN" >> "$REPORT"
    echo "" >> "$REPORT"
    echo "--- Per-sample genotype counts ---" >> "$REPORT"
    bcftools stats -s - "$FINAL_VCF" | grep "^PSC" >> "$REPORT"
fi

echo "" >> "$REPORT"
echo "Report generated: $(date)" >> "$REPORT"

cat "$REPORT"
echo ""
echo "Full report saved to $REPORT"
