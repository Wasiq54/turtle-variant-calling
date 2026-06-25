#!/bin/bash
# ============================================================
# Setup: define all shared paths used across pipeline scripts
# ============================================================
set -euo pipefail

# --- Paths (override these via environment variables before running) ---
#   REF      reference genome FASTA, indexed (samtools faidx + GATK .dict)
#   BAM_DIR  directory holding the input <SAMPLE>.final.bam files
#   OUT_DIR  where all pipeline outputs are written (default: ../results)
# Example:
#   export REF=/data/ref/GCF_015237465.2.fasta
#   export BAM_DIR=/data/bams
export REF="${REF:-/path/to/reference.fasta}"
export BAM_DIR="${BAM_DIR:-/path/to/bam_directory}"
PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PIPELINE_DIR
export OUT_DIR="${OUT_DIR:-$(dirname "$PIPELINE_DIR")/results}"
export SAMPLES="${SAMPLES:-CH1_W CH2_W S1_H S2_H S3_U S4_U}"

# --- Threading (machine has 80 threads) ---
export TOTAL_THREADS=80
export PARALLEL_SAMPLES=6      # process all 6 samples at once
export THREADS_PER_SAMPLE=12   # 6 x 12 = 72 threads, leaves headroom
export DV_SHARDS=64            # DeepVariant make_examples shards
export HC_SCATTER=72           # GATK HaplotypeCaller interval scatter

# --- Tool versions (single source of truth; pinned for reproducibility) ---
export DV_VERSION="${DV_VERSION:-1.9.0}"   # DeepVariant CPU image (used in 03b and 06c)
export DV_TAG="deepvariant_1_9"            # DeepVariant output-file name tag (03b -> 04b)

# --- Descriptive output paths (single source of truth for all steps) ---
export QC_DIR="$OUT_DIR/01_alignment_qc"
export COV_DIR="$OUT_DIR/02_coverage"
export GATK_GVCF_DIR="$OUT_DIR/03_gatk_calls/per_sample_gvcf"
export GATK_JOINT_DIR="$OUT_DIR/03_gatk_calls/joint_genotyped_vcf"
export DV_GVCF_DIR="$OUT_DIR/04_deepvariant_calls/per_sample_gvcf"
export DV_JOINT_DIR="$OUT_DIR/04_deepvariant_calls/joint_genotyped_vcf"
export FILTER_DIR="$OUT_DIR/05_filtered_variants"
export CONCORDANCE_DIR="$OUT_DIR/06_benchmark/caller_concordance"
export TRUTH_DIR="$OUT_DIR/06_benchmark/simulated_truth_set"
export VCFEVAL_DIR="$OUT_DIR/06_benchmark/vcfeval_scores"
export ANNOT_DIR="$OUT_DIR/07_functional_annotation"
export SUMMARY_DIR="$OUT_DIR/08_summary_tables"
export LOG_DIR="$OUT_DIR/logs"

# Create them all (idempotent)
mkdir -p "$QC_DIR" "$COV_DIR" \
         "$GATK_GVCF_DIR" "$GATK_JOINT_DIR" \
         "$DV_GVCF_DIR" "$DV_JOINT_DIR" \
         "$FILTER_DIR" \
         "$CONCORDANCE_DIR" "$TRUTH_DIR" "$VCFEVAL_DIR" \
         "$ANNOT_DIR" "$SUMMARY_DIR" "$LOG_DIR"

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
