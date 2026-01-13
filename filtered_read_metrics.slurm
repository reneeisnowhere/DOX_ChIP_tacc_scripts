#!/bin/bash

#SBATCH -J filt_metrics	  	# Job name
#SBATCH -o read_counts.%j		# Name of stdout output file (%j expantds to jobID)
#SBATCH -p normal		# Queue name
#SBATCH -N 1			# Total number of nodes requested
#SBATCH -n 1 			# Total number of mpi tasks requested (normally 1)
#SBATCH -t 1:00:00		# Run time (hh:mm:ss)
#SBATCH --array=1-48%6

# ----------------- Modules -----------------
module unload xalt
module load tacc-apptainer
module load biocontainers

# ----------------- Variables -----------------
BAM_LIST="/scratch/09196/reneem/DOX_ChIP/bam_list.txt"
PP_BAM_DIR="/scratch/09196/reneem/DOX_ChIP/bam_folder"
SAMTOOLS_SIF="/scratch/09196/reneem/DOX_ChIP/samtools_1.9--h91753b0_5.sif"
BAM2_DIR="/scratch/09196/reneem/DOX_ChIP/final_bam_folder"
BAM3_DIR="/scratch/09196/reneem/DOX_ChIP/bl_filtered_bams"
#OUT_FILE="/scratch/09196/reneem/DOX_ChIP/final_counts_file.txt"


# ----------------- Using file dir -----------------
BAM=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$BAM_LIST")


if [[ -z "$BAM" ]]; then
	echo "No BAM found for task ${SLURM_ARRAY_TASK_ID}"
	exit 1
fi

SAMPLE=$(basename "$BAM" .proper_unique.noChrM.sorted.dedup.bam)

BAM1="${PP_BAM_DIR}/${SAMPLE}.proper_unique.bam"
BAM2="${BAM2_DIR}/${SAMPLE}.proper_unique.noChrM.sorted.bam"
BAM4="${BAM3_DIR}/${SAMPLE}.filtered.bam"

echo "[$(date)] Processing $SAMPLE"

READS1=$(apptainer exec "$SAMTOOLS_SIF" samtools view -c "$BAM1")
READS2=$(apptainer exec "$SAMTOOLS_SIF" samtools view -c "$BAM2")
READS3=$(apptainer exec "$SAMTOOLS_SIF" samtools view -c "$BAM")
READS4=$(apptainer exec "$SAMTOOLS_SIF" samtools view -c "$BAM4")

### write output-----------------------
OUT_FILE="/scratch/09196/reneem/DOX_ChIP/${SAMPLE}.counts.txt"
echo -e "Sample\tPropPairedUnique\tNuclear\tDedup\tnoBL" > "$OUT_FILE"
echo -e "${SAMPLE}\t${READS1}\t${READS2}\t${READS3}\t${READS4}" >> "$OUT_FILE"

echo "[$(date)} Done for $SAMPLE"

