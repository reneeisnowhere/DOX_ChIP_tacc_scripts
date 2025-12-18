#!/bin/bash

#!/bin/bash
#SBATCH -J macs3_callpeak
#SBATCH -o callpeak.%j		# Name of stdout output file (%j expantds to jobID)
#SBATCH -p development		# Queue name
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 02:00:00

# ----------------- Modules -----------------
module unload xalt
module load tacc-apptainer
module load biocontainers
module load macs3
module load bedtools
# ----------------- Variables -----------------
BAM_DIR="/scratch/09196/reneem/DOX_ChIP/final_bam_folder"
OUT_DIR="/scratch/09196/reneem/DOX_ChIP/peak_call_initial"
SIF_PATH="/scratch/09196/reneem/DOX_ChIP/samtools_1.9--h91753b0_5.sif"
CHRS="/scratch/09196/reneem/DOX_ChIP/chromosomes.txt"
TMP_DIR="$OUT_DIR/tmp"

mkdir -p "$OUT_DIR"
#mkdir -p "$OUT_DIR/tmp"


# Summary file (optional, each job writes its own partial summary)
SUMMARY="$OUT_DIR/summary_${SLURM_ARRAY_TASK_ID}.csv"
echo "Sample,Start,End,Input_Count,NoChrM_Count,Dedup_Count" > "$SUMMARY"
#-----------------Select BAM for this task ----------------

#BAM_LIST=("$BAM_DIR"/*.bam)
BAM_LIST=("$BAM_DIR"/MCW_SP_ChIP{71..74}.proper_unique.bam)
bam_file="${BAM_LIST[$SLURM_ARRAY_TASK_ID-1]}"   # array IDs start at 1
base=$(basename "$bam_file" .bam)

start_time=$(date +"%Y-%m-%d %H:%M:%S")
echo "$base: Start at $start_time"

sorted_final="${OUT_DIR}/${base}.noChrM.sorted.bam"
dedup_bam="${OUT_DIR}/${base}.noChrM.sorted.dedup.bam"
metrics="${OUT_DIR}/${base}.noChrM.sorted.dedup.metrics.txt"

# 1) Filter chromosomes + sort
apptainer exec "$SIF_PATH" bash -c "
    samtools view -@ ${THREADS} -b -L '${CHRS}' '${bam_file}' | \
    samtools sort -@ ${THREADS} -m ${MEM_PER_THREAD} -o '${sorted_final}' -
"

# 2) Remove duplicates
gatk MarkDuplicates \
    -I "${sorted_final}" \
    -O "${dedup_bam}" \
    -M "${metrics}" \
    --REMOVE_DUPLICATES true \
    --CREATE_INDEX true

# 3) Counts
input_count=$(apptainer exec "$SIF_PATH" samtools view -c "${bam_file}")
noChrM_count=$(apptainer exec "$SIF_PATH" samtools view -c "${sorted_final}")
dedup_count=$(apptainer exec "$SIF_PATH" samtools view -c "${dedup_bam}")

end_time=$(date +"%Y-%m-%d %H:%M:%S")
echo "$base: Finished at $end_time"

# 4) Append to summary
echo "${base},${start_time},${end_time},${input_count},${noChrM_count},${dedup_count}" \
    >> "$SUMMARY"

