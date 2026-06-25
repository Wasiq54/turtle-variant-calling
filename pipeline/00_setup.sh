#!/bin/bash
# ============================================================
# Setup: define all shared paths used across pipeline scripts
# ============================================================
set -euo pipefail

export REF="/home/work/Desktop/DeepVariantTraining/ref/Reference.fasta"
export BAM_DIR="/home/work/Desktop/afshan"
export OUT_DIR="/home/work/Desktop/afshan/research_paper_work1/results"
export PIPELINE_DIR="/home/work/Desktop/afshan/research_paper_work1/pipeline"
export PAPER_DIR="/home/work/Desktop/afshan/research_paper_work1/paper"
export GITHUB_DIR="/home/work/Desktop/afshan/research_paper_work1/github"
export ZENODO_DIR="/home/work/Desktop/afshan/research_paper_work1/zenodo"
export SAMPLES="CH1_W CH2_W S1_H S2_H S3_U S4_U"

# --- Threading (machine has 80 threads) ---
export TOTAL_THREADS=80
export PARALLEL_SAMPLES=6      # process all 6 samples at once
export THREADS_PER_SAMPLE=12   # 6 x 12 = 72 threads, leaves headroom
export DV_SHARDS=64            # DeepVariant make_examples shards
export HC_SCATTER=72           # GATK HaplotypeCaller interval scatter

# Output sub-directories
mkdir -p "$OUT_DIR/qc"
mkdir -p "$OUT_DIR/gvcf"
mkdir -p "$OUT_DIR/vcf"
mkdir -p "$OUT_DIR/filtered"
mkdir -p "$OUT_DIR/annotated"
mkdir -p "$OUT_DIR/coverage"
mkdir -p "$OUT_DIR/logs"

export LOG_DIR="$OUT_DIR/logs"

# start_log <step-name> : tee all stdout+stderr to a timestamped log file
start_log() {
    local STEP="$1"
    local LOG="$LOG_DIR/${STEP}_$(date +%Y%m%d_%H%M%S).log"
    exec > >(tee -a "$LOG") 2>&1
    echo "==================================================="
    echo " STEP : $STEP"
    echo " START: $(date)"
    echo " LOG  : $LOG"
    echo "==================================================="
}

echo "Directories ready under $OUT_DIR"
