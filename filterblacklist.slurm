#!/bin/bash

#SBATCH -J blacklist
#SBATCH -o Bl_filter.%j
#SBATCH -p normal
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 18:00:00






module load tacc-apptainer
module load biocontainers
module unload xalt
module load bedtools

set -euo pipefail

# ---------------- Variables ----------------
BAM_DIR="/scratch/09196/reneem/DOX_ChIP/final_bam_folder"
FILTERED_DIR="/scratch/09196/reneem/DOX_ChIP/bl_filtered_bams"
BLACKLIST="/scratch/09196/reneem/DOX_ChIP/hg38-blacklist.v2.bed"
SAMTOOLS_CONTAINER="/scratch/09196/reneem/DOX_ChIP/samtools_1.9--h91753b0_5.sif"

mkdir -p "$FILTERED_DIR"

# ---------------- Loop through BAM files ----------------
for BAM in "$BAM_DIR"/*.proper_unique.noChrM.sorted.dedup.bam; do
    SAMPLE=$(basename "$BAM" .proper_unique.noChrM.sorted.dedup.bam)

    echo "Processing sample: $SAMPLE"
    
    # Count reads in original BAM
    READS=$(apptainer exec "$SAMTOOLS_CONTAINER" samtools view -c "$BAM")
    echo "  Original BAM reads: $READS"

    # Define filtered BAM path
    FILTERED_BAM="$FILTERED_DIR/${SAMPLE}.filtered.bam"

    # Filter blacklist regions if filtered BAM doesn't exist
    if [[ ! -f "$FILTERED_BAM" ]]; then
        echo "  Filtering blacklist regions..."
       bedtools intersect -v -abam "$BAM" -b "$BLACKLIST" > "$FILTERED_BAM"
    fi

    # Count reads in filtered BAM
    FILTERED_READS=$(apptainer exec "$SAMTOOLS_CONTAINER" samtools view -c "$FILTERED_BAM")
    echo "  Filtered BAM reads: $FILTERED_READS"
    echo "----------------------------------------"
done

