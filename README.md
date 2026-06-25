# Chelonia mydas WGS Variant Calling Pipeline

A reproducible bioinformatics framework for variant discovery and annotation
in small-cohort non-model vertebrate genomes, applied to green sea turtle
(*Chelonia mydas*) whole-genome sequencing data.

## Associated Paper
> [Your Name] et al. (2026). A Reproducible Bioinformatics Framework for
> Variant Discovery and Annotation in Small-Cohort Non-Model Vertebrate Genomes:
> A Green Sea Turtle (*Chelonia mydas*) Case Study.
> *BMC Bioinformatics* [submitted]

## Dataset
- 6 WGS samples: wild-healthy (n=2), captive-healthy (n=2), captive-unhealthy (n=2)
- Species: *Chelonia mydas* (green sea turtle)
- Reference: NCBI GCF_015237465.2 (rCheMyd1.pri.v2)
- Processed outputs deposited at Zenodo: [DOI]

## Pipeline Steps

| Script | Step |
|--------|------|
| `00_setup.sh` | Create output directories |
| `01_index_bams.sh` | Index BAM files (samtools) |
| `02_bam_qc.sh` | Alignment QC (flagstat, stats, coverage) |
| `03_haplotypecaller_gvcf.sh` | Per-sample GVCF (GATK HaplotypeCaller) |
| `04_joint_genotyping.sh` | Joint genotyping (GATK GenotypeGVCFs) |
| `05_variant_filter.sh` | Hard filtering SNPs + indels |
| `06_annotate.sh` | Functional annotation (SnpEff) |
| `07_summary_report.sh` | Summary tables for publication |

## Requirements

| Tool | Version |
|------|---------|
| GATK | 4.6.2 |
| samtools | 1.19.2 |
| bcftools | 1.19 |
| SnpEff | [version] |

## Usage

```bash
git clone https://github.com/[yourusername]/chelonia-mydas-wgs-pipeline
cd chelonia-mydas-wgs-pipeline

# Edit 00_setup.sh to set your REF and BAM_DIR paths
bash pipeline/00_setup.sh
bash pipeline/01_index_bams.sh
bash pipeline/02_bam_qc.sh
bash pipeline/03_haplotypecaller_gvcf.sh
bash pipeline/04_joint_genotyping.sh
bash pipeline/05_variant_filter.sh
bash pipeline/06_annotate.sh
bash pipeline/07_summary_report.sh
```

## Output Structure

```
results/
├── qc/           # flagstat + samtools stats per sample
├── coverage/     # per-sample depth files
├── gvcf/         # per-sample .g.vcf.gz
├── vcf/          # joint genotyped all_samples.vcf.gz
├── filtered/     # PASS-only final_filtered.vcf.gz
├── annotated/    # SnpEff annotated VCF + HTML report
└── summary_report.txt
```

## License
MIT License

## Contact
[Your Name] — [your email]
