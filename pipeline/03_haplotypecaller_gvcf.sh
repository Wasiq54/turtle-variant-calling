#!/bin/bash
# ============================================================
# Step 3: GATK HaplotypeCaller — per-sample GVCF mode
# Run each sample independently; combine in step 04.
# ============================================================
set -euo pipefail
source "$(dirname "$0")/00_setup.sh"
start_log "03_haplotypecaller"

for SAMPLE in $SAMPLES; do
    BAM="$BAM_DIR/${SAMPLE}.final.bam"
    GVCF="$OUT_DIR/gvcf/${SAMPLE}.g.vcf.gz"

    if [ -f "$GVCF" ]; then
        echo "[SKIP] $SAMPLE GVCF already exists"
        continue
    fi

    echo "[GVCF] $SAMPLE ..."
    conda run -n gatk-env gatk HaplotypeCaller \
        -R "$REF" \
        -I "$BAM" \
        -O "$GVCF" \
        -ERC GVCF \
        --sample-name "$SAMPLE" \
        --native-pair-hmm-threads 8 \
        --tmp-dir /tmp \
        2> "$OUT_DIR/gvcf/${SAMPLE}.hc.log"

    echo "[DONE] $SAMPLE -> $GVCF"
done

echo "HaplotypeCaller GVCF step complete."
