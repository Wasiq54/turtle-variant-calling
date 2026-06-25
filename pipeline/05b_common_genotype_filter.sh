#!/bin/bash
# ============================================================
# Step 5b: COMMON (caller-agnostic) genotype filter
# ------------------------------------------------------------
# Applies the SAME generic filter, identically, to BOTH the
# GATK and the DeepVariant call sets, so the two are compared
# on equal footing. This is the "Layer B" filter (depth /
# genotype-quality / biallelic) that uses standard VCF fields
# (DP, GQ) present in both files.
#
# NOTE on fairness: each caller keeps its OWN quality filter
# (Layer A: GATK hard-filtering in 05; DeepVariant native QUAL
# from GLnexus). This script only adds the identical Layer-B
# filter on top of both.
#
# Caveat (state in Methods): GQ is computed differently by GATK
# and DeepVariant, so an identical GQ threshold is an
# approximation (Yun et al. 2021, Bioinformatics).
# Thresholds: DP>=8 / GQ>=20 follow Carson et al. 2014,
# BMC Bioinformatics 15:125.
# ============================================================
set -euo pipefail
source "$(dirname "$0")/00_setup.sh"
start_log "05b_common_genotype_filter"

# ---- Tunable thresholds (single source of truth) ----
MIN_DP=8           # minimum per-genotype read depth
MIN_GQ=20          # minimum per-genotype genotype quality
MAX_MISSING=0.5    # drop sites with > this fraction of missing genotypes
                   #   (0.5 = keep sites called in at least half the samples)

# ---- Inputs ----
GATK_IN="$FILTER_DIR/gatk_final.vcf.gz"          # from step 05 (hard-filtered PASS)
DV_IN="$DV_JOINT_DIR/dv_joint.vcf.gz"            # DeepVariant/GLnexus joint (native PASS)

# ---- Outputs (descriptive folder named after the filter; one subfolder per tool) ----
COMMON_DIR="$FILTER_DIR/common_filtered_DP${MIN_DP}_GQ${MIN_GQ}_biallelic_PASS"
mkdir -p "$COMMON_DIR/GATK" "$COMMON_DIR/DeepVariant"
GATK_OUT="$COMMON_DIR/GATK/gatk_common_filtered.vcf.gz"
DV_OUT="$COMMON_DIR/DeepVariant/deepvariant_common_filtered.vcf.gz"

# Make sure the GATK hard-filtered set exists first
if [ ! -f "$GATK_IN" ]; then
    echo "[ERROR] $GATK_IN not found — run 05_variant_filter.sh first." >&2
    exit 1
fi

# ------------------------------------------------------------
# filter_one  <TAG>  <input.vcf.gz>  <output.vcf.gz>
# The EXACT same command runs for both callers.
# ------------------------------------------------------------
filter_one() {
    local TAG="$1" IN="$2" OUT="$3"
    echo "=================================================="
    echo "[$TAG] input : $IN"

    local N_IN; N_IN=$(bcftools view -H "$IN" 2>/dev/null | wc -l)

    # 1) keep PASS (or unfiltered '.') + biallelic only  (-m2 -M2)
    # 2) mask genotypes failing DP<MIN_DP OR GQ<MIN_GQ  -> set to missing './.'
    # 3) drop sites with > MAX_MISSING fraction missing
    bcftools view -f PASS,. -m2 -M2 "$IN" -Ou \
      | bcftools +setGT -Ou -- -t q -n . -i "FMT/DP<${MIN_DP} | FMT/GQ<${MIN_GQ}" \
      | bcftools view -e "F_MISSING > ${MAX_MISSING}" -Oz -o "$OUT"
    bcftools index -t "$OUT"

    local N_OUT; N_OUT=$(bcftools view -H "$OUT" 2>/dev/null | wc -l)
    echo "[$TAG] output: $OUT"
    echo "[$TAG] sites: ${N_IN} -> ${N_OUT}  (DP>=${MIN_DP}, GQ>=${MIN_GQ}, biallelic, F_MISSING<=${MAX_MISSING})"
}

echo "Applying identical Layer-B filter to BOTH callers"
echo "  MIN_DP=${MIN_DP}  MIN_GQ=${MIN_GQ}  MAX_MISSING=${MAX_MISSING}"

filter_one "GATK"        "$GATK_IN" "$GATK_OUT"
filter_one "DeepVariant" "$DV_IN"   "$DV_OUT"

echo "=================================================="
echo "Common genotype filtering complete."
echo "  GATK        -> $GATK_OUT"
echo "  DeepVariant -> $DV_OUT"
