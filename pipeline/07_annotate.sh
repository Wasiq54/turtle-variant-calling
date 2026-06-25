#!/bin/bash
# ============================================================
# Step 7: Functional annotation with SnpEff
#   - Custom-built Chelonia_mydas database (NCBI GCF_015237465.2, release 103)
#   - Annotates the HIGH-CONFIDENCE CONSENSUS set: variants called by BOTH
#     GATK and DeepVariant (normalised, from Step 6a) -> fewest false positives
#     for downstream candidate-gene interpretation.
# Notes:
#   * SnpEff annotation is single-threaded (tool limitation); threads are used
#     for the bcftools/bgzip compression + indexing around it.
#   * SnpEff needs a large heap for this genome -> -Xmx48g (default OOMs).
# ============================================================
set -euo pipefail
source "$(dirname "$0")/00_setup.sh"
start_log "07_annotate"

THREADS=16
SNPEFF_ENV="snpeff-env"
SNPEFF_DB="Chelonia_mydas"
JAVA_MEM="-Xmx48g"

# --- Input: high-confidence consensus (GATK ∩ DeepVariant), normalised (Step 6a) ---
CONSENSUS="$CONCORDANCE_DIR/isec/0002.vcf"
IN_VCF="$ANNOT_DIR/highconf_consensus.vcf.gz"

ANN_VCF="$ANNOT_DIR/highconf_consensus.annotated.vcf.gz"
HTML_STATS="$ANNOT_DIR/snpeff_stats.html"
CSV_STATS="$ANNOT_DIR/snpeff_stats.csv"
HIGHMOD_VCF="$ANNOT_DIR/highconf_consensus.HIGH_MODERATE.vcf.gz"

mkdir -p "$ANNOT_DIR"
[ -f "$CONSENSUS" ] || { echo "[ERROR] consensus $CONSENSUS not found — run 06a first"; exit 1; }

# --- 1) Compress + index the consensus set (threaded) ---
echo "[PREP] bgzip + index consensus set ..."
bcftools view "$CONSENSUS" --threads "$THREADS" -O z -o "$IN_VCF"
bcftools index -t -f --threads "$THREADS" "$IN_VCF"
echo -n "[PREP] variants to annotate: "; bcftools view -H "$IN_VCF" | wc -l

# --- 2) SnpEff annotation (single-threaded; large heap) ---
echo "[ANNOTATE] SnpEff ($SNPEFF_DB) ..."
conda run --no-capture-output -n "$SNPEFF_ENV" bash -lc \
  "_JAVA_OPTIONS='$JAVA_MEM' snpEff -v -stats '$HTML_STATS' -csvStats '$CSV_STATS' '$SNPEFF_DB' '$IN_VCF'" \
  | bgzip -@ "$THREADS" -c > "$ANN_VCF"
bcftools index -t -f --threads "$THREADS" "$ANN_VCF"

# --- 3) Extract HIGH + MODERATE impact variants (candidate set -> Table 5) ---
# IMPACT is the 3rd pipe-field of each ANN entry; HIGH/MODERATE only occur there.
echo "[FILTER] extracting HIGH + MODERATE impact variants ..."
{ bcftools view -h "$ANN_VCF"
  bcftools view -H "$ANN_VCF" | grep -E '\|(HIGH|MODERATE)\|' || true
} | bgzip -@ "$THREADS" -c > "$HIGHMOD_VCF"
bcftools index -t -f --threads "$THREADS" "$HIGHMOD_VCF"

echo "=================================================="
echo "Annotation complete:"
echo "  annotated VCF : $ANN_VCF"
echo "  HIGH/MOD VCF  : $HIGHMOD_VCF  ($(bcftools view -H "$HIGHMOD_VCF" | wc -l) variants)"
echo "  impact stats  : $CSV_STATS  (-> Table 4)   + $HTML_STATS"
echo "  per-gene file : $ANNOT_DIR/snpeff_stats.genes.txt (SnpEff; -> Table 5 candidates)"
