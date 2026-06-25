# Chelonia mydas WGS Variant Calling & Benchmarking Pipeline

A reproducible bioinformatics framework for variant discovery, caller
benchmarking, and functional annotation in small-cohort non-model vertebrate
genomes, applied to green sea turtle (*Chelonia mydas*) whole-genome
sequencing data.

The pipeline runs **two independent callers** — GATK HaplotypeCaller and
Google DeepVariant — applies an identical caller-agnostic genotype filter to
both, measures their real-data concordance, and scores each against a
**simulated truth set** (no truth set exists for a non-model species) using
RTG `vcfeval`.

## Associated Paper
> [Author list] (2026). A Reproducible Bioinformatics Framework for Variant
> Discovery, Caller Benchmarking, and Annotation in Small-Cohort Non-Model
> Vertebrate Genomes: A Green Sea Turtle (*Chelonia mydas*) Case Study.
> *[Journal]* [submitted].
>
> _Note: update the author list, journal, and DOI before publication._

## Dataset
- 6 WGS samples: wild-healthy (n=2), captive-healthy (n=2), captive-unhealthy (n=2)
- Species: *Chelonia mydas* (green sea turtle)
- Reference: NCBI GCF_015237465.2 (rCheMyd1.pri.v2)
- Sequencing: Illumina NovaSeq, 150 bp paired-end
- Processed outputs (VCFs, benchmark results, annotation) deposited at Zenodo: [DOI]
- Raw BAMs and all large data files are **not** in this repository — they are
  archived on Zenodo. This repo contains the analysis code only.

## Pipeline Steps

| Script | Step |
|--------|------|
| `00_setup.sh` | Shared paths, threading, output dirs, logging helper (sourced by every step) |
| `01_index_bams.sh` | Index input BAM files (samtools) |
| `02_bam_qc.sh` | Alignment QC: flagstat + mosdepth coverage (optional samtools stats / MultiQC) |
| `03a_gatk_haplotypecaller.sh` | GATK track: per-sample GVCF, scatter-gathered (uses `03a_hc_worker.sh`) |
| `03a_hc_worker.sh` | Worker: runs HaplotypeCaller on one interval shard (called in parallel) |
| `03b_deepvariant.sh` | DeepVariant track: per-sample GVCF via Docker (CNN caller) |
| `04a_gatk_joint_genotyping.sh` | GATK track: CombineGVCFs + GenotypeGVCFs |
| `04b_glnexus_merge.sh` | DeepVariant track: joint genotyping with GLnexus |
| `05_variant_filter.sh` | GATK hard-filtering of SNPs and indels (Broad thresholds) |
| `05b_common_genotype_filter.sh` | Identical caller-agnostic DP/GQ/biallelic filter applied to both callers |
| `06a_compare_callers.sh` | Real-data concordance GATK vs DeepVariant → consensus set (Figure 3) |
| `06b_simulate_truth.sh` | Build a phased-diploid simulated truth set (simuG → ART → bwa) |
| `06c_benchmark_vcfeval.sh` | Score both callers vs truth with RTG vcfeval → Precision/Recall/F1 (Table 3) |
| `07_annotate.sh` | Functional annotation of the high-confidence consensus set (SnpEff) |
| `08_summary_report.sh` | Paper-ready summary tables |

## Requirements

Tools are run from named conda environments (`conda run -n <env>`) and Docker.
Pin versions to match the manuscript Methods.

| Tool | Version | Used in |
|------|---------|---------|
| GATK | 4.6.2 | 03a, 04a, 05, 06b, 06c |
| Google DeepVariant | 1.9.0 (Docker, CPU image; GPU optional) | 03b, 06c |
| GLnexus | (DeepVariantWGS config) | 04b |
| samtools | 1.19.2 | 01, 02, 06b |
| bcftools | 1.19 | 04b, 05, 05b, 06a, 06c, 07, 08 |
| mosdepth | — | 02 |
| GNU parallel | — | 03a |
| simuG | — | 06b |
| ART (art_illumina) | — | 06b |
| bwa | — | 06b |
| RTG Tools (vcfeval) | — | 06c |
| SnpEff | — (custom *Chelonia_mydas* DB, NCBI release 103) | 07 |
| Docker | — | 03b, 06c (DeepVariant) |

Conda environments expected by the scripts: `gatk-env`, `glnexus-env`,
`simug-env`, `art-env`, `rtg-env`, `snpeff-env`.

## Usage

```bash
git clone https://github.com/<user>/turtle-variant-calling
cd turtle-variant-calling

# Point the pipeline at your reference and BAMs (see 00_setup.sh header)
export REF=/path/to/reference.fasta      # indexed: .fai + GATK .dict
export BAM_DIR=/path/to/bams             # contains <SAMPLE>.final.bam
# export OUT_DIR=/path/to/results        # optional; default is ./results

bash pipeline/01_index_bams.sh
bash pipeline/02_bam_qc.sh
# GATK track
bash pipeline/03a_gatk_haplotypecaller.sh
bash pipeline/04a_gatk_joint_genotyping.sh
bash pipeline/05_variant_filter.sh
# DeepVariant track
bash pipeline/03b_deepvariant.sh
bash pipeline/04b_glnexus_merge.sh
# Common filter + benchmarking
bash pipeline/05b_common_genotype_filter.sh
bash pipeline/06a_compare_callers.sh
bash pipeline/06b_simulate_truth.sh
bash pipeline/06c_benchmark_vcfeval.sh
# Annotation + summary
bash pipeline/07_annotate.sh
bash pipeline/08_summary_report.sh
```

Most steps are resumable (they skip outputs that already exist). `00_setup.sh`
is sourced automatically by each script — you do not run it directly.

## Output Structure

```
results/
├── 01_alignment_qc/          # flagstat + (optional) samtools stats, MultiQC
├── 02_coverage/              # mosdepth per-sample coverage
├── 03_gatk_calls/            # GATK per-sample GVCFs + joint VCF
├── 04_deepvariant_calls/     # DeepVariant per-sample GVCFs + GLnexus joint VCF
├── 05_filtered_variants/     # hard-filtered + common-filtered call sets
├── 06_benchmark/             # caller concordance, simulated truth set, vcfeval scores
├── 07_functional_annotation/ # SnpEff-annotated consensus VCF + impact tables
├── 08_summary_tables/        # paper-ready summary tables
└── logs/                     # timestamped per-step logs
```

## License
MIT License

## Contact
Wasiq Aslam — wasiqaslam54@gmail.com
