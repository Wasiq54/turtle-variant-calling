#!/bin/bash
# ============================================================
# Step 6c (BENCHMARK leg 1 scoring): call the simulated BAM with BOTH
# callers, then score each against the known truth set with RTG vcfeval.
# -> Paper TABLE 3 (Precision / Recall / F1) = HEADLINE RESULT.
# Run AFTER 06b (which produces sim.final.bam + truth.vcf.gz).
# ============================================================
set -euo pipefail
source "$(dirname "$0")/00_setup.sh"
start_log "06c_benchmark_vcfeval"

SIM_BAM="$TRUTH_DIR/sim.final.bam"
TRUTH_VCF="$TRUTH_DIR/truth.vcf.gz"
# Per-tool output subfolders (keep GATK and DeepVariant results separate)
GATK_DIR="$VCFEVAL_DIR/GATK"
DV_DIR="$VCFEVAL_DIR/DeepVariant"
mkdir -p "$GATK_DIR" "$DV_DIR"
GATK_SIM="$GATK_DIR/gatk_sim.vcf.gz"
DV_SIM="$DV_DIR/dv_sim.vcf.gz"
REF_SDF="$VCFEVAL_DIR/ref_sdf"          # shared reference SDF (not tool-specific)
REF_DIR="$(dirname "$REF")"; REF_NAME="$(basename "$REF")"

[ -f "$SIM_BAM" ]   || { echo "[ERROR] $SIM_BAM missing — run 06b first"; exit 1; }
[ -f "$TRUTH_VCF" ] || { echo "[ERROR] $TRUTH_VCF missing — run 06b first"; exit 1; }

# --- Call the simulated BAM with GATK (single sample, direct VCF) ---
if [ -f "$GATK_SIM" ]; then
    echo "[SKIP] GATK VCF already exists -> $GATK_SIM"
else
    echo "[CALL] GATK on simulated BAM ..."
    conda run -n gatk-env gatk HaplotypeCaller \
        -R "$REF" -I "$SIM_BAM" -O "$GATK_SIM" \
        --native-pair-hmm-threads 8 --tmp-dir /tmp 2> "$GATK_DIR/gatk_sim.log"
fi

# --- Call the simulated BAM with DeepVariant (docker) ---
if [ -f "$DV_SIM" ]; then
    echo "[SKIP] DeepVariant VCF already exists -> $DV_SIM"
else
    echo "[CALL] DeepVariant on simulated BAM ..."
    docker run --rm \
        -v "${REF_DIR}":/ref -v "${TRUTH_DIR}":/bam -v "${VCFEVAL_DIR}":/output \
        google/deepvariant:"${DV_VERSION:-latest}" \
        /opt/deepvariant/bin/run_deepvariant \
            --model_type=WGS --ref=/ref/"${REF_NAME}" \
            --reads=/bam/sim.final.bam --output_vcf=/output/DeepVariant/dv_sim.vcf.gz \
            --num_shards="${DV_SHARDS}" --intermediate_results_dir=/output/DeepVariant/dv_tmp \
        2> "$DV_DIR/dv_sim.log"
fi
# DeepVariant (docker) writes root-owned files; cleanup/chown must NOT abort the run
rm -rf "$DV_DIR/dv_tmp" 2>/dev/null || true
chown -R "$(id -u):$(id -g)" "$VCFEVAL_DIR" 2>/dev/null || true

# --- Build RTG SDF of the reference (once) ---
[ -d "$REF_SDF" ] || conda run -n rtg-env rtg format -o "$REF_SDF" "$REF"

# --- Split the truth set into SNP-only and indel-only (once) ---
TRUTH_SNP="$VCFEVAL_DIR/truth_snp.vcf.gz"
TRUTH_INDEL="$VCFEVAL_DIR/truth_indel.vcf.gz"
bcftools view -v snps   "$TRUTH_VCF" -O z -o "$TRUTH_SNP";   bcftools index -t -f "$TRUTH_SNP"
bcftools view -v indels "$TRUTH_VCF" -O z -o "$TRUTH_INDEL"; bcftools index -t -f "$TRUTH_INDEL"

# Pull Precision / Recall / F-measure from a vcfeval summary.txt. Prefer the
# 'None' row (all calls, no score threshold); the last 3 columns are always
# Precision, Sensitivity(Recall), F-measure regardless of RTG version.
extract_prf () {
    awk '$1!="Threshold" && $1 !~ /^-+$/ && NF>=3 {
            p=$(NF-2); r=$(NF-1); f=$NF;
            if ($1=="None") { np=p; nr=r; nf=f } else { lp=p; lr=r; lf=f }
         }
         END { if (np!="") print np, nr, nf; else if (lp!="") print lp, lr, lf; else print "NA NA NA" }' "$1/summary.txt"
}

# --- Score each caller against truth, split by variant type -> P/R/F1 ---
declare -A CDIR=(  [gatk]="$GATK_DIR" [dv]="$DV_DIR" )
declare -A CNAME=( [gatk]="GATK"      [dv]="DeepVariant" )
for CALLER in gatk dv; do
    D="${CDIR[$CALLER]}"
    CVCF="$D/${CALLER}_sim.vcf.gz"
    bcftools index -t -f "$CVCF" 2>/dev/null || true
    bcftools view -v snps   "$CVCF" -O z -o "$D/${CALLER}_snp.vcf.gz";   bcftools index -t -f "$D/${CALLER}_snp.vcf.gz"
    bcftools view -v indels "$CVCF" -O z -o "$D/${CALLER}_indel.vcf.gz"; bcftools index -t -f "$D/${CALLER}_indel.vcf.gz"
    rm -rf "$D/vcfeval" "$D/vcfeval_snp" "$D/vcfeval_indel"
    echo "[VCFEVAL] Scoring ${CNAME[$CALLER]} (all / SNP / indel) ..."
    conda run -n rtg-env rtg vcfeval -b "$TRUTH_VCF"   -c "$CVCF"                     -t "$REF_SDF" -o "$D/vcfeval"
    conda run -n rtg-env rtg vcfeval -b "$TRUTH_SNP"   -c "$D/${CALLER}_snp.vcf.gz"   -t "$REF_SDF" -o "$D/vcfeval_snp"
    conda run -n rtg-env rtg vcfeval -b "$TRUTH_INDEL" -c "$D/${CALLER}_indel.vcf.gz" -t "$REF_SDF" -o "$D/vcfeval_indel"
done

# --- Collate Table 3 (Precision / Recall / F1, split SNP vs indel) ---
REPORT="$VCFEVAL_DIR/Table3_precision_recall_f1.txt"
{
  echo "=== TABLE 3: Caller accuracy vs simulated truth set (RTG vcfeval) ==="
  printf "%-12s %-6s %10s %10s %10s\n" "Caller" "Type" "Precision" "Recall" "F1"
  echo   "---------------------------------------------------------------"
  for CALLER in gatk dv; do
      D="${CDIR[$CALLER]}"
      printf "%-12s %-6s %10s %10s %10s\n" "${CNAME[$CALLER]}" "SNP"   $(extract_prf "$D/vcfeval_snp")
      printf "%-12s %-6s %10s %10s %10s\n" "${CNAME[$CALLER]}" "INDEL" $(extract_prf "$D/vcfeval_indel")
      printf "%-12s %-6s %10s %10s %10s\n" "${CNAME[$CALLER]}" "All"   $(extract_prf "$D/vcfeval")
  done
} | tee "$REPORT"

echo "Benchmark scoring complete -> $REPORT"
