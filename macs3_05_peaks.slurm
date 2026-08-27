#!/bin/bash

#!/bin/bash
#SBATCH -J macs3_callpeak
#SBATCH -o callpeak05.%A.%a		# Name of stdout output file (%j expantds to jobID)
#SBATCH -p normal		# Queue name
#SBATCH -N 1
#SBATCH -n 16
#SBATCH --array=3-36%5
#SBATCH -t 01:30:00

# ----------------- Modules -----------------
module unload xalt
module load tacc-apptainer
module load biocontainers
module load macs3
module load python3


CMD=$(sed -n "${SLURM_ARRAY_TASK_ID}p" macs3_q05_commands.txt)

# Run it
echo "Running command ${SLURM_ARRAY_TASK_ID}:"
echo "$CMD"
eval "$CMD"



