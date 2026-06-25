#!/bin/bash
# ============================================================
# Step 4a (GATK track): Joint genotyping
# CombineGVCFs (-> one multi-sample GVCF file) then GenotypeGVCFs.
# ============================================================
set -euo pipefail
source "$(dirname "$0")/00_setup.sh"
start_log "04a_gatk_joint_genotyping"

COMBINED_GVCF="$GATK_GVCF_DIR/combined.g.vcf.gz"
JOINT_VCF="$GATK_JOINT_DIR/gatk_joint.vcf.gz"

# Build -V arguments for all samples
V_ARGS=""
for SAMPLE in $SAMPLES; do
    V_ARGS="$V_ARGS -V $GATK_GVCF_DIR/${SAMPLE}.g.vcf.gz"
done

# --- Combine the 6 per-sample GVCFs into ONE multi-sample GVCF ---
# (CombineGVCFs writes a .g.vcf.gz FILE — not a GenomicsDB directory.)
if [ -f "$COMBINED_GVCF" ]; then
    echo "[SKIP] Combined GVCF already exists"
else
    echo "[COMBINE] Running CombineGVCFs ..."
    conda run -n gatk-env gatk CombineGVCFs \
        -R "$REF" \
        $V_ARGS \
        -O "$COMBINED_GVCF" \
        --tmp-dir /tmp \
        2> "$GATK_JOINT_DIR/combine_gvcfs.log"
    echo "[DONE] CombineGVCFs -> $COMBINED_GVCF"
fi

# --- Joint genotyping ---
if [ -f "$JOINT_VCF" ]; then
    echo "[SKIP] Joint VCF already exists"
else
    echo "[GENOTYPE] Running GenotypeGVCFs ..."
    conda run -n gatk-env gatk GenotypeGVCFs \
        -R "$REF" \
        -V "$COMBINED_GVCF" \
        -O "$JOINT_VCF" \
        --tmp-dir /tmp \
        2> "$GATK_JOINT_DIR/genotype_gvcfs.log"
    echo "[DONE] Joint VCF -> $JOINT_VCF"
fi

echo "GATK joint genotyping complete."
