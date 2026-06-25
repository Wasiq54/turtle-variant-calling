#!/bin/bash
# ============================================================
# Worker for 03a: run GATK HaplotypeCaller on ONE interval shard
# for ONE sample. Called in parallel by 03a_gatk_haplotypecaller.sh.
# Args: $1=SAMPLE  $2=INTERVAL_LIST  $3=IDX(zero-padded)
# Resumable: skips if this shard's GVCF already exists.
# ============================================================
set -euo pipefail
source "$(dirname "$0")/00_setup.sh" >/dev/null

SAMPLE="$1"; IVL="$2"; IDX="$3"
BAM="$BAM_DIR/${SAMPLE}.final.bam"
SHARD_DIR="$GATK_GVCF_DIR/shards/$SAMPLE"
OUT="$SHARD_DIR/${IDX}.g.vcf.gz"
LOG="$LOG_DIR/03a_gatk/jobs/${SAMPLE}.${IDX}.log"
mkdir -p "$SHARD_DIR" "$(dirname "$LOG")"

# Skip if already completed (valid .tbi present)
if [ -f "$OUT" ] && [ -f "${OUT}.tbi" ]; then
    echo "[SKIP] $SAMPLE shard $IDX already done"
    exit 0
fi

conda run -n gatk-env gatk --java-options "-Xmx${HC_XMX:-6g}" HaplotypeCaller \
    -R "$REF" \
    -I "$BAM" \
    -O "$OUT" \
    -ERC GVCF \
    -L "$IVL" \
    --sample-name "$SAMPLE" \
    --native-pair-hmm-threads "${HC_HMM_THREADS:-2}" \
    --tmp-dir /tmp \
    > "$LOG" 2>&1

echo "[DONE] $SAMPLE shard $IDX -> $OUT"
