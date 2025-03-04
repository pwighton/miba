#!/bin/bash

export FREESURFER_HOME=/autofs/vast/freesurfer/centos7_x86_64/7.5.0

# Subject dir and output dir for non unwarped (orig) version of subjects
export SUBJECTS_DIR=/autofs/vast/petsurfer/a1a-elmenhorst/subjects
OUT_DIR=/autofs/vast/gerenuk/pwighton/pet/a1a/pet-register/orig

# Subject dir and output dir for unwarped version of subjects
#export SUBJECTS_DIR=/autofs/vast/gerenuk/pwighton/pet/a1a/fs-subs-unwarped
#OUT_DIR=/autofs/vast/gerenuk/pwighton/pet/a1a/pet-register/unwarped

source $FREESURFER_HOME/SetUpFreeSurfer.sh

PET_LIST=/autofs/vast/gerenuk/pwighton/pet/a1a/sub-list-pet.txt
#PET_LIST=/autofs/vast/gerenuk/pwighton/pet/a1a/sub-list-pet-single-subject.txt

PET_DIR=/autofs/vast/petsurfer/a1a-elmenhorst/unpacked/pet/

while read -r LINE;
do
  #echo $LINE
  SUB_NAME=`echo $LINE|awk '{print $1}'`
  PET_FILE=`echo $LINE|awk '{print $2}'`
  echo "================================================================="
  echo "SUB: ${SUB_NAME}; FILE: ${PET_FILE}"

  mkdir -p $OUT_DIR/$SUB_NAME
  cd $OUT_DIR/$SUB_NAME
  # Linear Registration
  mri_coreg \
    --mov $PET_DIR/$PET_FILE \
    --ref $SUBJECTS_DIR/$SUB_NAME/mri/brainmask.mgz \
    --reg ./coreg.lta \
    --s $SUB_NAME
  # To test efficacy of grad unwarp
  bbregister \
    --mov $PET_DIR/$PET_FILE \
    --reg $OUT_DIR/$SUB_NAME/bbreg.lta \
    --init-reg $OUT_DIR/$SUB_NAME/coreg.lta \
    --s 105_006 \
    --t2
  # Synthmorph; default
  mri_synthmorph \
    -t $OUT_DIR/$SUB_NAME/synthmorph--pet2mri--warp.nii.gz \
    -o $OUT_DIR/$SUB_NAME/synthmorph--pet2mri.nii.gz \
    $PET_DIR/$PET_FILE \
    $SUBJECTS_DIR/$SUB_NAME/mri/brainmask.mgz
  # Synthmorph; deform only
  mri_synthmorph \
    -m deform \
    -i $OUT_DIR/$SUB_NAME/coreg.lta \
    -t $OUT_DIR/$SUB_NAME/synthmorph--pet2mri-deformonly--warp.nii.gz \
    -o $OUT_DIR/$SUB_NAME/synthmorph--pet2mri-deformonly.nii.gz \
    $PET_DIR/$PET_FILE \
    $SUBJECTS_DIR/$SUB_NAME/mri/brainmask.mgz
  # Convert synthmorph warps to m3z
  mri_warp_convert \
    --insrcgeom $OUT_DIR/$SUB_NAME/synthmorph--pet2mri--warp.nii.gz \
    --inras $OUT_DIR/$SUB_NAME/synthmorph--pet2mri--warp.nii.gz \
    --outm3z $OUT_DIR/$SUB_NAME/synthmorph--pet2mri--warp.m3z
  mri_warp_convert \
    --insrcgeom $OUT_DIR/$SUB_NAME/synthmorph--pet2mri-deformonly--warp.nii.gz \
    --inras $OUT_DIR/$SUB_NAME/synthmorph--pet2mri-deformonly--warp.nii.gz \
    --outm3z $OUT_DIR/$SUB_NAME/synthmorph--pet2mri-deformonly--warp.m3z
  # Sanity checks
  # These vols should be identical:
  #   - pet-in-mr-space--synthmorph-sanity-check.nii.gz
  #   - synthmorph--pet2mri.nii.gz
  # And:
  #   - pet-in-mr-space--synthmorph-sanity-check-deformonly.nii.gz
  #   - synthmorph--pet2mri-deformonly.nii.gz
  mri_vol2vol \
    --gcam \
      $PET_DIR/$PET_FILE \
      $OUT_DIR/$SUB_NAME/coreg.lta \
      $OUT_DIR/$SUB_NAME/synthmorph--pet2mri--warp.m3z \
      0 \
      0 \
      1 \
      $OUT_DIR/$SUB_NAME/pet-in-mr-space--synthmorph-sanity-check.nii.gz
  mri_vol2vol \
    --gcam \
      $PET_DIR/$PET_FILE \
      $OUT_DIR/$SUB_NAME/coreg.lta \
      $OUT_DIR/$SUB_NAME/synthmorph--pet2mri-deformonly--warp.m3z \
      0 \
      0 \
      1 \
      $OUT_DIR/$SUB_NAME/pet-in-mr-space--synthmorph-sanity-check-deformonly.nii.gz  
done < "$PET_LIST"
