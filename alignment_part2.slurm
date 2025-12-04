#!/bin/bash

#SBATCH -J alignment_DOXChIP	  	# Job name
#SBATCH -o set2align-DXChIP.%j		# Name of stdout output file (%j expantds to jobID)
#SBATCH -p normal		# Queue name
#SBATCH -N 1			# Total number of nodes requested
#SBATCH -n 1 			# Total number of mpi tasks requested (normally 1)
#SBATCH -t 22:00:00		# Run time (hh:mm:ss)

#____________modules_____________
module unload xalt
module load tacc-apptainer
module load multiqc
module load biocontainers
##module load cutadapt

### ------------Variables -----------

BOWTIE2_SIF="/scratch/09196/reneem/DOX_ChIP/bowtie2.sif"
BT2_INDEX="/scratch/09196/reneem/GRCh38/bowtie2_index/GRCh38_noalt_as/GRCh38_noalt_as"
### Location!

cd /scratch/09196/reneem/DOX_ChIP
mkdir -p sam_folder

# BASE INPUT DIRECTORY
TRIMFILES="/scratch/09196/reneem/DOX_ChIP/fastq_files/cut-adapt_files"
SAMPLES="/scratch/09196/reneem/DOX_ChIP/sample_names_set2.txt"


#make other dirs

echo $(date) "running Bowtie2 on trimmed files"


while read -r i; do 
	 echo "==== Processing sample: $i ====" >> set2_output.txt;
	apptainer exec $BOWTIE2_SIF bowtie2 -q --threads 12 --very-sensitive --no-mixed --no-discordant --phred33 -x $BT2_INDEX -1 $TRIMFILES/${i}_R1_trim.fastq.gz -2 $TRIMFILES/${i}_R2_trim.fastq.gz -S sam_folder/${i}.sam 2>> set2_output.txt
 done < "$SAMPLES"

echo $(date) "DONE"
