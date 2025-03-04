#!/bin/bash

export FREESURFER_HOME=/autofs/vast/freesurfer/centos7_x86_64/7.5.0

# Subject dir and output dir for non unwarped version of subjects
export SUBJECTS_DIR=/autofs/vast/petsurfer/a1a-elmenhorst/subjects
OUT_DIR=/autofs/vast/gerenuk/pwighton/pet/a1a/bbregister/orig

# Subject dir and output dir for unwared version of subjects
#export SUBJECTS_DIR=/autofs/vast/gerenuk/pwighton/pet/a1a/fs-subs-unwarped
#OUT_DIR=/autofs/vast/gerenuk/pwighton/pet/a1a/bbregister/unwarped

source $FREESURFER_HOME/SetUpFreeSurfer.sh

PET_LIST=/autofs/vast/gerenuk/pwighton/pet/a1a/sub-list-pet.txt
PET_DIR=/autofs/vast/petsurfer/a1a-elmenhorst/unpacked/pet/

while read -r LINE;
do
  #echo $LINE
  SUB_NAME=`echo $LINE|awk '{print $1}'`
  PET_FILE=`echo $LINE|awk '{print $2}'`
  #echo "SUB: ${SUB_NAME}; FILE: ${PET_FILE}"

  mkdir -p $OUT_DIR/$SUB_NAME
  cd $OUT_DIR/$SUB_NAME
  mri_coreg \
    --mov $PET_DIR/$PET_FILE \
    --ref $SUBJECTS_DIR/$SUB_NAME/mri/brainmask.mgz \
    --reg ./coreg.lta \
    --s $SUB_NAME
  bbregister \
    --mov $PET_DIR/$PET_FILE \
    --reg $OUT_DIR/$SUB_NAME/bbreg.lta \
    --init-reg $OUT_DIR/$SUB_NAME/coreg.lta \
    --s 105_006 \
    --t2
done < "$PET_LIST"
