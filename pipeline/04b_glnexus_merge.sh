#!/bin/bash
# ============================================================
# Step 4b (DeepVariant track): joint genotyping with GLnexus
# GLnexus is the official DeepVariant cohort merger. The DeepVariantWGS
# config applies the recommended QUAL-based filtering natively.
# ============================================================
set -euo pipefail
source "$(dirname "$0")/00_setup.sh"
start_log "04b_glnexus_merge"

GLNEXUS_DB="$DV_JOINT_DIR/GLnexus.DB"     # scratch DB — must NOT pre-exist
JOINT_BCF="$DV_JOINT_DIR/dv_joint.bcf"
JOINT_VCF="$DV_JOINT_DIR/dv_joint.vcf.gz"

# Collect the 6 per-sample DeepVariant GVCFs
GVCFS=()
for SAMPLE in $SAMPLES; do
    GVCFS+=("$DV_GVCF_DIR/${SAMPLE}_${DV_TAG}.g.vcf.gz")
done

# GLnexus refuses to run if its scratch DB dir already exists
rm -rf "$GLNEXUS_DB"

echo "[GLNEXUS] Joint genotyping ${#GVCFS[@]} DeepVariant GVCFs ..."
conda run --no-capture-output -n glnexus-env glnexus_cli \
    --config DeepVariantWGS \
    --dir "$GLNEXUS_DB" \
    "${GVCFS[@]}" \
    > "$JOINT_BCF" \
    2> "$DV_JOINT_DIR/glnexus.log"

echo "[CONVERT] BCF -> bgzipped VCF ..."
bcftools view "$JOINT_BCF" -O z -o "$JOINT_VCF"
bcftools index -t "$JOINT_VCF"
rm -rf "$GLNEXUS_DB" "$JOINT_BCF"

echo "DeepVariant joint genotyping complete -> $JOINT_VCF"
bcftools stats "$JOINT_VCF" | grep "^SN"
