#!/bin/bash
# ============================================================
# Step 6b (BENCHMARK leg 2): build a SIMULATED TRUTH SET
# Non-model species => NO truth set exists. We MANUFACTURE ground truth:
#   simuG injects known variants -> ART simulates reads -> bwa aligns ->
#   callers must re-discover them; vcfeval (06c) scores against this truth.
#
# DIPLOID handling (the #1 reviewer catch): a real sample is diploid. We
# assign PHASED genotypes to the injected variants, build two haplotype
# genomes (bcftools consensus -H1/-H2), simulate each at HALF depth, and
# concatenate -> realistic het/hom mix (NOT all-homozygous).
#
# truth.vcf is an OUTPUT of this step (created by simuG + the GT assignment),
# NOT something downloaded. It is consumed only by 06c (vcfeval).
# ============================================================
set -euo pipefail
source "$(dirname "$0")/00_setup.sh"
start_log "06b_simulate_truth"

# --- Parameters (override via env; match real data) ---
SNP_COUNT="${SNP_COUNT:-50000}"
INDEL_COUNT="${INDEL_COUNT:-5000}"
TARGET_DEPTH="${TARGET_DEPTH:-50}"     # ~ real mean depth from QC (39-58x, mean ~51)
READLEN="${READLEN:-150}"
FRAG_MEAN="${FRAG_MEAN:-334}"          # real median insert size (TLEN) from BAMs
FRAG_SD="${FRAG_SD:-50}"
ART_SS="${ART_SS:-HSXt}"               # real data = Illumina NovaSeq 150bp; ART has no
                                       # NovaSeq profile, HSXt (HiSeqX TruSeq 150bp) is closest
SEED="${SEED:-1}"
HALF_DEPTH=$(awk "BEGIN{printf \"%.1f\", $TARGET_DEPTH/2}")

W="$TRUTH_DIR/work"; mkdir -p "$W"
TRUTH_VCF="$TRUTH_DIR/truth.vcf.gz"
SIM_BAM="$TRUTH_DIR/sim.final.bam"

# --- 1) Inject known variants (simuG writes the variant list = raw truth) ---
echo "[SIMUG] Injecting $SNP_COUNT SNPs + $INDEL_COUNT indels ..."
conda run -n simug-env simuG \
    -refseq "$REF" \
    -snp_count "$SNP_COUNT" \
    -indel_count "$INDEL_COUNT" \
    -prefix "$W/sim" \
    -seed "$SEED"
# outputs: $W/sim.simseq.genome.fa, $W/sim.refseq2simseq.SNP.vcf, ...INDEL.vcf

# --- 2) Pool SNP + INDEL into one sorted sites VCF ---
echo "[POOL] Combining SNP + INDEL ..."
for t in SNP INDEL; do
    bgzip -f "$W/sim.refseq2simseq.${t}.vcf"
    bcftools index -t -f "$W/sim.refseq2simseq.${t}.vcf.gz"
done
bcftools concat -a "$W/sim.refseq2simseq.SNP.vcf.gz" "$W/sim.refseq2simseq.INDEL.vcf.gz" \
    | bcftools sort -O v -o "$W/pool.sites.vcf"

# --- 3) Assign PHASED diploid genotypes (~35% hom-alt, rest het split by hap) ---
# Adds a single sample "sim" with GT in {1|1, 1|0, 0|1}. This makes the truth
# diploid and lets bcftools consensus build two distinct haplotypes.
echo "[GT] Assigning phased diploid genotypes ..."
awk 'BEGIN{srand('"$SEED"')}
     /^##/ {print; next}
     /^#CHROM/ {
        print "##FORMAT=<ID=GT,Number=1,Type=String,Description=\"Genotype\">";
        print $0"\tFORMAT\tsim"; next }
     {
        r=rand();
        if (r<0.35) gt="1|1"; else if (r<0.675) gt="1|0"; else gt="0|1";
        print $0"\tGT\t"gt }' "$W/pool.sites.vcf" \
    | bgzip -c > "$TRUTH_VCF"
bcftools index -t "$TRUTH_VCF"

# --- 4) Build two haplotype genomes from the phased truth ---
echo "[CONSENSUS] Building haplotype genomes ..."
samtools faidx "$REF" 2>/dev/null || true
bcftools consensus -H 1 -f "$REF" "$TRUTH_VCF" > "$W/hap1.fa"
bcftools consensus -H 2 -f "$REF" "$TRUTH_VCF" > "$W/hap2.fa"

# --- 5) Simulate reads from EACH haplotype at HALF depth (ART) ---
echo "[ART] Simulating reads at ${HALF_DEPTH}x per haplotype ..."
conda run -n art-env art_illumina -ss "$ART_SS" -i "$W/hap1.fa" -p -na \
    -l "$READLEN" -f "$HALF_DEPTH" -m "$FRAG_MEAN" -s "$FRAG_SD" -o "$W/hap1_R" -rs "$SEED"
conda run -n art-env art_illumina -ss "$ART_SS" -i "$W/hap2.fa" -p -na \
    -l "$READLEN" -f "$HALF_DEPTH" -m "$FRAG_MEAN" -s "$FRAG_SD" -o "$W/hap2_R" -rs $((SEED+1))

cat "$W/hap1_R1.fq" "$W/hap2_R1.fq" > "$W/sim_R1.fq"
cat "$W/hap1_R2.fq" "$W/hap2_R2.fq" > "$W/sim_R2.fq"

# --- 6) Align combined reads to the ORIGINAL reference -> simulated BAM ---
echo "[ALIGN] bwa mem -> sort -> markdup ..."
bwa mem -t 16 -M -R '@RG\tID:sim\tSM:sim\tPL:ILLUMINA\tLB:sim' \
    "$REF" "$W/sim_R1.fq" "$W/sim_R2.fq" \
    | samtools sort -@ 8 -o "$W/sim.sorted.bam"
conda run -n gatk-env gatk MarkDuplicates \
    -I "$W/sim.sorted.bam" -O "$SIM_BAM" -M "$W/sim.dup_metrics.txt" --TMP_DIR /tmp
samtools index "$SIM_BAM"

echo "Simulated truth set complete:"
echo "  truth VCF : $TRUTH_VCF"
echo "  sim BAM   : $SIM_BAM   (call this with BOTH callers, then run 06c)"
bcftools stats "$TRUTH_VCF" | grep "^SN"
