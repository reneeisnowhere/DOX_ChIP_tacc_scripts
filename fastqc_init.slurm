#!/bin/bash

#SBATCH -J fastqc-DOXChIP	  	# Job name
#SBATCH -o fastqc-DXChIP.%j		# Name of stdout output file (%j expantds to jobID)
#SBATCH -p development		# Queue name
#SBATCH -N 1			# Total number of nodes requested
#SBATCH -n 1 			# Total number of mpi tasks requested (normally 1)
#SBATCH -t 02:00:00		# Run time (hh:mm:ss)

#____________modules_____________
module unload xalt
module load tacc-apptainer
module load multiqc
module load biocontainers


### ------------Variables -----------

FASTQC_SIF="/scratch/09196/reneem/DOX_ChIP/fastqc_0.11.8.sif"

### Location!

cd /scratch/09196/reneem/DOX_ChIP/fastq_files

mkdir -p /scratch/09196/reneem/DOX_ChIP/fastq_files/Lane1/fastqc
mkdir -p /scratch/09196/reneem/DOX_ChIP/fastq_files/Lane2/fastqc

mkdir -p /scratch/09196/reneem/DOX_ChIP/fastq_files/Lane1/multiqc
mkdir -p /scratch/09196/reneem/DOX_ChIP/fastq_files/Lane2/multiqc


echo $(date) "running fastqc on Lane1"

apptainer exec $FASTQC_SIF fastqc -t 12 -o /scratch/09196/reneem/DOX_ChIP/fastq_files/Lane1/fastqc/ /scratch/09196/reneem/DOX_ChIP/fastq_files/Lane1/*.gz

echo $(date) "running fastqc on Lane2"

apptainer exec $FASTQC_SIF fastqc -t 12 -o /scratch/09196/reneem/DOX_ChIP/fastq_files/Lane2/fastqc/ /scratch/09196/reneem/DOX_ChIP/fastq_files/Lane2/*.gz

##running multiqc on the files

multiqc /scratch/09196/reneem/DOX_ChIP/fastq_files/Lane1/fastqc -o /scratch/09196/reneem/DOX_ChIP/fastq_files/Lane1/multiqc/

multiqc /scratch/09196/reneem/DOX_ChIP/fastq_files/Lane2/fastqc -o /scratch/09196/reneem/DOX_ChIP/fastq_files/Lane2/multiqc/

echo $(date) "DONE"
