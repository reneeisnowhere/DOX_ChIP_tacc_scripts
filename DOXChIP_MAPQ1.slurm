#!/bin/bash

#SBATCH -J DOXChIP_MAPQ1
#SBATCH -o MAPQ1.%A_%a.out
#SBATCH -e MAPQ1.%A_%a.err
#SBATCH -p normal
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 04:00:00
#SBATCH --cpus-per-task=16
#SBATCH --array=1-48%8

# Do not enable nounset before loading TACC modules
set +u

module unload xalt
module load tacc-apptainer
module load biocontainers
module load gatk
module load bedtools

set -euo pipefail

# ============================================================
# Paths
# ============================================================

SAM_DIR="/scratch/09196/reneem/DOX_ChIP/sam_folder"

# IMPORTANT:
# Use a completely separate directory from the MAPQ30 pipeline.
OUT_DIR="/scratch/09196/reneem/DOX_ChIP/bam_folder_MAPQ1"

SUMMARY_DIR="${OUT_DIR}/summary_files"
TMP_DIR="${OUT_DIR}/tmp"

SIF_PATH="/scratch/09196/reneem/DOX_ChIP/samtools_1.9--h91753b0_5.sif"

CHRS="/scratch/09196/reneem/DOX_ChIP/chromosomes.bed"

BLACKLIST="/scratch/09196/reneem/DOX_ChIP/hg38-blacklist.v2.bed"

META="/scratch/09196/reneem/DOX_ChIP/DOX_ChIP_samplenames.txt"

mkdir -p \
    "$OUT_DIR" \
    "$SUMMARY_DIR" \
    "$TMP_DIR"


# ============================================================
# Resources
# ============================================================

THREADS="${SLURM_CPUS_PER_TASK}"
MEM_PER_THREAD="2G"

# Conservative Java heap for MarkDuplicates
export _JAVA_OPTIONS="-Xmx24g -Djava.io.tmpdir=${TMP_DIR}"


# ============================================================
# Select sample
#
# Array task 1 = metadata line 2
# because line 1 is the header.
# ============================================================

line_number=$((SLURM_ARRAY_TASK_ID + 1))

sample=$(
    awk -F'\t' -v line="$line_number" \
        'NR == line {print $1}' \
        "$META" |
    tr -d '\r' |
    xargs
)

if [[ -z "$sample" ]]; then
    echo "ERROR: No sample found for task ${SLURM_ARRAY_TASK_ID}" >&2
    exit 1
fi

sam_file="${SAM_DIR}/${sample}.sam"

echo "============================================================"
echo "Array task: ${SLURM_ARRAY_TASK_ID}"
echo "Sample:     ${sample}"
echo "SAM:        ${sam_file}"
echo "============================================================"


# ============================================================
# Check inputs
# ============================================================

[[ -f "$sam_file" ]] || {
    echo "ERROR: SAM not found: $sam_file" >&2
    exit 1
}

[[ -f "$CHRS" ]] || {
    echo "ERROR: chromosome BED not found: $CHRS" >&2
    exit 1
}

[[ -f "$BLACKLIST" ]] || {
    echo "ERROR: blacklist not found: $BLACKLIST" >&2
    exit 1
}


# ============================================================
# Output files
# ============================================================

filtered_bam="${OUT_DIR}/${sample}.proper_MAPQ1.bam"

canonical_bam="${OUT_DIR}/${sample}.proper_MAPQ1.canonical.sorted.bam"

dedup_bam="${OUT_DIR}/${sample}.proper_MAPQ1.canonical.sorted.dedup.bam"

metrics="${OUT_DIR}/${sample}.MAPQ1.dedup.metrics.txt"

name_sorted_bam="${OUT_DIR}/${sample}.MAPQ1.dedup.namesorted.bam"

noblack_name_bam="${OUT_DIR}/${sample}.MAPQ1.dedup.noblack.namesorted.bam"

final_bam="${OUT_DIR}/${sample}.proper_MAPQ1.canonical.dedup.noblack.sorted.bam"

summary_file="${SUMMARY_DIR}/${sample}.summary.csv"


start_time=$(date +"%Y-%m-%d %H:%M:%S")


# ============================================================
# STEP 0
# Count raw properly paired alignments
# ============================================================

raw_proper_count=$(
    apptainer exec "$SIF_PATH" \
        samtools view \
        -c \
        -f 0x2 \
        "$sam_file"
)

echo "Raw properly paired reads: ${raw_proper_count}"


# ============================================================
# STEP 1
# Properly paired + MAPQ >= 1
#
# This is the MAPQ threshold we are changing.
#
# -f 2   properly paired
#
# -F 780 excludes:
#   4   unmapped
#   8   mate unmapped
#   256 secondary
#   512 QC failure
# ============================================================

echo "Step 1: Proper pairs + MAPQ >= 1"

apptainer exec "$SIF_PATH" \
    samtools view \
    -@ "$THREADS" \
    -b \
    -f 0x2 \
    -F 780 \
    -q 1 \
    -o "$filtered_bam" \
    "$sam_file"

