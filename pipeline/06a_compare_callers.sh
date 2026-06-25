#!/bin/bash
# ============================================================
# Step 6a (BENCHMARK leg 1): Real-data concordance GATK vs DeepVariant
# Measures AGREEMENT (not accuracy). Shared calls = high-confidence set.
# -> Paper FIGURE 3 (Venn) + concordance %.
# MANDATORY: normalise both VCFs first, or representation differences
#            (multiallelics, indel left-alignment) cause FALSE discordance.
# ============================================================
set -euo pipefail
source "$(dirname "$0")/00_setup.sh"
start_log "06a_compare_callers"

# Use the Layer-B common-filtered sets (identical filter on both) for a FAIR comparison
GATK_VCF="$FILTER_DIR/common_filtered_DP8_GQ20_biallelic_PASS/GATK/gatk_common_filtered.vcf.gz"
DV_VCF="$FILTER_DIR/common_filtered_DP8_GQ20_biallelic_PASS/DeepVariant/deepvariant_common_filtered.vcf.gz"
GATK_NORM="$CONCORDANCE_DIR/gatk.norm.vcf.gz"
DV_NORM="$CONCORDANCE_DIR/dv.norm.vcf.gz"

# --- Normalise (left-align + split multiallelics) ---
echo "[NORM] Normalising both call sets ..."
bcftools norm -f "$REF" -m -any "$GATK_VCF" -O z -o "$GATK_NORM"
bcftools norm -f "$REF" -m -any "$DV_VCF"   -O z -o "$DV_NORM"
bcftools index -t "$GATK_NORM"
bcftools index -t "$DV_NORM"

# --- Site-level intersection ---
echo "[ISEC] Intersecting call sets ..."
bcftools isec -p "$CONCORDANCE_DIR/isec" "$GATK_NORM" "$DV_NORM"
#   isec output: 0000=GATK-only  0001=DV-only  0002=shared(GATK)  0003=shared(DV)

GATK_ONLY=$(grep -vc '^#' "$CONCORDANCE_DIR/isec/0000.vcf")
DV_ONLY=$(grep -vc   '^#' "$CONCORDANCE_DIR/isec/0001.vcf")
SHARED=$(grep -vc    '^#' "$CONCORDANCE_DIR/isec/0002.vcf")
TOTAL=$((GATK_ONLY + DV_ONLY + SHARED))
CONC=$(awk "BEGIN{ if($TOTAL>0) printf \"%.2f\", 100*$SHARED/$TOTAL; else print \"NA\" }")

# --- Genotype-level concordance at shared sites (per sample) ---
echo "[GT] Genotype concordance at shared sites ..."
bcftools stats "$GATK_NORM" "$DV_NORM" > "$CONCORDANCE_DIR/bcftools_compare_stats.txt" 2>/dev/null || true

# --- Report (Figure 3 numbers) ---
REPORT="$CONCORDANCE_DIR/concordance_summary.txt"
{
  echo "=== GATK vs DeepVariant concordance (real data, site level) ==="
  echo "GATK-only      : $GATK_ONLY"
  echo "DeepVariant-only: $DV_ONLY"
  echo "Shared (high-conf): $SHARED"
  echo "Total union    : $TOTAL"
  echo "Concordance %  : $CONC"
} | tee "$REPORT"

echo "Concordance step complete -> $REPORT"
