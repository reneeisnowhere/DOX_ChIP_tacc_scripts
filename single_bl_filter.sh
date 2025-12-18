#!/bin/bash
set -euo pipefail

# ---------------- Variables ----------------
BAM_DIR="/scratch/09196/reneem/DOX_ChIP/final_bam_folder"
FILTERED_DIR="/scratch/09196/reneem/DOX_ChIP/bl_filtered_bams"
BLACKLIST="/scratch/09196/reneem/DOX_ChIP/hg38-blacklist.v2.bed"
SAMTOOLS_CONTAINER="/scratch/09196/reneem/DOX_ChIP/samtools_1.9--h91753b0_5.sif"

# Pick a single sample for testing
SAMPLE="MCW_SP_ChIP32"
IND="Ind2"
TX="DOX"
AB="TOP2B"
INPUT_SAMPLE="MCW_SP_ChIP38"  # Corresponding Input_P53

mkdir -p "$FILTERED_DIR"

# ---------------- ChIP BAM ----------------
CHIP_BAM="${BAM_DIR}/${SAMPLE}.proper_unique.noChrM.sorted.dedup.bam"
FILTERED_BAM="${FILTERED_DIR}/${SAMPLE}.filtered.bam"

echo "DEBUG: SAMPLE='$SAMPLE', TX='$TX', AB='$AB'"

# Check if BAM is valid
if ! apptainer exec "$SAMTOOLS_CONTAINER" samtools quickcheck "$CHIP_BAM"; then
    echo "WARNING: $CHIP_BAM is truncated or invalid. Skipping."
    exit 1
fi

# Filter ChIP BAM
echo "Filtering $CHIP_BAM..."
apptainer exec "$SAMTOOLS_CONTAINER" samtools view -b -U /dev/null -L "$BLACKLIST" "$CHIP_BAM" > "$FILTERED_BAM"

CHIP_COUNT=$(apptainer exec "$SAMTOOLS_CONTAINER" samtools view -c "$FILTERED_BAM")

# ---------------- Input BAM ----------------
INPUT_BAM="${BAM_DIR}/${INPUT_SAMPLE}.proper_unique.noChrM.sorted.dedup.bam"
FILTERED_INPUT_BAM="${FILTERED_DIR}/${INPUT_SAMPLE}.filtered.bam"

# Check if BAM is valid
if ! apptainer exec "$SAMTOOLS_CONTAINER" samtools quickcheck "$INPUT_BAM"; then
    echo "WARNING: $INPUT_BAM is truncated or invalid. Skipping control BAM."
    INPUT_COUNT="N/A"
else
    echo "Filtering Input BAM $INPUT_BAM..."
    apptainer exec "$SAMTOOLS_CONTAINER" samtools view -b -U /dev/null -L "$BLACKLIST" "$INPUT_BAM" > "$FILTERED_INPUT_BAM"
    INPUT_COUNT=$(apptainer exec "$SAMTOOLS_CONTAINER" samtools view -c "$FILTERED_INPUT_BAM")
fi

# ---------------- Print results ----------------
echo "RESULTS:"
echo "  ChIP BAM: $FILTERED_BAM reads: $CHIP_COUNT"
echo "  Control BAM: $FILTERED_INPUT_BAM reads: $INPUT_COUNT"
