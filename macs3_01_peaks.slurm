#!/bin/bash

#!/bin/bash
#SBATCH -J macs3_callpeak
#SBATCH -o callpeak.%j		# Name of stdout output file (%j expantds to jobID)
#SBATCH -p normal		# Queue name
#SBATCH -N 1
#SBATCH -n 16
#SBATCH --array=1-38%8
#SBATCH -t 06:00:00

# ----------------- Modules -----------------
module unload xalt
module load tacc-apptainer
module load biocontainers
module load macs3
module load python3


CMD=$(sed -n "${SLURM_ARRAY_TASK_ID}p" macs3_commands.txt)

# Run it
eval $CMD



