#!/bin/bash

# To submit:
# sbatch --job-name=petprep4730 --output=petprep4730_%j.out --mail-type=END,FAIL ./mlsc-petprep-hmc-ds004730.bash

# To monitor:
# squeue | grep <username>

#SBATCH --account=fsm
#SBATCH --partition=basic
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=0-24:00:00
#SBATCH --output=slurm-%A_%a.out

INPUT_DIR=/autofs/vast/gerenuk/pwighton/pet/leucine/ds004730-download
OUTPUT_DIR=/autofs/vast/gerenuk/pwighton/pet/leucine/petprep-output/ds004730
FS_LICENSE=/autofs/vast/freesurfer/centos7_x86_64/dev/.license
SINGULARITY_CONTAINER=/autofs/vast/gerenuk/pwighton/pet/petprep_hmc_0.0.8.sif
# match to `SBATCH --cpus-per-task` above
NUM_PROCS=16

# Make sure $SINGULARITY_TMPDIR is a local drive 
# - `/scratch` is local on mlsc
# - `/scratch/${SLURM_JOBID}` is automatically created when the job starts
# - see https://it.martinos.org/mlsc-cluster/
singularity_temp_dir=$(mktemp -d -p /scratch/${SLURM_JOBID} singularity.XXXXXX)
export SINGULARITY_TMPDIR=${singularity_temp_dir}

echo "INPUT_DIR:              "${INPUT_DIR}
echo "OUTPUT_DIR:             "${OUTPUT_DIR}
echo "FS_LICENSE_FILE:        "${FS_LICENSE}
echo "SINGULARITY_CONTAINER:  "${SINGULARITY_CONTAINER}
echo "SINGULARITY_TMPDIR:     "${SINGULARITY_TMPDIR}
echo "NUM_PROCS:              "${NUM_PROCS}
echo "SLURM_JOBID:            "${SLURM_JOBID}

singularity run \
    -B ${INPUT_DIR}:/data/input \
    -B ${OUTPUT_DIR}:/data/output \
    -B ${FS_LICENSE}:/opt/freesurfer/license.txt \
    ${SINGULARITY_CONTAINER} \
      --bids_dir /data/input \
      --output_dir /data/output \
      --analysis_level participant \
      --n_procs ${NUM_PROCS}
