#!/bin/bash

#SBATCH -J realblacklist
#SBATCH -o bl_filter.%j
#SBATCH -p normal
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 03:00:00
#SBATCH --array=1-48%6





module load tacc-apptainer
module load biocontainers
module unload xalt
module load bedtools

#set -euo pipefail

# ---------------- Variables ----------------

# ---------------- Paths ----------------
BAM_LIST="/scratch/09196/reneem/DOX_ChIP/bam_list.txt"
BAM_DIR="/scratch/09196/reneem/DOX_ChIP/final_bam_folder"
FILTERED_DIR="/scratch/09196/reneem/DOX_ChIP/bl_filtered_bams"
BLACKLIST="/scratch/09196/reneem/DOX_ChIP/hg38-blacklist.v2.bed"
SAMTOOLS_SIF="/scratch/09196/reneem/DOX_ChIP/samtools_1.9--h91753b0_5.sif"

mkdir -p "$FILTERED_DIR" logs

# ---------------- Select BAM ----------------
BAM=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$BAM_LIST")
SAMPLE=$(basename "$BAM" .proper_unique.noChrM.sorted.dedup.bam)
OUT_BAM="$FILTERED_DIR/${SAMPLE}.filtered.bam"

echo "[$(date)] Task ${SLURM_ARRAY_TASK_ID}"
echo "Sample: $SAMPLE"

# ---------------- Skip if done ----------------
if [[ -s "$OUT_BAM" ]]; then
    echo "Filtered BAM exists — skipping."
    exit 0
fi

# ---------------- Count original reads ----------------
ORIG_COUNT=$(apptainer exec "$SAMTOOLS_SIF" samtools view -c "$BAM")
echo "Original reads: $ORIG_COUNT"

# ---------------- Blacklist filtering (BEDTOOLS) ----------------
echo "Filtering blacklist regions with bedtools..."

bedtools intersect -v \
    -abam "$BAM" \
    -b "$BLACKLIST" \
    > "$OUT_BAM"

# ---------------- Index filtered BAM ----------------
apptainer exec "$SAMTOOLS_SIF" samtools index "$OUT_BAM"

# ---------------- Count filtered reads ----------------
FILT_COUNT=$(apptainer exec "$SAMTOOLS_SIF" samtools view -c "$OUT_BAM")
echo "Filtered reads: $FILT_COUNT"

echo "[$(date)] Done."

