#!/bin/bash

#SBATCH -J alignarray	  	# Job name
#SBATCH -o align-DXChIP.%A_%a.out		# Name of stdout output file (%j expantds to jobID)
#SBATCH -p normal		# Queue name
#SBATCH -N 1			# Total number of nodes requested
#SBATCH -n 1 			# Total number of mpi tasks requested (normally 1)
#SBATCH -t 04:00:00		# Run time (hh:mm:ss)
#SBATCH --array=1-48%5

#____________modules_____________
module unload xalt
module load tacc-apptainer
#module load multiqc
#module load biocontainers
##module load cutadapt

### ------------Variables -----------

BOWTIE2_SIF="/scratch/09196/reneem/DOX_ChIP/bowtie2.sif"
BT2_INDEX="/scratch/09196/reneem/GRCh38/bowtie2_index/GRCh38_noalt_as/GRCh38_noalt_as"
### Location!


BASE_DIR="/scratch/09196/reneem/DOX_ChIP"
TRIMFILES="${BASE_DIR}/fastq_files/cut-adapt_files"
SAMPLES="${BASE_DIR}/DOX_ChIP_samplenames.txt"
SAM_DIR="${BASE_DIR}/sam_folder"

mkdir -p "${BASE_DIR}/logs"
mkdir -p "$SAM_DIR"

sample=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLES" | tr -d '\r')

if [[ -z "$sample" ]]; then
	echo "no sample found for array task ${SLURM_ARRAY_TASK_ID}"
	exit 1
fi

R1="${TRIMFILES}/${sample}_R1_trim.fastq.gz"

R2="${TRIMFILES}/${sample}_R2_trim.fastq.gz"

SAM="${SAM_DIR}/${sample}.sam"

echo "$(date): processing ${sample}"


if [[ ! -f "$R1" ]]; then
	echo "Missing R1: $R1"
	exit 1
fi

if [[ ! -f "$R2" ]]; then
	echo "Missing R2: $R2"
	exit 1
fi

	apptainer exec "$BOWTIE2_SIF" bowtie2 -q --threads 8 --very-sensitive --no-mixed --no-discordant --phred33 -x "$BT2_INDEX" -1 "$R1" -2 "$R2" -S "$SAM" 2> "${BASE_DIR}/logs/${sample}_bowtie2.log"


echo "$(date): finished ${sample}"



status=$?

if [[ $status -eq 0 ]]; then
    echo "$(date): finished ${sample}"
else
    echo "$(date): Bowtie2 failed for ${sample} with exit code ${status}"
    exit "$status"
fi

