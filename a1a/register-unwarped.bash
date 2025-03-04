#!/bin/bash

export FREESURFER_HOME=/autofs/vast/freesurfer/centos7_x86_64/7.5.0

# Subject dir and output dir for non unwarped (orig) version of subjects
#export SUBJECTS_DIR=/autofs/vast/petsurfer/a1a-elmenhorst/subjects
#OUT_DIR=/autofs/vast/gerenuk/pwighton/pet/a1a/pet-register/orig

# Subject dir and output dir for unwarped version of subjects
export SUBJECTS_DIR=/autofs/vast/gerenuk/pwighton/pet/a1a/fs-subs-unwarped
OUT_DIR=/autofs/vast/gerenuk/pwighton/pet/a1a/pet-register/unwarped

source $FREESURFER_HOME/SetUpFreeSurfer.sh

#PET_LIST=/autofs/vast/gerenuk/pwighton/pet/a1a/sub-list-pet.txt
PET_LIST=/autofs/vast/gerenuk/pwighton/pet/a1a/sub-list-pet-single-subject.txt

PET_DIR=/autofs/vast/petsurfer/a1a-elmenhorst/unpacked/pet/

while read -r LINE;
do
  #echo $LINE
  SUB_NAME=`echo $LINE|awk '{print $1}'`
  PET_FILE=`echo $LINE|awk '{print $2}'`
  echo "================================================================="
  echo "SUB: ${SUB_NAME}; FILE: ${PET_FILE}"

  # Linear Registration
  mri_coreg \
    --mov $PET_DIR/$PET_FILE \
    --ref $SUBJECTS_DIR/$SUB_NAME/mri/brainmask.mgz \
    --reg $SUBJECTS_DIR/$SUB_NAME/mri/transforms/coreg--pet-to-brainmask.lta \
    --s $SUB_NAME
  
  # To test efficacy of grad unwarp
  bbregister \
    --mov $PET_DIR/$PET_FILE \
    --reg $SUBJECTS_DIR/$SUB_NAME/mri/transforms/bbreg--pet-to-brainmask.lta \
    --init-reg $SUBJECTS_DIR/$SUB_NAME/mri/transforms/coreg--pet-to-brainmask.lta \
    --s $SUB_NAME \
    --t2

  # register conform vol to mni152
  fs-synthmorph-reg --s $SUB_NAME

  # resample pet data into various mni spaces
  mkdir -p $SUBJECTS_DIR/$SUB_NAME/pet

  # resample the pet data into fsaverage space.  This data should not be used for subsequent resampling,
  # but to compute averages across ROIs
  mri_vol2vol \
    --mov $PET_DIR/$PET_FILE \
    --targ $SUBJECTS_DIR/$SUB_NAME/mri/aparc+aseg.mgz \
    --o $SUBJECTS_DIR/$SUB_NAME/pet/a1a.vt.fsaverage.nii.gz \
    --lta $SUBJECTS_DIR/$SUB_NAME/mri/transforms/coreg--pet-to-brainmask.lta
  
  # Compute a1a VT avg/std across ROIs
  mri_segstats \
    --seg $SUBJECTS_DIR/$SUB_NAME/mri/aparc+aseg.mgz \
    --ctab $FREESURFER_HOME/FreeSurferColorLUT.txt \
    --i $SUBJECTS_DIR/$SUB_NAME/pet/a1a.vt.fsaverage.nii.gz \
    --sum $SUBJECTS_DIR/$SUB_NAME/pet/a1a.vt.fsaverage.segstats.nii.gz
  
  # project a1a VT data onto surfaces (left hemi)
  mri_vol2surf \
    --mov $PET_DIR/$PET_FILE \
    --reg $SUBJECTS_DIR/$SUB_NAME/mri/transforms/coreg--pet-to-brainmask.lta \
    --hemi lh \
    --projfrac 0.5 \
    --o $SUBJECTS_DIR/$SUB_NAME/pet/a1a.vt.fsaverage.lh.nii.gz \
    --trgsubject fsaverage \
    --cortex
  
  # project a1a VT data onto surfaces (right hemi)
  mri_vol2surf \
    --mov $PET_DIR/$PET_FILE \
    --reg $SUBJECTS_DIR/$SUB_NAME/mri/transforms/coreg--pet-to-brainmask.lta \
    --hemi rh \
    --projfrac 0.5 \
    --o $SUBJECTS_DIR/$SUB_NAME/pet/a1a.vt.fsaverage.rh.nii.gz \
    --trgsubject fsaverage \
    --cortex

  # This command puts the pet data:
  #  - petvol-in-mni_icbm152_t1_tal_nlin_asym_09c.nii.gz
  # Into the same space as
  #  - mni_icbm152_t1_tal_nlin_asym_09c.nii.gz
  mri_vol2vol \
    --gcam \
      $PET_DIR/$PET_FILE \
      $SUBJECTS_DIR/$SUB_NAME/mri/transforms/bbreg--pet-to-brainmask.lta \
      $SUBJECTS_DIR/$SUB_NAME/mri/transforms/synthmorph.1.0mm.1.0mm/warp.to.mni152.1.0mm.1.0mm.nii.gz \
      0 \
      0 \
      1 \
      $SUBJECTS_DIR/$SUB_NAME/pet/petvol-in-mni_icbm152_t1_tal_nlin_asym_09c.nii.gz

  # This command puts the pet data:
  #  - petvol-in-mni152-1.5mm.nii.gz
  # Into the same space as
  #  - mni152.1.5mm.nii.gz
  mri_vol2vol \
    --gcam \
      $PET_DIR/$PET_FILE \
      $SUBJECTS_DIR/$SUB_NAME/mri/transforms/bbreg--pet-to-brainmask.lta \
      $SUBJECTS_DIR/$SUB_NAME/mri/transforms/synthmorph.1.0mm.1.0mm/warp.to.mni152.1.0mm.1.0mm.nii.gz \
      $FREESURFER_HOME/average/mni_icbm152_nlin_asym_09c/reg-targets/reg.1.5mm.to.1.0mm.lta \
      0 \
      1 \
      $SUBJECTS_DIR/$SUB_NAME/pet/petvol-in-mni152-1.5mm.nii.gz

  # This command puts the pet data:
  #  - petvol-in-mni152-2.0mm.nii.gz
  # Into the same space as
  #  - mni152.2.0mm.nii.gz
  mri_vol2vol \
    --gcam \
      $PET_DIR/$PET_FILE \
      $SUBJECTS_DIR/$SUB_NAME/mri/transforms/bbreg--pet-to-brainmask.lta \
      $SUBJECTS_DIR/$SUB_NAME/mri/transforms/synthmorph.1.0mm.1.0mm/warp.to.mni152.1.0mm.1.0mm.nii.gz \
      $FREESURFER_HOME/average/mni_icbm152_nlin_asym_09c/reg-targets/reg.2.0mm.to.1.0mm.lta \
      0 \
      1 \
      $SUBJECTS_DIR/$SUB_NAME/pet/petvol-in-mni152-2.0mm.nii.gz
done < "$PET_LIST"
