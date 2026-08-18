#!/bin/bash

#SBATCH -J sam2bam_DOXChIP	  	# Job name
#SBATCH -o sam2bam.%A_%a.out	# Name of stdout output file (%j expantds to jobID)
#SBATCH -e sam2bam.%A_%a.err
#SBATCH -p normal		# Queue name
#SBATCH -N 1			# Total number of nodes requested
#SBATCH -n 1 			# Total number of mpi tasks requested (normally 1)
#SBATCH -t 05:00:00		# Run time (hh:mm:ss)
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --array=1-60%8

set -euo pipefail


# ----------------- Modules -----------------
module unload xalt
module load tacc-apptainer

# ----------------- Variables -----------------
SAM_DIR="/scratch/09196/reneem/DOX_ChIP/sam_folder"
OUT_DIR="/scratch/09196/reneem/DOX_ChIP/bam_folder"
SUMMARY_DIR="${OUT_DIR}/summary_files"

SIF_PATH="/scratch/09196/reneem/DOX_ChIP/samtools_1.9--h91753b0_5.sif"
CHRS="/scratch/09196/reneem/DOX_ChIP/chromosomes.bed"
SAMPLES="/scratch/09196/reneem/DOX_ChIP/DOX_ChIP_sam_files.txt"


mkdir -p "$OUT_DIR" "$SUMMARY_DIR"

#__________________Resources___________________________

# Threads/memory
THREADS="${SLURM_CPUS_PER_TASK}"

MEM_PER_THREAD="1500M"

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


#-------------- Outputfiles ----------------------

bam_filtered="${OUT_DIR}/${base}.proper_MAPQ30.bam"
sorted_final="${OUT_DIR}/${base}.proper_MAPQ30.canonical.sorted.bam"
summary_file="${SUMMARY_DIR}/${base}.summary.csv"

start_time=$(date +"%Y-%m-%d %H:%M:%S")

echo "Array task: ${SLURM_ARRAY_TASK_ID}"
echo "Sample: $base"
echo "Started: $start_time"


#--------------Filter sam---------------------

apptainer exec "$SIF_PATH" samtools view -@ "$THREADS" -b -f 0x2 -q 30 -o "$bam_filtered" "$sam_file"


#-----------Filter canonical chroms and sort-----------------------

apptainer exec "$SIF_PATH" bash -c " 
set -o pipefail

samtools view -@ '$THREADS' -m '$MEM_PER_THREAD' -o '$sorted_final' -
"
#--------------INDEX final BAM-------------------------

apptainer exec "$SIF_PATH" samtools index "$sorted_final"

#---------------------Counts----------------------------

proper_count=$(apptainer exec "$SIF_PATH" samtools view -c -f 0x2 "$sam_file")


filtered_count=$(
    apptainer exec "$SIF_PATH" \
        samtools view -c -f 0x2 -F 1804 -q 30 "$sam_file"
)

canonical_count=$(
    apptainer exec "$SIF_PATH" \
        samtools view -c "$sorted_final"
)

end_time=$(date +"%Y-%m-%d %H:%M:%S")
    


# Each array task writes a separate summary file.
echo \
    "Sample,Start,End,Properly_Paired,Properly_Paired_MAPQ30,Properly_Paired_MAPQ30_Canonical" \
    > "$summary_file"

echo \
    "${base},${start_time},${end_time},${proper_count},${filtered_count},${canonical_count}" \
    >> "$summary_file"

echo "Finished: $end_time"
echo "Final BAM: $sorted_final"
echo "Summary: $summary_file"

# Remove the unsorted intermediate BAM after successful completion.
rm -f "$bam_filtered"

done

