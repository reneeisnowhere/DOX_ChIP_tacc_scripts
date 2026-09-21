#!/bin/bash
#SBATCH -J rerun_ChIP44_50
#SBATCH -o rerun_ChIP44_50.%j.out
#SBATCH -e rerun_ChIP44_50.%j.err
#SBATCH -p normal
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 04:00:00
#SBATCH --cpus-per-task=16

set +u

module unload xalt
module load tacc-apptainer
module load biocontainers
module load gatk
module load bedtools
set -e
set -o pipefail
set -u


SAM_DIR="/scratch/09196/reneem/DOX_ChIP/sam_folder"
OUT_DIR="/scratch/09196/reneem/DOX_ChIP/test_ChIP44_50"
SIF_PATH="/scratch/09196/reneem/DOX_ChIP/samtools_1.9--h91753b0_5.sif"
CHRS="/scratch/09196/reneem/DOX_ChIP/chromosomes.bed"
BLACKLIST="/scratch/09196/reneem/DOX_ChIP/hg38-blacklist.v2.bed"

THREADS="${SLURM_CPUS_PER_TASK}"
MEM_PER_THREAD="2G"
TMP_DIR="${OUT_DIR}/tmp"

mkdir -p "$OUT_DIR" "$TMP_DIR"

export _JAVA_OPTIONS="-Xmx56g -Djava.io.tmpdir=${TMP_DIR}"

SAMPLES=("MCW_SP_ChIP44" "MCW_SP_ChIP50")

SUMMARY="${OUT_DIR}/ChIP44_50_processing_summary.tsv"

echo -e \
"Sample\tRawProper\tMAPQ30\tCanonical\tDedup\tNoBlacklist\tFinalFragments" \
> "$SUMMARY"

for SAMPLE in "${SAMPLES[@]}"
do

    echo "========================================"
    echo "Processing $SAMPLE"
    echo "========================================"

    SAM="${SAM_DIR}/${SAMPLE}.sam"

    FILTERED="${OUT_DIR}/${SAMPLE}.proper_MAPQ30.bam"

    CANONICAL="${OUT_DIR}/${SAMPLE}.proper_MAPQ30.canonical.sorted.bam"

    DEDUP="${OUT_DIR}/${SAMPLE}.proper_MAPQ30.canonical.sorted.dedup.bam"

    METRICS="${OUT_DIR}/${SAMPLE}.dedup.metrics.txt"

    NAME_SORTED="${OUT_DIR}/${SAMPLE}.dedup.namesorted.bam"

    NOBL_NAME="${OUT_DIR}/${SAMPLE}.dedup.noblack.namesorted.bam"

    FINAL="${OUT_DIR}/${SAMPLE}.proper_MAPQ30.canonical.dedup.noblack.sorted.bam"


    # --------------------------------------------------
    # 0. Proper-pair count before filtering
    # --------------------------------------------------

    RAW_PROPER=$(
        apptainer exec "$SIF_PATH" \
        samtools view -c -f 0x2 "$SAM"
    )


    # --------------------------------------------------
    # 1. Proper pairs + MAPQ >=30
    #    remove unmapped, mate-unmapped,
    #    secondary, QC-failed
    # --------------------------------------------------

    apptainer exec "$SIF_PATH" \
        samtools view \
        -@ "$THREADS" \
        -b \
        -f 0x2 \
        -F 780 \
        -q 30 \
        -o "$FILTERED" \
        "$SAM"

    MAPQ_COUNT=$(
        apptainer exec "$SIF_PATH" \
        samtools view -c "$FILTERED"
    )


    # --------------------------------------------------
    # 2. Keep canonical chromosomes and sort
    # --------------------------------------------------

    apptainer exec "$SIF_PATH" bash -c "
        set -o pipefail

        samtools view \
            -@ '$THREADS' \
            -b \
            -L '$CHRS' \
            '$FILTERED' |
        samtools sort \
            -@ '$THREADS' \
            -m '$MEM_PER_THREAD' \
            -o '$CANONICAL' \
            -
    "

    apptainer exec "$SIF_PATH" \
        samtools index "$CANONICAL"

    CANONICAL_COUNT=$(
        apptainer exec "$SIF_PATH" \
        samtools view -c "$CANONICAL"
    )


    # --------------------------------------------------
    # 3. Remove duplicates
    # --------------------------------------------------

    gatk MarkDuplicates \
        -I "$CANONICAL" \
        -O "$DEDUP" \
        -M "$METRICS" \
        --REMOVE_DUPLICATES true \
        --CREATE_INDEX true \
        --TMP_DIR "$TMP_DIR"

    DEDUP_COUNT=$(
        apptainer exec "$SIF_PATH" \
        samtools view -c "$DEDUP"
    )


    # --------------------------------------------------
    # 4. Remove entire PE fragment if either mate
    #    overlaps blacklist
    # --------------------------------------------------

    apptainer exec "$SIF_PATH" \
        samtools sort \
        -n \
        -@ "$THREADS" \
        -m "$MEM_PER_THREAD" \
        -o "$NAME_SORTED" \
        "$DEDUP"

    bedtools pairtobed \
        -abam "$NAME_SORTED" \
        -b "$BLACKLIST" \
        -type neither \
        > "$NOBL_NAME"


    # --------------------------------------------------
    # 5. Coordinate sort final BAM
    # --------------------------------------------------

    apptainer exec "$SIF_PATH" \
        samtools sort \
        -@ "$THREADS" \
        -m "$MEM_PER_THREAD" \
        -o "$FINAL" \
        "$NOBL_NAME"

    apptainer exec "$SIF_PATH" \
        samtools index "$FINAL"

    FINAL_COUNT=$(
        apptainer exec "$SIF_PATH" \
        samtools view -c "$FINAL"
    )

    FINAL_FRAGMENTS=$(( FINAL_COUNT / 2 ))


    # --------------------------------------------------
    # Summary
    # --------------------------------------------------

    echo -e \
"${SAMPLE}\t${RAW_PROPER}\t${MAPQ_COUNT}\t${CANONICAL_COUNT}\t${DEDUP_COUNT}\t${FINAL_COUNT}\t${FINAL_FRAGMENTS}" \
        >> "$SUMMARY"

done


# ======================================================
# MACS3 test
# ======================================================

CHIP="${OUT_DIR}/MCW_SP_ChIP44.proper_MAPQ30.canonical.dedup.noblack.sorted.bam"
INPUT="${OUT_DIR}/MCW_SP_ChIP50.proper_MAPQ30.canonical.dedup.noblack.sorted.bam"

mkdir -p "${OUT_DIR}/macs3_q05"
mkdir -p "${OUT_DIR}/macs3_q01"

macs3 callpeak \
    -t "$CHIP" \
    -c "$INPUT" \
    -f BAMPE \
    -g hs \
    -q 0.05 \
    --outdir "${OUT_DIR}/macs3_q05" \
    -n "MCW_SP_ChIP44_DOX_TOP2B_Ind4_q0.05"

macs3 callpeak \
    -t "$CHIP" \
    -c "$INPUT" \
    -f BAMPE \
    -g hs \
    -q 0.01 \
    --outdir "${OUT_DIR}/macs3_q01" \
    -n "MCW_SP_ChIP44_DOX_TOP2B_Ind4_q0.01"


echo "Finished."
echo "Processing summary:"
cat "$SUMMARY"
