#!/bin/bash
# ============================================================
# Step 5: Variant filtering (hard filters — no population DB
# available for non-model species, so VQSR is not applicable)
# ============================================================
set -euo pipefail
source "$(dirname "$0")/00_setup.sh"
start_log "05_variant_filter"

JOINT_VCF="$OUT_DIR/vcf/all_samples.vcf.gz"
SNP_RAW="$OUT_DIR/filtered/snps_raw.vcf.gz"
INDEL_RAW="$OUT_DIR/filtered/indels_raw.vcf.gz"
SNP_FILTERED="$OUT_DIR/filtered/snps_filtered.vcf.gz"
INDEL_FILTERED="$OUT_DIR/filtered/indels_filtered.vcf.gz"
FINAL_VCF="$OUT_DIR/filtered/final_filtered.vcf.gz"

# --- 5a: Separate SNPs and INDELs ---
echo "[FILTER] Extracting SNPs ..."
conda run -n gatk-env gatk SelectVariants -R "$REF" -V "$JOINT_VCF" \
    --select-type-to-include SNP -O "$SNP_RAW" --tmp-dir /tmp

echo "[FILTER] Extracting INDELs ..."
conda run -n gatk-env gatk SelectVariants -R "$REF" -V "$JOINT_VCF" \
    --select-type-to-include INDEL -O "$INDEL_RAW" --tmp-dir /tmp

# --- 5b: Hard filter SNPs (GATK best-practice thresholds for non-model) ---
echo "[FILTER] Hard filtering SNPs ..."
# Thresholds match Broad Institute official "Hard-filtering germline short variants"
conda run -n gatk-env gatk VariantFiltration -R "$REF" -V "$SNP_RAW" \
    --filter-expression "QD < 2.0"              --filter-name "QD2" \
    --filter-expression "QUAL < 30.0"           --filter-name "QUAL30" \
    --filter-expression "SOR > 3.0"             --filter-name "SOR3" \
    --filter-expression "FS > 60.0"             --filter-name "FS60" \
    --filter-expression "MQ < 40.0"             --filter-name "MQ40" \
    --filter-expression "MQRankSum < -12.5"     --filter-name "MQRankSum-12.5" \
    --filter-expression "ReadPosRankSum < -8.0" --filter-name "ReadPosRankSum-8" \
    -O "$SNP_FILTERED" --tmp-dir /tmp

# --- 5c: Hard filter INDELs ---
echo "[FILTER] Hard filtering INDELs ..."
# Indels: mapping-quality annotations (MQ, MQRankSum) deliberately omitted —
# Broad recommendation, as indel length conflates with mapping quality
conda run -n gatk-env gatk VariantFiltration -R "$REF" -V "$INDEL_RAW" \
    --filter-expression "QD < 2.0"               --filter-name "QD2" \
    --filter-expression "QUAL < 30.0"            --filter-name "QUAL30" \
    --filter-expression "FS > 200.0"             --filter-name "FS200" \
    --filter-expression "SOR > 10.0"             --filter-name "SOR10" \
    --filter-expression "ReadPosRankSum < -20.0" --filter-name "ReadPosRankSum-20" \
    -O "$INDEL_FILTERED" --tmp-dir /tmp

# --- 5d: Merge filtered SNPs and INDELs, keep only PASS ---
echo "[FILTER] Merging and keeping PASS variants ..."
bcftools concat --allow-overlaps \
    "$SNP_FILTERED" "$INDEL_FILTERED" \
    | bcftools view --apply-filters PASS \
    -O z -o "$FINAL_VCF"
bcftools index -t "$FINAL_VCF"

echo "Variant filtering complete. Final VCF: $FINAL_VCF"
bcftools stats "$FINAL_VCF" | grep "^SN"
