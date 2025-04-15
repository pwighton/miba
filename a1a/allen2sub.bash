#!/bin/bash

export FREESURFER_HOME=/autofs/vast/freesurfer/centos7_x86_64/7.5.0
export SUBJECTS_DIR=/autofs/vast/gerenuk/pwighton/pet/a1a/fs-subs-unwarped

source $FREESURFER_HOME/SetUpFreeSurfer.sh

# Output dir for outputs of this script.  This dir will be created inside each subject's dir
export OUTPUT_DIR=allen

#PET_LIST=/autofs/vast/gerenuk/pwighton/pet/a1a/sub-list-pet.txt
PET_LIST=/autofs/vast/gerenuk/pwighton/pet/a1a/sub-list-pet-single-subject.txt

# Allen files were downloaded from:
#  - https://www.meduniwien.ac.at/neuroimaging/mRNA.html
# These files do not work directly with mri_vol2vol
# They needed to first be converted to LAS, using `nii2las.py`

ALLEN_FILES="/autofs/vast/gerenuk/pwighton/pet/a1a/allen/134_mirr_mRNA_las.nii /autofs/vast/gerenuk/pwighton/pet/a1a/allen134_mRNA_las.nii"

while read -r LINE;
do
  SUB_NAME=`echo $LINE|awk '{print $1}'`
  
  for ALLEN_FILE in $ALLEN_FILES; do
    echo "================================================================="
    echo "SUB: ${SUB_NAME}"
    echo "ALLEN_FILE: ${ALLEN_FILE}"
  done

done < "$PET_LIST"
