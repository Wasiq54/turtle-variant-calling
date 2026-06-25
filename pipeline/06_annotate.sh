#!/bin/bash
# ============================================================
# Step 6: Variant annotation with SnpEff
# Uses the closest available annotation (GCF_015237465.2)
# ============================================================
set -euo pipefail
source "$(dirname "$0")/00_setup.sh"
start_log "06_annotate"

FINAL_VCF="$OUT_DIR/filtered/final_filtered.vcf.gz"
ANN_VCF="$OUT_DIR/annotated/final_annotated.vcf.gz"
ANN_STATS="$OUT_DIR/annotated/snpeff_stats.html"

# SnpEff database name for Chelonia mydas (NCBI release 103)
# Check: snpeff databases | grep -i chelonia
SNPEFF_DB="Chelonia_mydas"

if ! command -v snpeff &>/dev/null && ! command -v snpEff &>/dev/null; then
    echo "[ERROR] SnpEff not found. Install with: conda install -c bioconda snpeff"
    echo "        Or use VEP: conda install -c bioconda ensembl-vep"
    exit 1
fi

echo "[ANNOTATE] Running SnpEff on final filtered VCF ..."
snpeff ann \
    -v "$SNPEFF_DB" \
    -stats "$ANN_STATS" \
    "$FINAL_VCF" \
    | bgzip -c > "$ANN_VCF"
bcftools index -t "$ANN_VCF"

echo "Annotation complete -> $ANN_VCF"
echo "Stats report -> $ANN_STATS"
