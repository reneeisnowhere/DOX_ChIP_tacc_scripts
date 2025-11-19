#!/bin/bash

#SBATCH -J fastqc2-DOXChIP	  	# Job name
#SBATCH -o fastqc2-DXChIP.%j		# Name of stdout output file (%j expantds to jobID)
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

# BASE INPUT DIRECTORY
BASE="/scratch/09196/reneem/DOX_ChIP/fastq_files"

LANE1="$BASE/Lane1"
LANE2="$BASE/Lane2"
OUT="$BASE/merged_files"

mkdir -p "$OUT"

echo "Merging FASTQ files from:"
echo "  $LANE1"
echo "  $LANE2"
echo "Output → $OUT"
echo ""

FILES=$( (ls "$LANE1"/*.fastq.gz 2>/dev/null; ls "$LANE2"/*.fastq.gz 2>/dev/null) \
         | xargs -n1 basename | sort | uniq )

for fname in $FILES; do
    f1="$LANE1/$fname"
    f2="$LANE2/$fname"
    out="$OUT/$fname"

    if [[ -f "$f1" && -f "$f2" ]]; then
        cat "$f1" "$f2" > "$out"
    elif [[ -f "$f1" ]]; then
        cp "$f1" "$out"
    elif [[ -f "$f2" ]]; then
        cp "$f2" "$out"
    fi
done

echo "Done!"

mkdir -p /scratch/09196/reneem/DOX_ChIP/fastq_files/merged_files/fastqc


mkdir -p /scratch/09196/reneem/DOX_ChIP/fastq_files/merged_files/multiqc


echo $(date) "running fastqc on merged files"

apptainer exec $FASTQC_SIF fastqc -t 12 -o /scratch/09196/reneem/DOX_ChIP/fastq_files/merged_files/fastqc/ /scratch/09196/reneem/DOX_ChIP/fastq_files/merged_files/*.gz



##running multiqc on the files

multiqc /scratch/09196/reneem/DOX_ChIP/fastq_files/merged_files/fastqc -o /scratch/09196/reneem/DOX_ChIP/fastq_files/merged_files/multiqc/


## make checksum file

MASTER_MD5="$OUT/merged_checksums.md5"
rm -f "$MASTER_MD5"
for f in "$OUT"/*.fastq.gz; do
    md5sum "$f" >> "$MASTER_MD5"
done
echo $(date) "DONE"
