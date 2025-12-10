#!/bin/bash

#SBATCH -J sam2bam_DOXChIP	  	# Job name
#SBATCH -o sam2bam.%j		# Name of stdout output file (%j expantds to jobID)
#SBATCH -p normal		# Queue name
#SBATCH -N 1			# Total number of nodes requested
#SBATCH -n 1 			# Total number of mpi tasks requested (normally 1)
#SBATCH -t 24:00:00		# Run time (hh:mm:ss)
#SBATCH --cpus-per-task=128
#SBATCH --mem=192G

# ----------------- Modules -----------------
module unload xalt
module load tacc-apptainer
#module load parallel
module load biocontainers

# ----------------- Variables -----------------
SAM_DIR="/scratch/09196/reneem/DOX_ChIP/sam_folder"
OUT_DIR="/scratch/09196/reneem/DOX_ChIP/bam_folder"
SIF_PATH="/scratch/09196/reneem/DOX_ChIP/samtools_1.9--h91753b0_5.sif"
CHRS="/scratch/09196/reneem/DOX_ChIP/chromosomes.txt"

mkdir -p "$OUT_DIR"

# Threads and memory
THREADS=128
MEM_PER_THREAD=$((192 / THREADS))G

# Summary CSV
SUMMARY="$OUT_DIR/full_summary_counts.csv"
echo "Sample,Start,End,Properly_Paired,Properly_Paired_Unique,Properly_Paired_Unique_noChrM" > "$SUMMARY"

# ----------------- Loop through SAM files -----------------
for sam_file in "$SAM_DIR"/*.sam; do
    base=$(basename "$sam_file" .sam)
    start_time=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$base: Start at $start_time"

    sorted_final="$OUT_DIR/${base}.proper_unique.nochrM.sorted.bam"
    chrs=$(tr '\n' ' ' < "$CHRS")

    # Step 1: Convert SAM -> BAM, filter properly paired & uniquely mapped, remove unwanted chromosomes, and sort
    apptainer exec $SIF_PATH bash -c '
        samtools view -b -@ '"$THREADS"' -f 0x2 -q 1 '"$sam_file"' | \
        samtools view -b -@ '"$THREADS"' -h -o - '"$chrs"' | \
        samtools sort -@ '"$THREADS"' -m '"$MEM_PER_THREAD"' -o '"$sorted_final"'
    '

    # Step 2: Index final BAM
    apptainer exec $SIF_PATH samtools index "$sorted_final"

    # Step 3: Count reads
    proper_count=$(apptainer exec $SIF_PATH samtools view -c -f 0x2 "$sam_file")
    unique_count=$(apptainer exec $SIF_PATH samtools view -c -f 0x2 -q 1 "$sam_file")
    nochrM_count=$(apptainer exec $SIF_PATH samtools view -c "$sorted_final")

    end_time=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$base: Finished at $end_time"

    # Step 4: Append to summary
    echo "${base},${start_time},${end_time},${proper_count},${unique_count},${nochrM_count}" \
        >> "$SUMMARY"
done


