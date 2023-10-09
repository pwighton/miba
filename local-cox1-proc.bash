#!/bin/bash

# To submit:
# sbatch --job-name=cox_proc --output=cox_proc_%j.out --mail-type=END,FAIL ./mlsc-cox1-proc.bash

#SBATCH --account=fsm
#SBATCH --partition=basic
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=0-16:00:00
#SBATCH --output=slurm-%A_%a.out

# PW match the 34 with `wc -l ${SUB_LIST}`
#SBATCH --array=1-34%34

export SUBJECTS_DIR=/autofs/vast/gerenuk/pwighton/pet/fs-subs
export FREESURFER_HOME=/usr/local/freesurfer/7.4.1

source $FREESURFER_HOME/SetUpFreeSurfer.sh

COX1_PROC=/autofs/vast/gerenuk/pwighton/pet/miba/cox1-proc

SUB_LIST=cox1-proc-mapping.txt

NUM_LINES=$(cat $SUB_LIST|wc -l)

for LINE_NUM in $(seq $NUM_LINES)
do
    SUB_NAME=$(cat $SUB_LIST | sed -n "${LINE_NUM}p" | awk '{print $1}')
    TIMEPOINT=$(cat $SUB_LIST | sed -n "${LINE_NUM}p" | awk '{print $2}')
    OUT_DIR=$(cat $SUB_LIST | sed -n "${LINE_NUM}p" | awk '{print $3}')
    OUT_DIR_FULL=${SUBJECTS_DIR}/${OUT_DIR}

    echo "SUB_NAME:     "${SUB_NAME}
    echo "TIMEPOINT:    "${TIMEPOINT}
    echo "OUT_DIR:      "${OUT_DIR}
    echo "OUT_DIR_FULL: "${OUT_DIR_FULL}

    echo "${COX1_PROC} --s ${SUB_NAME} --tp ${TIMEPOINT} --o ${OUT_DIR_FULL}"
    ${COX1_PROC} --s ${SUB_NAME} --tp ${TIMEPOINT} --o ${OUT_DIR_FULL}
done




