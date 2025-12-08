#!/bin/bash

#SBATCH -J sam2bam_DOXChIP	  	# Job name
#SBATCH -o sam2bam.%j		# Name of stdout output file (%j expantds to jobID)
#SBATCH -p normal		# Queue name
#SBATCH -N 1			# Total number of nodes requested
#SBATCH -n 1 			# Total number of mpi tasks requested (normally 1)
#SBATCH -t 12:00:00		# Run time (hh:mm:ss)
#SBATCH --cpus-per-task=128
#SBATCH --mem=192G
#____________modules_____________
module unload xalt
module load tacc-apptainer
module load parallel
module load biocontainers




### ------------Variables -----------
# Paths
SAM_DIR="/scratch/09196/reneem/DOX_ChIP/sam_folder"
OUT_DIR="/scratch/09196/reneem/DOX_ChIP/bam_folder"
SIF_PATH="/scratch/09196/reneem/DOX_ChIP/samtools_1.9--h91753b0_5.sif"

mkdir -p "$OUT_DIR"

# Resources
TOTAL_CORES=128
JOBS=6
THREADS=$((TOTAL_CORES / JOBS))       # 21 threads per job
MEM_PER_JOB=$((192 / JOBS))           # 32 GB per job
MEM_PER_THREAD=$((MEM_PER_JOB / THREADS))  # 1.5 GB per thread

echo "Running $JOBS jobs in parallel with $THREADS threads each"
echo "Memory per job: ${MEM_PER_JOB}G, Memory per thread: ${MEM_PER_THREAD}G"

# Summary CSV
SUMMARY="$OUT_DIR/full_summary_counts.csv"
echo "Sample,Start,End,Properly_Paired,Properly_Paired_Unique,Properly_Paired_Unique_noChrM" > "$SUMMARY"

# Function to process a single SAM file
process_sam() {
    sam_file="$1"
    base=$(basename "$sam_file" .sam)
    
    start_time=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$base: Start at $start_time"

    # 1️⃣ Convert SAM -> BAM
    bam="$OUT_DIR/${base}.bam"
    apptainer exec $SIF_PATH samtools view -Sb -@ $THREADS "$sam_file" -o "$bam"

    # 2️⃣ Count properly paired reads
    proper_count=$(apptainer exec $SIF_PATH samtools view -c -f 0x2 "$bam")

    # 3️⃣ Extract properly paired + uniquely mapped reads
    proper_unique="$OUT_DIR/${base}.proper_unique.bam"
    apptainer exec $SIF_PATH samtools view -b -@ $THREADS -f 0x2 -q 1 "$bam" -o "$proper_unique"
    unique_count=$(apptainer exec $SIF_PATH samtools view -c "$proper_unique")

    # Delete initial BAM
    rm -f "$bam"

    # 4️⃣ Remove chrM reads
    nochrM="$OUT_DIR/${base}.proper_unique.nochrM.bam"
    chrs=$(apptainer exec $SIF_PATH samtools idxstats "$proper_unique" | cut -f1 | grep -v chrM | tr '\n' ' ')
    apptainer exec $SIF_PATH samtools view -b -@ $THREADS "$proper_unique" $chrs > "$nochrM"
    nochrM_count=$(apptainer exec $SIF_PATH samtools view -c "$nochrM")

    # Delete intermediate proper_unique BAM
    rm -f "$proper_unique"

    # 5️⃣ Sort & index final BAM
    sorted="$OUT_DIR/${base}.proper_unique.nochrM.sorted.bam"
    apptainer exec $SIF_PATH samtools sort -@ $THREADS -m ${MEM_PER_THREAD}G -o "$sorted" "$nochrM"
    apptainer exec $SIF_PATH samtools index "$sorted"

    # Delete unsorted BAM
    rm -f "$nochrM"

    end_time=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$base: Finished at $end_time"

    # 6️⃣ Append counts + timestamps to summary CSV
    echo "${base},${start_time},${end_time},${proper_count},${unique_count},${nochrM_count}" \
	    > "$OUT_DIR/${base}.summary.tmp.csv"
}

export -f process_sam
export OUT_DIR
export THREADS
export MEM_PER_THREAD
export SUMMARY
export SIF_PATH

# Run all SAM files in parallel across 8 jobs
find "$SAM_DIR" -name "*.sam" | parallel -j $JOBS process_sam {}

echo "Sample,Start,End,Properly_Paired,Properly_Paired_Unique,Properly_Paired_Unique_noChrM" > "$SUMMARY"
cat "$OUT_DIR"/*.summary.tmp.csv >> "$SUMMARY"

# Optional: delete temporary summary files
#rm -f "$OUT_DIR"/*.summary.tmp.csv





