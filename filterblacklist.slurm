#!/bin/bash

#SBATCH -J blacklist
#SBATCH -o Bl_filter.%j
#SBATCH -p normal
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 18:00:00








set -euo pipefail

# ---------------- Variables ----------------
BAM_DIR="/scratch/09196/reneem/DOX_ChIP/final_bam_folder"
FILTERED_DIR="/scratch/09196/reneem/DOX_ChIP/bl_filtered_bams"
BLACKLIST="/scratch/09196/reneem/DOX_ChIP/hg38-blacklist.v2.bed"
SAMTOOLS_CONTAINER="/scratch/09196/reneem/DOX_ChIP/samtools_1.9--h91753b0_5.sif"

mkdir -p "$FILTERED_DIR"

# ---------------- Loop through BAM files ----------------
for BAM in "$BAM_DIR"/*.proper_unique.noChroM.sorted.dedup.bam; do
    SAMPLE=$(basename "$BAM" .proper_unique.noChroM.sorted.dedup.bam)

    echo "Processing sample: $SAMPLE"
    
    # Count reads in original BAM
    READS=$(apptainer exec "$SAMTOOLS_CONTAINER" samtools view -c "$BAM")
    echo "  Original BAM reads: $READS"

    # Define filtered BAM path
    FILTERED_BAM="$FILTERED_DIR/${SAMPLE}.filtered.bam"

    # Filter blacklist regions if filtered BAM doesn't exist
    if [[ ! -f "$FILTERED_BAM" ]]; then
        echo "  Filtering blacklist regions..."
        apptainer exec "$SAMTOOLS_CONTAINER" samtools view -@ 64 -b -U /dev/null -L "$BLACKLIST" "$BAM" > "$FILTERED_BAM"
    fi

    # Count reads in filtered BAM
    FILTERED_READS=$(apptainer exec "$SAMTOOLS_CONTAINER" samtools view -c "$FILTERED_BAM")
    echo "  Filtered BAM reads: $FILTERED_READS"
    echo "----------------------------------------"
done

