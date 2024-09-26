#!/bin/bash

# To submit:
# sbatch --job-name=leucine_recon --output=leucine_recon_%j.out --mail-type=END,FAIL ./mlsc-recon-all.bash

# To monitor:
# squeue | grep <username>

#SBATCH --account=fsm
#SBATCH --partition=basic
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=0-16:00:00
#SBATCH --output=slurm-%A_%a.out

# PW match the 63 with `wc -l ${SUB_LIST}`
#SBATCH --array=1-63%9

export SUBJECTS_DIR=/autofs/vast/gerenuk/pwighton/pet/leucine/fs-subs
export FREESURFER_HOME=/usr/local/freesurfer/dev
export MNI152REG_FNIRT=/autofs/vast/gerenuk/pwighton/pet/miba/mni152reg.fnirt

source $FREESURFER_HOME/SetUpFreeSurfer.sh

SUB_LIST=/autofs/vast/gerenuk/pwighton/pet/miba/leucine/recon-all-sub-list.txt

INPUT_FILE=$(cat $SUB_LIST | sed -n "${SLURM_ARRAY_TASK_ID}p" | awk '{print $1}')
SUB_NAME=$(cat $SUB_LIST | sed -n "${SLURM_ARRAY_TASK_ID}p" | awk '{print $2}')

echo "SUB_NAME:   "${SUB_NAME}
echo "INPUT_FILE: "${INPUT_FILE}

recon-all -all -i ${INPUT_FILE} -s ${SUB_NAME}
gtmseg --s ${SUB_NAME}
mni152reg --s ${SUB_NAME}
${MNI152REG_FNIRT} --s ${SUB_NAME}
