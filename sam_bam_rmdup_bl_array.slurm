#!/bin/bash

#SBATCH -J sam2bam_process	  	# Job name
#SBATCH -o sam2bamp.%A_%a.out	# Name of stdout output file (%j expantds to jobID)
#SBATCH -e sam2bamp.%A_%a.err
#SBATCH -p normal		# Queue name
#SBATCH -N 1			# Total number of nodes requested
#SBATCH -n 1 			# Total number of mpi tasks requested (normally 1)
#SBATCH -t 05:00:00		# Run time (hh:mm:ss)
#SBATCH --cpus-per-task=16
#SBATCH --array=1-2%2



# ----------------- Modules -----------------
module unload xalt
module load tacc-apptainer
module load biocontainers
module load gatk
module load bedtools

set -euo pipefail

# ----------------- Variables -----------------
SAM_DIR="/scratch/09196/reneem/DOX_ChIP/sam_folder"
OUT_DIR="/scratch/09196/reneem/DOX_ChIP/bam_folder"
SUMMARY_DIR="${OUT_DIR}/summary_files"
TMP_DIR="${OUT_DIR}/tmp"
SIF_PATH="/scratch/09196/reneem/DOX_ChIP/samtools_1.9--h91753b0_5.sif"
CHRS="/scratch/09196/reneem/DOX_ChIP/chromosomes.bed"
BLACKLIST="/scratch/09196/reneem/DOX_ChIP/hg38-blacklist.v2.bed"
SAMPLES="/scratch/09196/reneem/DOX_ChIP/DOX_ChIP_sam_files.txt"


mkdir -p "$OUT_DIR" "$SUMMARY_DIR" "$TMP_DIR"

#__________________Resources___________________________

# Threads/memory
THREADS="${SLURM_CPUS_PER_TASK}"

MEM_PER_THREAD="2G"

export _JAVA_OPTIONS="Xmx56g -Djava.io.tmpdir=${TMP_DIR}"
#--------------------- Select one SAM file -------------------------------
sam_name=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLES" | tr -d '\r')

if [[ -z "$sam_name" ]]; then
	echo "ERROR: No filename found for array task ${SLURM_ARRAY_TASK_ID}" >&2
	exit 1
fi

sam_file="${SAM_DIR}/${sam_name}"
base=$(basename "$sam_file" .sam)

#-------------------Check inputs ----------------------------

[[ -f "$sam_file" ]] || {
    echo "ERROR: SAM file not found: $sam_file" >&2
    exit 1
}

[[ -f "$SIF_PATH" ]] || {
    echo "ERROR: container not found: $SIF_PATH" >&2
    exit 1
}

[[ -f "$CHRS" ]] || {
    echo "ERROR: chromosome BED not found: $CHRS" >&2
    exit 1
}

[[ -f "$BLACKLIST" ]] || {
    echo "ERROR: blacklist BED not found: $BLACKLIST" >&2
    exit 1
}

#-------------- Outputfiles ----------------------

filtered_bam="${OUT_DIR}/${base}.proper_MAPQ30.bam"
canonical_bam="${OUT_DIR}/${base}.proper_MAPQ30.canonical.sorted.bam"
dedup_bam="${OUT_DIR}/${base}.proper_MAPQ30.canonical.sorted.dedup.bam"
metrics="${OUT_DIR}/${base}.dedup.metrics.txt"
name_sorted_bam="${OUT_DIR}/${base}.dedup.namesorted.bam"
noblack_name_bam="${OUT_DIR}/${base}.dedup.noblack.namesorted.bam"

summary_file="${SUMMARY_DIR}/${base}.summary.csv"

start_time=$(date +"%Y-%m-%d %H:%M:%S")

echo "Array task: ${SLURM_ARRAY_TASK_ID}"
echo "Sample: $base"
echo "Started: $start_time"


#--------------Filter sam---------------------

raw_proper_count=$(apptainer exec "$SIF_PATH" samtools view -c -f 0x2 "$sam_file")

echo "Raw properly paired reads: ${raw_proper_count}"


###STEP 1
# Properly paired + MAPQ >= 30
#
# -f 2   = properly paired
#
# -F 780 excludes:
#    4   read unmapped
#    8   mate unmapped
#    256 secondary alignment
#    512 QC failure

echo "Step 1: filtering proper pairs and MAP1 >= 30..."

apptainer exec "$SIF_PATH" samtools view -@ "$THREADS" -b -f 0x2 -F 780 -q 30 -o "$filtered_bam" "$sam_file"

mapq_count=$(
    apptainer exec "$SIF_PATH" \
        samtools view -c -f 0x2 "$filtered_bam"
)

