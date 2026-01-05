#!/bin/bash

#SBATCH -J realblacklist
#SBATCH -o bl_filter.%j
#SBATCH -p normal
#SBATCH -N 1
#SBATCH -n 32
#SBATCH -t 10:00:00






module load tacc-apptainer
module load biocontainers
module unload xalt
module load bedtools

#set -euo pipefail

# ---------------- Variables ----------------
THREADS=32

BAM_DIR="/scratch/09196/reneem/DOX_ChIP/final_bam_folder"
FILTERED_DIR="/scratch/09196/reneem/DOX_ChIP/bl_filtered_bams"
BLACKLIST="/scratch/09196/reneem/DOX_ChIP/hg38-blacklist.v2.bed"
SAMTOOLS_SIF="/scratch/09196/reneem/DOX_ChIP/samtools_1.9--h91753b0_5.sif"

mkdir -p "$FILTERED_DIR"

echo "Started at: $(date)"
echo "Using $THREADS threads"
echo

# ---------------- Loop through BAM files ----------------
for BAM in "$BAM_DIR"/*.proper_unique.noChrM.sorted.dedup.bam; do
    SAMPLE=$(basename "$BAM" .proper_unique.noChrM.sorted.dedup.bam)
     OUT_BAM="$FILTERED_DIR/${SAMPLE}.filtered.bam"

    echo "Processing sample: $SAMPLE"

    # Skip if already filtered + indexed
    if [[ -f "$OUT_BAM" && -f "$OUT_BAM.bai" ]]; then
        echo "  Skipping (already filtered)"
        echo
        continue
    fi

    # Count original reads
    ORIG_COUNT=$(apptainer exec "$SAMTOOLS_SIF" samtools view -c "$BAM")
    echo "  Original reads: $ORIG_COUNT"

    # Blacklist filtering (correct direction)
    echo "  Removing blacklist regions..."
    bedtools intersect -v \
        -abam "$BAM" \
        -b "$BLACKLIST" \
        > "$OUT_BAM"

    # Index filtered BAM
    apptainer exec "$SAMTOOLS_SIF" samtools index -@ "$THREADS" "$OUT_BAM"

    # Count filtered reads
    FILTERED_COUNT=$(apptainer exec "$SAMTOOLS_SIF" samtools view -c "$OUT_BAM")
    echo "  Filtered reads: $FILTERED_COUNT"

    echo "--------------------------------------------"
done

echo "Finished at: $(date)" 
