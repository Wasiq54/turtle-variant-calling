#!/bin/bash
# ============================================================
# Step 8: Generate paper-ready summary tables (Results section)
# ============================================================
set -euo pipefail
source "$(dirname "$0")/00_setup.sh"
start_log "08_summary_report"

GATK_VCF="$FILTER_DIR/gatk_final.vcf.gz"
DV_VCF="$DV_JOINT_DIR/dv_joint.vcf.gz"
REPORT="$SUMMARY_DIR/summary_report.txt"

{
echo "====================================================="
echo " Variant Summary Report — Chelonia mydas WGS (n=6)  "
echo " Generated: $(date)"
echo "====================================================="
echo ""

# --- Read alignment summary (Table 1) ---
echo "--- Read Alignment + Coverage (Table 1) ---"
printf "%-8s %-16s %-9s %-11s\n" "Sample" "TotalReads" "Mapped%" "MeanDepth"
for SAMPLE in $SAMPLES; do
    FS="$QC_DIR/${SAMPLE}.flagstat.txt"
    SUM="$COV_DIR/${SAMPLE}.mosdepth.summary.txt"
    [ -f "$FS" ] || continue
    TOTAL=$(grep "in total" "$FS" | awk '{print $1}')
    MAPPCT=$(grep " mapped (" "$FS" | head -1 | grep -oP '\(\K[0-9.]+')
    DEPTH=$(awk '$1=="total"{print $4}' "$SUM" 2>/dev/null)
    printf "%-8s %-16s %-9s %-11s\n" "$SAMPLE" "$TOTAL" "${MAPPCT}%" "${DEPTH}x"
done
echo ""

# --- Variant counts per caller (Table 2) ---
echo "--- Variant Counts post-filter (Table 2) ---"
for LABEL in "GATK:$GATK_VCF" "DeepVariant:$DV_VCF"; do
    NAME="${LABEL%%:*}"; VCF="${LABEL#*:}"
    if [ -f "$VCF" ]; then
        echo "[$NAME]"
        bcftools stats "$VCF" | grep "^SN"
        echo ""
    fi
done

# --- Per-sample genotype counts (GATK) ---
if [ -f "$GATK_VCF" ]; then
    echo "--- Per-sample genotype counts (GATK) ---"
    bcftools stats -s - "$GATK_VCF" | grep "^PSC"
fi
} > "$REPORT"

cat "$REPORT"
echo ""
echo "Full report saved to $REPORT"
