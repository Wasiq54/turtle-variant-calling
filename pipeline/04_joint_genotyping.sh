#!/bin/bash
# ============================================================
# Step 4: Joint genotyping — combine GVCFs, then GenotypeGVCFs
# ============================================================
set -euo pipefail
source "$(dirname "$0")/00_setup.sh"
start_log "04_joint_genotyping"

COMBINED_DB="$OUT_DIR/gvcf/combined_genomicsdb"
JOINT_VCF="$OUT_DIR/vcf/all_samples.vcf.gz"

# Build -V arguments for all samples
V_ARGS=""
for SAMPLE in $SAMPLES; do
    GVCF="$OUT_DIR/gvcf/${SAMPLE}.g.vcf.gz"
    V_ARGS="$V_ARGS -V $GVCF"
done

# --- 4a: Combine GVCFs into GenomicsDB ---
if [ -d "$COMBINED_DB" ]; then
    echo "[SKIP] GenomicsDB already exists"
else
    echo "[COMBINE] Running CombineGVCFs ..."

    # Get all chromosome/scaffold names from reference dict
    INTERVALS=$(grep "^@SQ" "${REF%.fasta}.dict" | awk '{print $2}' | sed 's/SN://' | tr '\n' ' ')

    # Build -L arguments
    L_ARGS=""
    for CHR in $INTERVALS; do
        L_ARGS="$L_ARGS -L $CHR"
    done

    conda run -n gatk-env gatk CombineGVCFs \
        -R "$REF" \
        $V_ARGS \
        -O "$COMBINED_DB" \
        $L_ARGS \
        --tmp-dir /tmp \
        2> "$OUT_DIR/gvcf/combine_gvcfs.log"
    echo "[DONE] CombineGVCFs"
fi

# --- 4b: Joint genotyping ---
if [ -f "$JOINT_VCF" ]; then
    echo "[SKIP] Joint VCF already exists"
else
    echo "[GENOTYPE] Running GenotypeGVCFs ..."
    conda run -n gatk-env gatk GenotypeGVCFs \
        -R "$REF" \
        -V "$COMBINED_DB" \
        -O "$JOINT_VCF" \
        --tmp-dir /tmp \
        2> "$OUT_DIR/vcf/genotype_gvcfs.log"
    echo "[DONE] Joint VCF -> $JOINT_VCF"
fi

echo "Joint genotyping complete."
