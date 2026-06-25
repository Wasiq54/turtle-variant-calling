#!/bin/bash
# ============================================================
# Step 1: Index all BAM files (required before any downstream step)
# ============================================================
set -euo pipefail
source "$(dirname "$0")/00_setup.sh"
start_log "01_index"

for SAMPLE in $SAMPLES; do
    BAM="$BAM_DIR/${SAMPLE}.final.bam"
    if [ -f "${BAM}.bai" ]; then
        echo "[SKIP] $SAMPLE already indexed"
    else
        echo "[INDEX] $SAMPLE ..."
        samtools index -@ 4 "$BAM"
        echo "[DONE]  $SAMPLE"
    fi
done

echo "All BAMs indexed."
