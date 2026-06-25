#!/bin/bash
# ============================================================
# Step 2: BAM-level QC — FAST version
# Core metrics (flagstat + mosdepth) for all 6 samples in parallel.
# Heavy samtools stats is OPTIONAL (off by default; it is slow).
# Machine has 80 threads.
# ============================================================
set -euo pipefail
source "$(dirname "$0")/00_setup.sh"
start_log "02_bam_qc"

# Set to 1 to also run the slow detailed samtools stats (supplementary only)
RUN_FULL_STATS="${RUN_FULL_STATS:-0}"

# --- Core QC for one sample: flagstat (fast) + mosdepth (fast) ---
qc_one() {
    local SAMPLE="$1"
    local BAM="$BAM_DIR/${SAMPLE}.final.bam"
    echo "[START] $SAMPLE"

    # Alignment summary — total reads, mapping %, duplicates (seconds)
    samtools flagstat -@ 4 "$BAM" > "$OUT_DIR/qc/${SAMPLE}.flagstat.txt"

    # Coverage — mean depth + % genome >=10x (minutes). Cap at 4 threads (mosdepth max useful).
    mosdepth --threads 4 --no-per-base --fast-mode \
        "$OUT_DIR/coverage/${SAMPLE}" "$BAM"

    echo "[DONE]  $SAMPLE"
}
export -f qc_one
export BAM_DIR OUT_DIR

# Launch all 6 samples in parallel
for SAMPLE in $SAMPLES; do
    qc_one "$SAMPLE" &
done
wait

echo ""
echo "Core QC complete (flagstat + coverage)."

# --- OPTIONAL: slow detailed stats (only if RUN_FULL_STATS=1) ---
if [ "$RUN_FULL_STATS" = "1" ]; then
    echo "[FULL STATS] Running detailed samtools stats (slow) ..."
    for SAMPLE in $SAMPLES; do
        BAM="$BAM_DIR/${SAMPLE}.final.bam"
        samtools stats -@ "$THREADS_PER_SAMPLE" "$BAM" > "$OUT_DIR/qc/${SAMPLE}.stats.txt" &
    done
    wait
    echo "[FULL STATS] Done."
else
    echo "[INFO] Detailed samtools stats skipped (run with RUN_FULL_STATS=1 to enable)."
fi

# --- Aggregate with MultiQC if available ---
if command -v multiqc &>/dev/null; then
    multiqc "$OUT_DIR/qc" "$OUT_DIR/coverage" -o "$OUT_DIR/qc" -n multiqc_report 2>/dev/null
    echo "[MULTIQC] Report: $OUT_DIR/qc/multiqc_report.html"
fi

echo ""
echo "=== Quick Table 1 preview ==="
printf "%-8s %-16s %-10s %-12s\n" "Sample" "TotalReads" "Mapped%" "MeanDepth"
for SAMPLE in $SAMPLES; do
    FS="$OUT_DIR/qc/${SAMPLE}.flagstat.txt"
    SUM="$OUT_DIR/coverage/${SAMPLE}.mosdepth.summary.txt"
    TOTAL=$(grep "in total" "$FS" 2>/dev/null | awk '{print $1}')
    MAPPCT=$(grep "mapped (" "$FS" 2>/dev/null | head -1 | grep -oP '\(\K[^%]+')
    DEPTH=$(awk '$1=="total"{print $4}' "$SUM" 2>/dev/null)
    printf "%-8s %-16s %-10s %-12s\n" "$SAMPLE" "${TOTAL:-NA}" "${MAPPCT:-NA}" "${DEPTH:-NA}"
done

echo ""
echo "BAM QC complete. Results in $OUT_DIR/qc/ and $OUT_DIR/coverage/"