mapq_count=$(
    apptainer exec "$SIF_PATH" \
        samtools view \
        -c \
        "$filtered_bam"
)

echo "After MAPQ1 filtering: ${mapq_count}"


# ============================================================
# STEP 2
# Keep canonical chromosomes and coordinate sort
# ============================================================

echo "Step 2: Canonical chromosomes + coordinate sorting"

apptainer exec "$SIF_PATH" bash -c "
    set -o pipefail

    samtools view \
        -@ '$THREADS' \
        -b \
        -L '$CHRS' \
        '$filtered_bam' |
    samtools sort \
        -@ '$THREADS' \
        -m '$MEM_PER_THREAD' \
        -o '$canonical_bam' \
        -
"

apptainer exec "$SIF_PATH" \
    samtools index "$canonical_bam"

canonical_count=$(
    apptainer exec "$SIF_PATH" \
        samtools view \
        -c \
        "$canonical_bam"
)

echo "After canonical filtering: ${canonical_count}"


# ============================================================
# STEP 3
# Remove PCR/coordinate duplicates
# ============================================================

echo "Step 3: GATK MarkDuplicates"

gatk MarkDuplicates \
    -I "$canonical_bam" \
    -O "$dedup_bam" \
    -M "$metrics" \
    --REMOVE_DUPLICATES true \
    --CREATE_INDEX true \
    --TMP_DIR "$TMP_DIR"

dedup_count=$(
    apptainer exec "$SIF_PATH" \
        samtools view \
        -c \
        "$dedup_bam"
)

echo "After duplicate removal: ${dedup_count}"


# ============================================================
# STEP 4
# Pair-aware blacklist removal
#
# Name-sort because pairtobed expects paired reads together.
# -type neither retains pairs where neither mate overlaps
# blacklist.
# ============================================================

echo "Step 4: Name sorting"

apptainer exec "$SIF_PATH" \
    samtools sort \
    -n \
    -@ "$THREADS" \
    -m "$MEM_PER_THREAD" \
    -o "$name_sorted_bam" \
    "$dedup_bam"

echo "Step 4b: Removing blacklist-overlapping fragments"

bedtools pairtobed \
    -abam "$name_sorted_bam" \
    -b "$BLACKLIST" \
    -type neither \
    > "$noblack_name_bam"


# ============================================================
# STEP 5
# Coordinate-sort and index final BAM
# ============================================================

echo "Step 5: Final coordinate sort"

apptainer exec "$SIF_PATH" \
    samtools sort \
    -@ "$THREADS" \
    -m "$MEM_PER_THREAD" \
    -o "$final_bam" \
    "$noblack_name_bam"

apptainer exec "$SIF_PATH" \
    samtools index "$final_bam"

blacklist_count=$(
    apptainer exec "$SIF_PATH" \
        samtools view \
        -c \
        "$final_bam"
)

echo "After blacklist removal: ${blacklist_count}"


# ============================================================
# Counts removed at each stage
# ============================================================

removed_mapq=$(( raw_proper_count - mapq_count ))

removed_noncanonical=$(( mapq_count - canonical_count ))

removed_duplicates=$(( canonical_count - dedup_count ))

removed_blacklist=$(( dedup_count - blacklist_count ))

# 2 alignments per PE fragment
final_fragments=$(( blacklist_count / 2 ))


# ============================================================
# Summary
# ============================================================

end_time=$(date +"%Y-%m-%d %H:%M:%S")

echo \
"Sample,Start,End,Raw_Proper_Paired,After_MAPQ1,After_Canonical,After_Dedup,After_Blacklist,Removed_MAPQ,Removed_Noncanonical,Removed_Duplicates,Removed_Blacklist,Final_Fragments" \
> "$summary_file"

echo \
"${sample},${start_time},${end_time},${raw_proper_count},${mapq_count},${canonical_count},${dedup_count},${blacklist_count},${removed_mapq},${removed_noncanonical},${removed_duplicates},${removed_blacklist},${final_fragments}" \
>> "$summary_file"


# ============================================================
# Remove intermediate BAMs
# ============================================================

rm -f \
    "$filtered_bam" \
    "$canonical_bam" \
    "${canonical_bam}.bai" \
    "$name_sorted_bam" \
    "$noblack_name_bam"


# ============================================================
# Finish
# ============================================================

echo
echo "============================================================"
echo "Sample:                      ${sample}"
echo "Raw properly paired:         ${raw_proper_count}"
echo "After MAPQ1:                 ${mapq_count}"
echo "After canonical chromosomes: ${canonical_count}"
echo "After duplicate removal:     ${dedup_count}"
echo "After blacklist removal:     ${blacklist_count}"
echo "Final fragments:             ${final_fragments}"
echo
echo "Final BAM:"
echo "${final_bam}"
echo
echo "Summary:"
echo "${summary_file}"
echo
echo "Metrics:"
echo "${metrics}"
echo "============================================================"
