#!/bin/bash
#
PAIR_FILE="chip_input_pairs.txt"
MACS3_SCRIPT="macs3_callpeak_commands.sh"

# Header: make the script executable
echo "#!/bin/bash" > "$MACS3_SCRIPT"

# Skip header line and loop through pairs
tail -n +2 "$PAIR_FILE" | while IFS=$'\t' read -r CHIP INPUT TX IND AB; do
    # Construct output folder name
    OUT_DIR="macs3_out/${CHIP}_${TX}_${AB}_${IND}"
    mkdir -p "$OUT_DIR"

    # MACS3 callpeak command
    echo "macs3 callpeak -t /scratch/09196/reneem/DOX_ChIP/bl_filtered_bams/${CHIP}.filtered.bam \
-c /scratch/09196/reneem/DOX_ChIP/bl_filtered_bams/${INPUT}.filtered.bam \
-f BAMPE -g hs -q 0.01 --outdir $OUT_DIR --name ${CHIP}_${TX}_${AB}_${IND}_q0.01" >> "$MACS3_SCRIPT"
done

# Make the script executable
chmod +x "$MACS3_SCRIPT"
