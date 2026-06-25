#!/bin/bash
# ============================================================
# Step 3b (DeepVariant track): per-sample calling via Docker
# CNN deep-learning caller. GVCF mode for cohort merging (GLnexus, step 04b).
# NOTE: DeepVariant's WGS model is HUMAN-trained; used off-label on a
#       non-model genome. State this in the manuscript Limitations.
# ============================================================
set -euo pipefail
source "$(dirname "$0")/00_setup.sh"
start_log "03b_deepvariant"

# DV_VERSION (CPU image 1.9.0) and DV_TAG come from 00_setup.sh (single source
# of truth). This study was run on CPU; for GPU set DV_VERSION=1.9.0-gpu and add
# `--gpus all` to the docker run below. DV_TAG keeps output names in sync with 04b.
REF_DIR="$(dirname "$REF")"
REF_NAME="$(basename "$REF")"

for SAMPLE in $SAMPLES; do
    GVCF="$DV_GVCF_DIR/${SAMPLE}_${DV_TAG}.g.vcf.gz"
    if [ -f "$GVCF" ]; then
        echo "[SKIP] $SAMPLE DeepVariant GVCF already exists"
        continue
    fi

    echo "[DV] $SAMPLE (DeepVariant $DV_VERSION, CPU) ..."
    docker run --rm \
        -v "${REF_DIR}":/ref \
        -v "${BAM_DIR}":/bam \
        -v "${DV_GVCF_DIR}":/output \
        google/deepvariant:"${DV_VERSION}" \
        /opt/deepvariant/bin/run_deepvariant \
            --model_type=WGS \
            --ref=/ref/"${REF_NAME}" \
            --reads=/bam/"${SAMPLE}".final.bam \
            --output_vcf=/output/"${SAMPLE}_${DV_TAG}".vcf.gz \
            --output_gvcf=/output/"${SAMPLE}_${DV_TAG}".g.vcf.gz \
            --num_shards="${DV_SHARDS}" \
            --intermediate_results_dir=/output/"${SAMPLE}"_tmp \
            --make_examples_extra_args="small_model_call_multiallelics=false" \
        2> "$DV_GVCF_DIR/${SAMPLE}.dv.log"

    rm -rf "${DV_GVCF_DIR}/${SAMPLE}_tmp"
    echo "[DONE] $SAMPLE -> $GVCF"
done

# Docker writes outputs as root; normalise ownership so downstream steps can read.
# (Skips silently if not permitted; chown only what this step produced.)
chown -R "$(id -u):$(id -g)" "$DV_GVCF_DIR" 2>/dev/null || \
    echo "[WARN] could not chown DeepVariant outputs (root-owned); may need: sudo chown -R $(id -un) $DV_GVCF_DIR"

echo "DeepVariant per-sample calling complete."
