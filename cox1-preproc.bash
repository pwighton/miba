#!/bin/bash

# 

# Location of mapping file, each line has
#  - sub-name
#  - ses-name
#  - bids pet img sidecar (json)
#  - pet imaging timeseries file
#  - bloodstram file  

MAP_FILE="cox1-preproc-mapping.txt"

SUBJECTS_DIR="/autofs/vast/gerenuk/pwighton/pet/fs-subs"

# Top level directory of pet imaging data
IMG_REF_DIR="/autofs/vast/gerenuk/pwighton/pet/ds004230-plus-cox1blocked"

# Top level directory of motion corrected pet imaging data
MOCO_REF_DIR="/autofs/vast/gerenuk/pwighton/pet/ds004230-plus-cox1blocked--petprep-hmc--384176a6cc6b"

# Top level directory of bloodstream data
BLOOD_REF_DIR="/autofs/vast/gerenuk/pwighton/pet/ds004230-plus-cox1blocked--bloodstream2023-08-28_id-tfK8--martin"

# Location of integrate.py
CALC_FRAMEWISE_AIF_PY="/autofs/vast/gerenuk/pwighton/pet/miba/calc_framewise_aif.py"

echo "SUBJECTS_DIR:         "$SUBJECTS_DIR
echo "MAP_FILE:             "$MAP_FILE
echo "IMG_REF_DIR:          "$IMG_REF_DIR
echo "MOCO_REF_DIR:         "$MOCO_REF_DIR
echo "BLOOD_REF_DIR:        "$BLOOD_REF_DIR

# Make the file tsec.txt
#  Assumes consistent frame timing across dataset
PET_JSON_FILE=$(cat $MAP_FILE | sed -n "1p" | awk '{print $3}')
echo "jq '.FrameTimesStart[]' ${IMG_REF_DIR}/${PET_JSON_FILE} > $SUBJECTS_DIR/tsec.txt"
jq '.FrameTimesStart[]' ${IMG_REF_DIR}/${PET_JSON_FILE} > $SUBJECTS_DIR/tsec.txt

NUM_LINES=$(cat $MAP_FILE|wc -l)
for LINE_NUM in $(seq $NUM_LINES)
do
    SUB_NAME=$(cat $MAP_FILE| sed -n "${LINE_NUM}p" | awk '{print $1}')
    PET_SUBDIR=$(cat $MAP_FILE | sed -n "${LINE_NUM}p" | awk '{print $2}')
    PET_JSON_FILE=$(cat $MAP_FILE | sed -n "${LINE_NUM}p" | awk '{print $3}')
    PET_MOCO_FILE=$(cat $MAP_FILE | sed -n "${LINE_NUM}p" | awk '{print $4}')
    BLOODSTREAM_FILE=$(cat $MAP_FILE | sed -n "${LINE_NUM}p" | awk '{print $5}')
    
    echo "SUB_NAME:          "$SUB_NAME
    echo "PET_SUBDIR:        "$PET_SUBDIR
    echo "BLOODSTREAM_FILE:  "$BLOODSTREAM_FILE
    echo "PET_JSON_FILE:     "$PET_JSON_FILE
    PET_IMG_FILE=$(echo "${PET_JSON_FILE%%.*}")".nii.gz"
    echo "PET_IMG_FILE:      "$PET_IMG_FILE
    echo "PET_MOCO_FILE:     "$PET_MOCO_FILE
    
    PETSURFER_DIR=$SUBJECTS_DIR/$SUB_NAME/$PET_SUBDIR
    echo "PETSURFER_DIR:    "$PETSURFER_DIR 
    
    echo "rm -rf ${PETSURFER_DIR}"
    rm -rf ${PETSURFER_DIR}

    echo "mkdir -p ${PETSURFER_DIR}"
    mkdir -p ${PETSURFER_DIR}

    echo "cp ${MOCO_REF_DIR}/${PET_MOCO_FILE} ${PETSURFER_DIR}/pet.nii.gz"
    cp ${MOCO_REF_DIR}/${PET_MOCO_FILE} ${PETSURFER_DIR}/pet.nii.gz

    echo "mri_concat ${PETSURFER_DIR}/pet.nii.gz --mean --o ${PETSURFER_DIR}/pet.mn.nii.gz"
    mri_concat ${PETSURFER_DIR}/pet.nii.gz --mean --o ${PETSURFER_DIR}/pet.mn.nii.gz

    echo "${CALC_FRAMEWISE_AIF_PY} -a ${BLOOD_REF_DIR}/${BLOODSTREAM_FILE} -b ${IMG_REF_DIR}/${PET_JSON_FILE} -o ${PETSURFER_DIR}/aif.bloodstream.dat"
    ${CALC_FRAMEWISE_AIF_PY} -a ${BLOOD_REF_DIR}/${BLOODSTREAM_FILE} -b ${IMG_REF_DIR}/${PET_JSON_FILE} -o ${PETSURFER_DIR}/aif.bloodstream.dat
done
