#!/bin/bash

#SBATCH -J pairedmetrics	  	# Job name
#SBATCH -o Paired_counts.%j		# Name of stdout output file (%j expantds to jobID)
#SBATCH -p vm-small		# Queue name
#SBATCH -N 1			# Total number of nodes requested
#SBATCH -n 1 			# Total number of mpi tasks requested (normally 1)
#SBATCH -t 12:00:00		# Run time (hh:mm:ss)


# ----------------- Modules -----------------
module unload xalt
module load tacc-apptainer
module load biocontainers

# ----------------- Variables -----------------
SAM_DIR="/scratch/09196/reneem/DOX_ChIP/sam_folder"
SEC_DIR="/scratch/09196/reneem/DOX_ChIP/bam_folder"
SIF_PATH="/scratch/09196/reneem/DOX_ChIP/samtools_1.9--h91753b0_5.sif"
CHRS="/scratch/09196/reneem/DOX_ChIP/chromosomes.txt"
FIN_DIR="/scratch/09196/reneem/DOX_ChIP/final_bam_folder"
OUT_DIR="/scratch/09196/reneem/DOX_ChIP/bl_filtered_bams"

mkdir -p "$OUT_DIR"

SUMMARY="$OUT_DIR/full_read_count_summary.csv"
echo "Sample,Start,End,Properly_Paired_Reads,Properly_Paired_Unique_Reads,Properly_Paired_Unique_noChrM_Reads,Prop_Uni_noM_dedup_Reads" > "$SUMMARY"

# ----------------- Loop through SAM files -----------------
for sam_file in "$SAM_DIR"/*.sam; do
base=$(basename "$sam_file" .sam)
    start_time=$(date +"%Y-%m-%d %H:%M:%S")

    echo "$base: Start at $start_time"

    bam_ppu="${SEC_DIR}/${base}.proper_unique.bam"
    sorted_final="${FIN_DIR}/${base}.proper_unique.noChrM.sorted.bam"
    dedup_final="${FIN_DIR}/${base}.proper_unique.noChrM.sorted.dedup.bam"
    filter_final="${OUT_DIR}/${base}.filtered.bam"
[[ -f "$bam_ppu" && -f "$sorted_final" && -f "$dedup_final" && -f "$filter_final" ]] || {
        echo "Skipping $base (missing files)"
        continue
    } 
# Index filtered BAM if index does not exist
if [[ ! -f "${filter_final}.bai" ]]; then
    apptainer exec "$SIF_PATH" samtools index -@ 16 "$filter_final"
fi

    # 1) Counts
    proper_count=$(apptainer exec "$SIF_PATH" samtools view -c -f 0x2 "$sam_file")
    unique_count=$(apptainer exec "$SIF_PATH" samtools view -c "$bam_ppu")
    nochrM_count=$(apptainer exec "$SIF_PATH" samtools view -c "$sorted_final")
    dedup_count=$(apptainer exec "$SIF_PATH" samtools view -c "$dedup_final")
    filt_count=$(apptainer exec "$SIF_PATH" samtools view -c "$filter_final")

    end_time=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$base: Finished at $end_time"

    # 2) Append to summary
    echo "${base},${start_time},${end_time},${proper_count},${unique_count},${nochrM_count},${dedup_count},${filt_count} \
        >> "$SUMMARY"
done

