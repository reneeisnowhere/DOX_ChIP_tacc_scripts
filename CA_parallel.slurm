#!/bin/bash

#SBATCH -J CAQC-paraDOXChIP	  	# Job name
#SBATCH -o cutaQC-para.%A.%a		# Name of stdout output file (%j expantds to jobID)
#SBATCH -p normal		# Queue name
#SBATCH -N 1			# Total number of nodes requested
#SBATCH -n 1 			# Total number of mpi tasks requested (normally 1)
#SBATCH -t 04:00:00		# Run time (hh:mm:ss)
#SBATCH --array=1-48%5

module unload xalt
module load tacc-apptainer
module load biocontainers
module load cutadapt

FASTQC_SIF="/scratch/09196/reneem/DOX_ChIP/fastqc_0.11.8.sif"

BASE="/scratch/09196/reneem/DOX_ChIP/fastq_files"
MERGED="${BASE}/merged_files"
OUT="${BASE}/cut-adapt_files"
FASTQC_OUT="${OUT}/fastqc"
SAMPLES="/scratch/09196/reneem/DOX_ChIP/DOX_ChIP_sampleIDs.txt"

mkdir -p "$OUT"
mkdir -p "$FASTQC_OUT"
### because the samples file has a header:

line_number=$((SLURM_ARRAY_TASK_ID + 1))

# Select one sample from the sample-name file.
sample=$(awk -v line="$line_number" 'NR == line {print $1}' "$SAMPLES" | tr -d '\r')

echo "Array task ${SLURM_ARRAY_TASK_ID} selected: ${sample}"


if [[ -z "$sample" ]]; then
    echo "No sample found for array task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

if [[ "$sample" =~ [[:space:]] ]]; then
    echo "ERROR: sample contains whitespace: >>>$sample<<<"
    exit 1
fi

R1="${MERGED}/${sample}_R1.fastq.gz"
R2="${MERGED}/${sample}_R2.fastq.gz"

TRIM_R1="${OUT}/${sample}_R1_trim.fastq.gz"
TRIM_R2="${OUT}/${sample}_R2_trim.fastq.gz"

echo "$(date): processing ${sample}"

if [[ ! -f "$R1" ]]; then
    echo "Missing R1: $R1"
    exit 1
fi

if [[ ! -f "$R2" ]]; then
    echo "Missing R2: $R2"
    exit 1
fi

echo "$(date): running cutadapt for ${sample}"

cutadapt \
    -a CTGTCTCTTATACACATCT \
    -A CTGTCTCTTATACACATCT \
    -j 8 \
    -m 1 \
    -o "$TRIM_R1" \
    -p "$TRIM_R2" \
    "$R1" \
    "$R2"

status=$?

if [[ $status -ne 0 ]]; then
    echo "Cutadapt failed for ${sample} with exit code ${status}"
    exit "$status"
fi

echo "$(date): running FastQC for ${sample}"

apptainer exec "$FASTQC_SIF" fastqc \
    -t 8 \
    -o "$FASTQC_OUT" \
    "$TRIM_R1" \
    "$TRIM_R2"

status=$?

if [[ $status -ne 0 ]]; then
    echo "FastQC failed for ${sample} with exit code ${status}"
    exit "$status"
fi

echo "$(date): finished ${sample}"#____________modules_____________