echo "After MAPQ/filtering: ${mapq_count}"

#-----------Filter canonical chroms and sort-----------------------


# STEP 2
# Keep canonical chromosomes only:
# chr1-22, chrX, chrY
#
# Then coordinate sort.
echo "Step 2: Restricting to canonical chromosomes and sorting..."


apptainer exec "$SIF_PATH" bash -c " 
set -o pipefail

samtools view -@ '${THREADS}' -b -L '${CHRS}' '${filtered_bam}' | \
	samtools sort -@ '${THREADS}' -m '${MEM_PER_THREAD}' -o '${canonical_bam}' \
	-
"
#--------------INDEX final BAM-------------------------

apptainer exec "$SIF_PATH" samtools index "$canonical_bam"

#---------------------Counts----------------------------

canonical_count=$(apptainer exec "$SIF_PATH" samtools view -c -f 0x2 "$canonical_bam")

echo "After canoncial chromosome filtering: ${canonical_count}"

#------------------------------------------------
#Step 3 remove pcr/optical dups with GATK MarkDuplicates

echo "Step 3: Removing duplicates with GATK MarkDuplicates..."

gatk MarkDuplicates \
    -I "$canonical_bam" \
    -O "$dedup_bam" \
    -M "$metrics" \
    --REMOVE_DUPLICATES true \
    --CREATE_INDEX true \
    --TMP_DIR "$TMP_DIR"


dedup_count=$(
    apptainer exec "$SIF_PATH" \
        samtools view -c -f 0x2 "$dedup_bam"
)

echo "After duplicate removal: ${dedup_count}"

# ============================================================
# STEP 4
# Remove blacklist regions.
#
# Because data are paired-end, first name-sort the BAM.
#
# pairtobed -type neither:
# retain pair ONLY when NEITHER mate overlaps blacklist.
# ============================================================

echo "Step 4: Name-sorting for paired-end blacklist filtering..."
    apptainer exec "$SIF_PATH" samtools sort -n -@ "$THREADS" -m "$MEM_PER_THREAD" -o "$name_sorted_bam" "$dedup_bam")

echo "Removing read pairs overlapping blacklist..."

bedtools pairtobed -abam "$name_sorted_bam" -b "$BLACKLIST" -type neither > "$noblack_name_bam"


# ============================================================
# STEP 5
# Coordinate-sort blacklist-filtered BAM
# ============================================================

echo "Step 5: Coordinate-sorting final BAM..."

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
        samtools view -c -f 0x2 "$final_bam"
)


echo "After blacklist removal: ${blacklist_count}"

#________------------------------ calculate read removed at each step

removed_mapq=$(( raw_proper_count - mapq_count ))

removed_noncanonical=$(( mapq_count - canonical_count ))

removed_duplicates=$(( canonical_count - dedup_count ))

removed_blacklist=$(( dedup_count - blacklist_count ))

# Final read-pair / fragment count
#
# samtools view counts individual alignments.
# With properly paired PE data:
#
# 2 reads = 1 fragment


final_fragments=$(( blacklist_count / 2 ))

# ============================================================
# Summary CSV
# ============================================================

end_time=$(date +"%Y-%m-%d %H:%M:%S")


echo \
"Sample,Start,End,Raw_Proper_Paired,After_MAPQ30,After_Canonical,After_Dedup,After_Blacklist,Removed_MAPQ,Removed_Noncanonical,Removed_Duplicates,Removed_Blacklist,Final_Fragments" \
> "$summary_file"


echo \
"${base},${start_time},${end_time},${raw_proper_count},${mapq_count},${canonical_count},${dedup_count},${blacklist_count},${removed_mapq},${removed_noncanonical},${removed_duplicates},${removed_blacklist},${final_fragments}" \
>> "$summary_file"

# ============================================================
# Clean up intermediate BAMs
# ============================================================

rm -f \
    "$filtered_bam" \
    "$canonical_bam" \
    "${canonical_bam}.bai" \
    "$name_sorted_bam" \
    "$noblack_name_bam"


[200~# ============================================================
# Finish
# ============================================================

echo "============================================================"
echo "Sample: ${base}"
echo "Raw properly paired:        ${raw_proper_count}"
echo "After MAPQ30:               ${mapq_count}"
echo "After canonical chromosomes:${canonical_count}"
echo "After duplicate removal:    ${dedup_count}"
echo "After blacklist removal:    ${blacklist_count}"
echo "Final fragments:            ${final_fragments}"
echo
echo "Finished: ${end_time}"
echo "Final BAM: ${final_bam}"
echo "Summary:   ${summary_file}"
echo "Metrics:   ${metrics}"
echo "============================================================"



