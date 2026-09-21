#!/bin/bash

#!/bin/bash
#SBATCH -J macs3_callpeak
#SBATCH -o callpeak01.%A.%a		# Name of stdout output file (%j expantds to jobID)
#SBATCH -p normal		# Queue name
#SBATCH -N 1
#SBATCH -n 16
#SBATCH --array=1-36%5
#SBATCH -t 02:00:00

# ----------------- Modules -----------------
module unload xalt
module load tacc-apptainer
module load biocontainers
module load macs3
module load python3


CMD=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" macs3_callpeak_commands_MAPQ1_01.sh)
# Run it
echo "Running command ${SLURM_ARRAY_TASK_ID}:"
echo "$CMD"
eval "$CMD"



