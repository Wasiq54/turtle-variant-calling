#!/bin/bash
# ============================================================
# Step 3a (GATK track): HaplotypeCaller — per-sample GVCF
# ONE SAMPLE AT A TIME, each sample scatter-gathered across the machine:
# for each sample the genome is split into shards, HaplotypeCaller runs on
# all shards in parallel (GNU parallel), then the shards are gathered into
# one GVCF. The next sample starts only after the current one finishes.
# Order: CH1_W -> CH2_W -> S1_H -> S2_H -> S3_U -> S4_U
#
# Fully resumable (skips finished shards/samples) + per-job + master logging.
#
# Tunables (env overrides):
#   HC_SCATTER       genome pieces per sample   (default 72)
#   HC_JOBS          parallel jobs at once       (default 36)
#   HC_HMM_THREADS   pairHMM threads per job     (default 2)
#   HC_XMX           JVM heap per job            (default 6g)
# ============================================================
set -uo pipefail
source "$(dirname "$0")/00_setup.sh"
start_log "03a_gatk_haplotypecaller"
HERE="$(cd "$(dirname "$0")" && pwd)"

SCATTER="${HC_SCATTER:-72}"
JOBS="${HC_JOBS:-36}"
export HC_HMM_THREADS="${HC_HMM_THREADS:-2}"
export HC_XMX="${HC_XMX:-6g}"

WORKDIR="$LOG_DIR/03a_gatk"
IVL_DIR="$GATK_GVCF_DIR/intervals"
mkdir -p "$WORKDIR/jobs" "$IVL_DIR"

# --- Prep (once): split genome into balanced intervals (cached) ---
if ! ls "$IVL_DIR"/*-scattered.interval_list >/dev/null 2>&1; then
    echo "[SPLIT] Splitting genome into $SCATTER intervals ..."
    conda run -n gatk-env gatk SplitIntervals -R "$REF" \
        --scatter-count "$SCATTER" -O "$IVL_DIR" \
        2> "$WORKDIR/split_intervals.log"
fi
mapfile -t IVLS < <(ls "$IVL_DIR"/*-scattered.interval_list | sort)
EXPECTED=${#IVLS[@]}
echo "[INFO] Genome split into $EXPECTED pieces."
echo "[INFO] Processing samples ONE AT A TIME: $SAMPLES"
echo "==================================================================="
echo " >>> MONITOR (in another terminal): <<<"
echo "   finished pieces (current sample): wc -l $WORKDIR/parallel_joblog_<SAMPLE>.tsv"
echo "   finished sample files            : ls $GATK_GVCF_DIR/*.g.vcf.gz"
echo "   a single piece's GATK output     : tail -f $WORKDIR/jobs/<SAMPLE>.0000.log"
echo "   master log                       : $LOG_DIR/03a_gatk_haplotypecaller_*.log"
echo "==================================================================="

SAMPLE_NUM=0
TOTAL_SAMPLES=$(echo $SAMPLES | wc -w)
for SAMPLE in $SAMPLES; do
    SAMPLE_NUM=$((SAMPLE_NUM+1))
    FINAL="$GATK_GVCF_DIR/${SAMPLE}.g.vcf.gz"
    echo ""
    echo "############ SAMPLE $SAMPLE_NUM/$TOTAL_SAMPLES : $SAMPLE ############"

    if [ -f "$FINAL" ]; then
        echo "[SKIP] $SAMPLE already complete -> $FINAL"
        continue
    fi

    # 1) build this sample's shard job list
    JOBLIST="$WORKDIR/joblist_${SAMPLE}.tsv"
    JOBLOG="$WORKDIR/parallel_joblog_${SAMPLE}.tsv"
    : > "$JOBLIST"
    idx=0
    for IVL in "${IVLS[@]}"; do
        printf "%s\t%s\t%04d\n" "$SAMPLE" "$IVL" "$idx" >> "$JOBLIST"
        idx=$((idx+1))
    done

    # 2) run all shards for THIS sample in parallel
    echo "[RUN] $SAMPLE: $EXPECTED pieces, $JOBS in parallel ..."
    parallel --jobs "$JOBS" --colsep '\t' --joblog "$JOBLOG" --bar \
        "$HERE/03a_hc_worker.sh" {1} {2} {3} < "$JOBLIST" || \
        echo "[WARN] $SAMPLE: some pieces reported non-zero; verifying before gather"

    # 3) verify all pieces present, then gather into one GVCF
    SHARD_DIR="$GATK_GVCF_DIR/shards/$SAMPLE"
    mapfile -t SHARDS < <(ls "$SHARD_DIR"/*.g.vcf.gz 2>/dev/null | sort)
    if [ "${#SHARDS[@]}" -ne "$EXPECTED" ]; then
        echo "[ERROR] $SAMPLE has ${#SHARDS[@]}/$EXPECTED pieces — re-run this script to resume."
        exit 1
    fi

    echo "[GATHER] $SAMPLE: merging $EXPECTED pieces -> $FINAL"
    I_ARGS=(); for s in "${SHARDS[@]}"; do I_ARGS+=(-I "$s"); done
    conda run -n gatk-env gatk GatherVcfs "${I_ARGS[@]}" -O "$FINAL" \
        2> "$WORKDIR/gather_${SAMPLE}.log"
    bcftools index -t "$FINAL"

    # 4) free space: remove this sample's piece files now it is merged
    rm -rf "$SHARD_DIR"
    echo "[DONE] $SAMPLE COMPLETE -> $FINAL"
done

echo ""
echo "=== ALL SAMPLES COMPLETE ==="
ls -la "$GATK_GVCF_DIR"/*.g.vcf.gz
echo "GATK HaplotypeCaller step finished. Next step: 04a (joint genotyping)."
