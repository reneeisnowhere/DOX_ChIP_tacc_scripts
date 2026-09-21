#!/bin/bash

PAIR_FILE="chip_input_pairs.txt"
MACS3_SCRIPT="macs3_callpeak_commands_MAPQ1_05.sh"

echo "#!/bin/bash" > "$MACS3_SCRIPT"

tail -n +2 "$PAIR_FILE" | while IFS=$'\t' read -r CHIP INPUT TX IND AB; do

    OUT_DIR="/scratch/09196/reneem/DOX_ChIP/macs3_out_MAPQ1/${CHIP}_${TX}_${AB}_${IND}"
    mkdir -p "$OUT_DIR"

    echo "macs3 callpeak \
-t /scratch/09196/reneem/DOX_ChIP/bam_folder_MAPQ1/${CHIP}.proper_MAPQ1.canonical.dedup.noblack.sorted.bam \
-c /scratch/09196/reneem/DOX_ChIP/bam_folder_MAPQ1/${INPUT}.proper_MAPQ1.canonical.dedup.noblack.sorted.bam \
-f BAMPE \
-g hs \
-q 0.05 \
--outdir $OUT_DIR \
--name ${CHIP}_${TX}_${AB}_${IND}_q0.05" >> "$MACS3_SCRIPT"

done

chmod +x "$MACS3_SCRIPT"
