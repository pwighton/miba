#!/bin/bash

# $SUBJECTS_DIR should be set before run

# Location of mapping file, each line has
#  - sub-name
#  - ses-name
#  - petsurfer proc dir
#  - bids pet img sidecar (json)
#    - assumes an corresponding .nii.gz file also exists
#  - bloodstram file  
MAP_FILE="/autofs/vast/gerenuk/pwighton/pet/miba/cox1-preproc-mapping.txt"

# Top level directory of pet imaging data
IMG_REF_DIR="/autofs/vast/gerenuk/pwighton/pet/ds004230-plus-cox1blocked"

# Top level directory of bloodstream data
BLOOD_REF_DIR="/autofs/vast/gerenuk/pwighton/pet/ds004230-plus-cox1blocked--bloodstream2023-08-28_id-tfK8--martin"

# Location of integrate.py
CALC_FRAMEWISE_AIF_PY="/autofs/vast/gerenuk/pwighton/pet/miba/calc_framewise_aif.py"

echo "SUBJECTS_DIR:         "$SUBJECTS_DIR
echo "MAP_FILE:             "$MAP_FILE
echo "IMG_REF_DIR:          "$IMG_REF_DIR
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
    BLOODSTREAM_FILE=$(cat $MAP_FILE | sed -n "${LINE_NUM}p" | awk '{print $4}')
    
    echo "SUB_NAME:         "$SUB_NAME
    echo "PET_SUBDIR:       "$PET_SUBDIR
    echo "BLOODSTREAM_FILE: "$BLOODSTREAM_FILE
    echo "PET_JSON_FILE:    "$PET_JSON_FILE
    PET_IMG_FILE=$(echo "${PET_JSON_FILE%%.*}")".nii.gz"
    echo "PET_IMG_FILE:     "$PET_IMG_FILE
    
    PETSURFER_DIR=$SUBJECTS_DIR/$SUB_NAME/$PET_SUBDIR
    echo "PETSURFER_DIR:    "$PETSURFER_DIR 
    
    echo "rm -rf ${PETSURFER_DIR}"
    rm -rf ${PETSURFER_DIR}

    echo "mkdir -p ${PETSURFER_DIR}"
    mkdir -p ${PETSURFER_DIR}

    echo "cp ${IMG_REF_DIR}/${PET_IMG_FILE} ${PETSURFER_DIR}/pet.nii.gz"
    cp ${IMG_REF_DIR}/${PET_IMG_FILE} ${PETSURFER_DIR}/pet.nii.gz

    echo "mc-afni2 --i ${PETSURFER_DIR}/pet.nii.gz --o ${PETSURFER_DIR}/pet.mc.nii.gz --mcdat ${PETSURFER_DIR}/mc-afni2--motion-parameters.dat"
    mc-afni2 --i ${PETSURFER_DIR}/pet.nii.gz --o ${PETSURFER_DIR}/pet.mc.nii.gz --mcdat ${PETSURFER_DIR}/mc-afni2--motion-parameters.dat
    
    echo "${CALC_FRAMEWISE_AIF_PY} -a ${BLOOD_REF_DIR}/${BLOODSTREAM_FILE} -b ${IMG_REF_DIR}/${PET_JSON_FILE} -o ${PETSURFER_DIR}/aif.bloodstream.dat"
    ${CALC_FRAMEWISE_AIF_PY} -a ${BLOOD_REF_DIR}/${BLOODSTREAM_FILE} -b ${IMG_REF_DIR}/${PET_JSON_FILE} -o ${PETSURFER_DIR}/aif.bloodstream.dat
done
