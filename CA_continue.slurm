#!/bin/bash

#SBATCH -J cutadatptQC-DOXChIP	  	# Job name
#SBATCH -o cutaQC-DXChIP.%j		# Name of stdout output file (%j expantds to jobID)
#SBATCH -p normal		# Queue name
#SBATCH -N 1			# Total number of nodes requested
#SBATCH -n 1 			# Total number of mpi tasks requested (normally 1)
#SBATCH -t 07:00:00		# Run time (hh:mm:ss)

#____________modules_____________
module unload xalt
module load tacc-apptainer
module load multiqc
module load biocontainers
module load cutadapt

### ------------Variables -----------

FASTQC_SIF="/scratch/09196/reneem/DOX_ChIP/fastqc_0.11.8.sif"

### Location!

cd /scratch/09196/reneem/DOX_ChIP/fastq_files

# BASE INPUT DIRECTORY
BASE="/scratch/09196/reneem/DOX_ChIP/fastq_files"

MERGED="$BASE/merged_files"
OUT="$BASE/cut-adapt_files"
SAMPLES="/scratch/09196/reneem/DOX_ChIP/sample_names_short.txt"
mkdir -p "$OUT"


#make other dirs
mkdir -p /scratch/09196/reneem/DOX_ChIP/fastq_files/cut-adapt_files/fastqc


mkdir -p /scratch/09196/reneem/DOX_ChIP/fastq_files/cut-adapt_files/multiqc

echo $(date) "running cut adapt on merged files"

while read -r i; do 
	cutadapt -a CTGTCTCTTATACACATCT -A CTGTCTCTTATACACATCT -j 0 -m 1 -o $OUT/${i}_R1_trim.fastq.gz -p $OUT/${i}_R2_trim.fastq.gz $MERGED/${i}_R1.fastq.gz $MERGED/${i}_R2.fastq.gz;done < "$SAMPLES"

echo $(date) "running fastqc on cut files"

apptainer exec $FASTQC_SIF fastqc -t 12 -o $OUT/fastqc/ $OUT/*.gz



##running multiqc on the files

multiqc $OUT/fastqc -o $OUT/multiqc/


## make checksum file

MASTER_MD5="$OUT/ca_merged_checksums.md5"
rm -f "$MASTER_MD5"
for f in "$OUT"/*.fastq.gz; do
    md5sum "$f" >> "$MASTER_MD5"
done
echo $(date) "DONE"
