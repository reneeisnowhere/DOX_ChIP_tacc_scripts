#!/bin/bash
set -euo pipefail

# ---------------- Variables ----------------
BAM_DIR="/scratch/09196/reneem/DOX_ChIP/final_bam_folder"
META="DOX_ChIP_samplenames.txt"
BAM_SUFFIX=".proper_unique.noChrM.sorted.dedup.bam"
FILTERED_DIR="/scratch/09196/reneem/DOX_ChIP/bl_filtered_bams"
BLACKLIST="/scratch/09196/reneem/DOX_ChIP/hg38-blacklist.v2.bed"
SAMTOOLS_CONTAINER="/scratch/09196/reneem/DOX_ChIP/samtools_1.9--h91753b0_5.sif"

mkdir -p "$FILTERED_DIR"

# ---------------- Loop through samples ----------------
tail -n +2 "$META" | grep -v '^\s*$' | while IFS=$'\t' read -r SAMPLE CELL IND TX AB TYPE SEQ; do

    # Skip empty or Input samples in main loop
    [[ -z "$SAMPLE" ]] && continue
    [[ "$TX" == "Input_P53" ]] && continue
SAMPLE=$(echo "$SAMPLE" | xargs)
IND=$(echo "$IND" | xargs)
TX=$(echo "$TX" | xargs)
AB=$(echo "$AB" | xargs)
    # ---------------- ChIP BAM ----------------
    CHIP_BAM="${BAM_DIR}/${SAMPLE}${BAM_SUFFIX}"
    FILTERED_BAM="${FILTERED_DIR}/${SAMPLE}.filtered.bam"

    echo "DEBUG: SAMPLE='$SAMPLE', TX='$TX', AB='$AB'"
# ---------------- Check if BAM is valid ----------------
    if ! apptainer exec "$SAMTOOLS_CONTAINER" samtools quickcheck "$CHIP_BAM"; then
        echo "WARNING: $CHIP_BAM is truncated or invalid. Skipping this sample."
        continue
    fi
#-------------------filter ChIP BAM-------------------------
    if [[ ! -f "$FILTERED_BAM" ]]; then
        echo "Filtering $CHIP_BAM..."
        apptainer exec "$SAMTOOLS_CONTAINER" samtools view -b \
            -U /dev/null \
            -L "$BLACKLIST" \
            "$CHIP_BAM" \
            > "$FILTERED_BAM"
    fi

    CHIP_COUNT=$(apptainer exec "$SAMTOOLS_CONTAINER" samtools view -c "$FILTERED_BAM")

    # ---------------- Input BAM ----------------
    INPUT_SAMPLE=$(awk -F'\t' -v ind="$IND" -v tx="Input_P53" \
        '$3==ind && $4==tx {print $1}' "$META")
if [[ -z "$INPUT_SAMPLE" ]]; then
        echo "WARNING: No Input_P53 found for individual $IND. Skipping control BAM."
        FILTERED_INPUT_BAM="N/A"
        INPUT_COUNT="N/A"
    else
        INPUT_BAM="${BAM_DIR}/${INPUT_SAMPLE}${BAM_SUFFIX}"
        FILTERED_INPUT_BAM="${FILTERED_DIR}/${INPUT_SAMPLE}.filtered.bam"

        if [[ ! -f "$FILTERED_INPUT_BAM" ]]; then
            echo "Filtering Input BAM $INPUT_BAM..."
            apptainer exec "$SAMTOOLS_CONTAINER" samtools view -b \
                -U /dev/null \
                -L "$BLACKLIST" \
                "$INPUT_BAM" \
                > "$FILTERED_INPUT_BAM"
        fi
	


    INPUT_COUNT=$(apptainer exec "$SAMTOOLS_CONTAINER" samtools view -c "$FILTERED_INPUT_BAM")
    fi


    # ---------------- Print dry-run info ----------------
    if [[ "$CHIP_COUNT" -eq 0 ]]; then
        echo "WARNING: $FILTERED_BAM has 0 reads!"
    fi

    echo "READY: $SAMPLE (Tx=$TX, Ab=$AB)"
    echo "  ChIP BAM: $FILTERED_BAM read: $CHIP_COUNT"
    echo "  Control BAM: $FILTERED_INPUT_BAM reads: $INPUT_COUNT"
    echo "  MACS3 commands would be run for q=0.01 and q=0.05"
    echo "---------------------------------------------------------"

done

