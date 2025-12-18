
#!/bin/bash

META="DOX_ChIP_samplenames.txt"
PAIR_FILE="chip_input_pairs.txt"

# Header
echo -e "ChIP_sample\tInput_sample\tTx\tIndividual\tAB" > "$PAIR_FILE"

# Loop through ChIP samples
tail -n +2 "$META" | grep -v '^\s*$' | while IFS=$'\t' read -r SAMPLE CELL IND TX AB TYPE SEQ; do
    # Skip Input_P53 in this loop
    [[ "$AB" == "Input_P53" ]] && continue

    # Find matching Input_P53 for the same individual and Tx
    INPUT_SAMPLE=$(awk -F'\t' -v ind="$IND" -v tx="$TX" -v ab="Input_P53" \
        '$3==ind && $4==tx && $5==ab {print $1}' "$META")

    # Print if found
    if [[ -n "$INPUT_SAMPLE" ]]; then
        echo -e "${SAMPLE}\t${INPUT_SAMPLE}\t${TX}\t${IND}\t${AB}" >> "$PAIR_FILE"
    else
        echo "WARNING: No Input found for $SAMPLE (Ind=$IND, Tx=$TX, AB=$AB)"
    fi
done
