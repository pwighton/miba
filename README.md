## Steps to create a MIBA

Using the following datasets:
  - [ds004230](https://openneuro.org/datasets/ds004230)
  - `cox1blocked`
  
## 1) Run `petprep_hmc`

Run `petprep_hmc` on the datasets to generate motion corrected pet timeseries.

- See the [repo](https://github.com/mnoergaard/petprep_hmc) for details.
- Also see [this issue](https://github.com/mnoergaard/petprep_hmc/issues/11) documenting container running notes. 
- The container ID used was `384176a6cc6b` (`martinnoergaard/petprep_hmc:latest` as of 20231005)

On `ds004230`:
```
docker run -it --rm \
    -v /home/paul/lcn/20230918-bloodstream-r/ds004230-plus-cox1blocked/ds004230:/data/input \
    -v /home/paul/lcn/20230918-bloodstream-r/ds004230-plus-cox1blocked/petprep-hmc:/data/output \
    -v /home/paul/lcn/license.txt:/opt/freesurfer/license.txt \
    -e SUBJECTS_DIR=/data/output \
    -e PATH=/opt/freesurfer/bin:/opt/freesurfer/fsfast/bin:/opt/freesurfer/tktools:/opt/fsl/bin:/opt/freesurfer/mni/bin:/opt/freesurfer/bin:/opt/fsl/bin:/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/fsl/bin \
    martinnoergaard/petprep_hmc:latest \
        --bids_dir /data/input \
        --output_dir /data/output \
        --n_procs 12
```

On `cox1blocked`:
```
docker run -it --rm \
    -v /home/paul/lcn/20230918-bloodstream-r/ds004230-plus-cox1blocked/cox1blocked:/data/input \
    -v /home/paul/lcn/20230918-bloodstream-r/ds004230-plus-cox1blocked/petprep-hmc2:/data/output \
    -v /home/paul/lcn/license.txt:/opt/freesurfer/license.txt \
    -e SUBJECTS_DIR=/data/output \
    -e PATH=/opt/freesurfer/bin:/opt/freesurfer/fsfast/bin:/opt/freesurfer/tktools:/opt/fsl/bin:/opt/freesurfer/mni/bin:/opt/freesurfer/bin:/opt/fsl/bin:/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/fsl/bin \
    martinnoergaard/petprep_hmc:latest \
        --bids_dir /data/input \
        --output_dir /data/output \
        --n_procs 12 \
        --skip_bids_validator
```

## 2) Merge datasets

Merge `ds004230` and `cox1blocked` into a single dataset.

- We do this *after* `petprep_hmc` since the inconsistent `ses` naming (`rescan` vs `blocked`) interferes with `petprep_hmc`
- We do this *before* `bloodstream` since we're using hierarchical modeling in #3 which implies the processsing is not independent (pw: ? verify) 

The following subjects were used going forward:

- sub-PS19
- sub-PS20
- sub-PS21
- sub-PS24
- sub-PS26
- sub-PS27
- sub-PS28
- sub-PS38
- sub-PS39
- sub-PS42
- sub-PS50
- sub-PS51
- sub-PS52
- sub-PS53
- sub-PS54
- sub-PS55
- sub-PS56

## 3) Run `bloodstream` 

Run `bloodstream` to model and upsample artierial input functions (AIF)

- See the [repo](https://github.com/mathesong/bloodstream) for details and this [PR](https://github.com/mathesong/bloodstream/pull/11) for functionality to run non-interactivley in a container
- The config file was `config_2023-08-28_id-tfK8--martin.json`.
- The container ID used was `796cd379c2c0` (`pwighton/bloodstream:20230929` as of 20230929)

```  
docker run -it --rm \
  -v ${HOME}:/home/jovyan/work \
  pwighton/bloodstream:20230929 \
    /home/jovyan/run-bloodstream.R \
      -s /home/jovyan/work/lcn/20230918-bloodstream-r/ds004230-plus-cox1blocked \
      -c /home/jovyan/work/lcn/20230918-bloodstream-r/config_2023-08-28_id-tfK8--martin.json
```

## 4) Run `FreeSurfer 7.4.1`

For each subject, run:
```
recon-all -all $SUB
gtmseg -s $SUB
mni152reg --s $SUB
```

- Place the `global-expert-options.txt` file in $SUBJECTS_DIR before running
- The script `mlsc-recon-all.bash` can be used to submit these processing jobs to a SLURM compute cluster, which reads the file `ds004230-plus-cox1blocked-subject-list.txt` to determine what to process.

## 5) Run `cox1-preproc.bash`

Edit `cox1-preproc.bash` and set:
- `MAP_FILE`
- `IMG_REF_DIR`
- `BLOOD_REF_DIR`
- `CALC_FRAMEWISE_AIF_PY`

Run `cox1-preproc.bash` which:

- Takes as input a mapping file (`cox1-preproc-mapping.txt`) containing
  - fs subjects
  - pet study dirs
  - pet `.json` sidecar file
  - motion corrected pet imaging file
  - bloodstream file
- And:
  - Creates the file `$SUBJECTS_DIR/tsec.txt`
    - Currently assumes frame timing constant across study
  - For each line in provenance file:
    - Creates the folder `${SUBJECTS_DIR}/${FS+SUBJECT}/${PET_STUDY}`
    - Copies `${PET_IMAGE}` to `${SUBJECTS_DIR}/${FS+SUBJECT}/${PET_STUDY}/pet.nii.gz`
    - Creates a mean image across time from `${SUBJECTS_DIR}/${FS+SUBJECT}/${PET_STUDY}/pet.nii.gz`
    - Creates mean AIF per PET frame (`${SUBJECTS_DIR}/${FS_SUBJECT}/${PET_STUDY}/aif.bloodstream.dat`) by running `calc_framewise_aif.py` on the bloodstream file
    
## 5) Run `cox1-proc`

Run `cox1-proc` on each pet session, which:
  - Registers `pet.mn.nii.gz` to the anatomical using `mri_coreg`
  - Maps the subject's `aparc+aseg` to PET space
  - Creates a brainmask in PET space
  - Runs `mri_gtmpvc`
  - Runs `mri_glmfit` to peform an Logan analysis
  - Maps the results ("Distribution Volume Ratio"; DVR) to fsaverage space

## 6) Run `miba_gen.py`

### To generate the average across the first session of all subjects

In volumetric space:
```
cd $SUBJECTS_DIR
/home/paul/lcn/git/miba/miba_gen.py \
  --mean \
  -i ./sub-PS39/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ./sub-PS56/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ./sub-PS28/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ./sub-PS54/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ./sub-PS52/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ./sub-PS53/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ./sub-PS51/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ./sub-PS19/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ./sub-PS42/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ./sub-PS21/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ./sub-PS24/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ./sub-PS26/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ./sub-PS55/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ./sub-PS27/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ./sub-PS38/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ./sub-PS20/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ./sub-PS50/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
   -o cox1.miba.fsaverage.nii.gz
```

On the surface of the left hemisphere
```
cd $SUBJECTS_DIR
/home/paul/lcn/git/miba/miba_gen.py \
  --mean \
  -i ./sub-PS39/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ./sub-PS56/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ./sub-PS28/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ./sub-PS54/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ./sub-PS52/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ./sub-PS53/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ./sub-PS51/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ./sub-PS19/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ./sub-PS42/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ./sub-PS21/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ./sub-PS24/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ./sub-PS26/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ./sub-PS55/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ./sub-PS27/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ./sub-PS38/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ./sub-PS20/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ./sub-PS50/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
   -o cox1.miba.fsaverage.lh.nii.gz
```

On the surface of the right hemisphere
```
cd $SUBJECTS_DIR
/home/paul/lcn/git/miba/miba_gen.py \
  --mean \
  -i ./sub-PS39/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ./sub-PS56/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ./sub-PS28/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ./sub-PS54/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ./sub-PS52/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ./sub-PS53/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ./sub-PS51/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ./sub-PS19/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ./sub-PS42/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ./sub-PS21/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ./sub-PS24/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ./sub-PS26/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ./sub-PS55/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ./sub-PS27/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ./sub-PS38/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ./sub-PS20/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ./sub-PS50/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
   -o cox1.miba.fsaverage.rh.nii.gz
```

### To generate the average difference between unblocked and blocked

First generate the difference between unblocked and blocked for each subject:

(*PW: I'm having trouble processing sub-PS50_sess-blocked for some reason, so that subject is currently excluded*)

```
cd $SUBJECTS_DIR
for SUB in sub-PS51 sub-PS52 sub-PS53 sub-PS54 sub-PS55 sub-PS56
do
  /home/paul/lcn/git/miba/miba_gen.py \
    --diff \
    -i ./${SUB}/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
       ./${SUB}/pet2/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
    -o cox1.${SUB}.diff.fsaverage.nii.gz
done
```

Then average:
```
cd $SUBJECTS_DIR
/home/paul/lcn/git/miba/miba_gen.py \
  --mean \
  -i cox1.sub-PS51.diff.fsaverage.nii.gz \
     cox1.sub-PS52.diff.fsaverage.nii.gz \
     cox1.sub-PS53.diff.fsaverage.nii.gz \
     cox1.sub-PS54.diff.fsaverage.nii.gz \
     cox1.sub-PS55.diff.fsaverage.nii.gz \
     cox1.sub-PS56.diff.fsaverage.nii.gz \
  -o cox1.miba.unblocked-vs-blocked.fsaverage.nii.gz
```

Repeat for surface overlays:

```
cd $SUBJECTS_DIR
for SUB in sub-PS51 sub-PS52 sub-PS53 sub-PS54 sub-PS55 sub-PS56
do
  /home/paul/lcn/git/miba/miba_gen.py \
    --diff \
    -i ./${SUB}/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
       ./${SUB}/pet2/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
    -o cox1.${SUB}.diff.fsaverage.lh.nii.gz
done
```

```
cd $SUBJECTS_DIR
for SUB in sub-PS51 sub-PS52 sub-PS53 sub-PS54 sub-PS55 sub-PS56
do
  /home/paul/lcn/git/miba/miba_gen.py \
    --diff \
    -i ./${SUB}/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
       ./${SUB}/pet2/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
    -o cox1.${SUB}.diff.fsaverage.rh.nii.gz
done
```

```
cd $SUBJECTS_DIR
/home/paul/lcn/git/miba/miba_gen.py \
  --mean \
  -i cox1.sub-PS51.diff.fsaverage.rh.nii.gz \
     cox1.sub-PS52.diff.fsaverage.rh.nii.gz \
     cox1.sub-PS53.diff.fsaverage.rh.nii.gz \
     cox1.sub-PS54.diff.fsaverage.rh.nii.gz \
     cox1.sub-PS55.diff.fsaverage.rh.nii.gz \
     cox1.sub-PS56.diff.fsaverage.rh.nii.gz \
  -o cox1.miba.unblocked-vs-blocked.fsaverage.rh.nii.gz
```

```
cd $SUBJECTS_DIR
/home/paul/lcn/git/miba/miba_gen.py \
  --mean \
  -i cox1.sub-PS51.diff.fsaverage.lh.nii.gz \
     cox1.sub-PS52.diff.fsaverage.lh.nii.gz \
     cox1.sub-PS53.diff.fsaverage.lh.nii.gz \
     cox1.sub-PS54.diff.fsaverage.lh.nii.gz \
     cox1.sub-PS55.diff.fsaverage.lh.nii.gz \
     cox1.sub-PS56.diff.fsaverage.lh.nii.gz \
  -o cox1.miba.unblocked-vs-blocked.fsaverage.lh.nii.gz
```

## 6) Generate figures

### Figures of the average across the first session of all subjects

```
freeview \
  --volume \
    ${FREESURFER_HOME}/subjects/fsaverage/mri/orig.mgz \
    ${SUBJECTS_DIR}/cox1.miba.fsaverage.nii.gz:colormap=heat:opacity=0.5:heatscale=1.8,2.3,2.8:heatscale_options=truncate \
  --ras 0 -10 0 \
  --cc \
  --viewport axial \
  --colorscale \
  --screenshot ./axial.mean.png 2 true
```

```
freeview \
  --volume \
    ${FREESURFER_HOME}/subjects/fsaverage/mri/orig.mgz \
    ${SUBJECTS_DIR}/cox1.miba.fsaverage.nii.gz:colormap=heat:opacity=0.5:heatscale=1.8,2.3,2.8:heatscale_options=truncate \
  --ras 0 -10 0 \
  --cc \
  --viewport sagittal \
  --colorscale \
  --screenshot ./sagittal.mean.png 2 true
```

```
freeview \
  --surface \
    ${FREESURFER_HOME}/subjects/fsaverage/surf/lh.white:overlay=${SUBJECTS_DIR}/cox1.miba.fsaverage.lh.nii.gz:overlay_threshold=1.80,2.80:overlay_color=heat,truncate:annot=${FREESURFER_HOME}/subjects/fsaverage/label/lh.aparc.annot:annot_outline=1 \
  --viewport 3d \
  --colorscale \
  --screenshot ./lh.mean.white.png 2 true
```

```
freeview \
  --surface \
    ${FREESURFER_HOME}/subjects/fsaverage/surf/lh.inflated:overlay=${SUBJECTS_DIR}/cox1.miba.fsaverage.lh.nii.gz:overlay_threshold=1.80,2.80:overlay_color=heat,truncate:annot=${FREESURFER_HOME}/subjects/fsaverage/label/lh.aparc.annot:annot_outline=1 \
  --viewport 3d \
  --colorscale \
  --screenshot ./lh.mean.inflated.png 2 true
```

### Figures of the average across (unblocked - blocked)

```
freeview \
  --volume \
    ${FREESURFER_HOME}/subjects/fsaverage/mri/orig.mgz \
    ${SUBJECTS_DIR}/cox1.miba.unblocked-vs-blocked.fsaverage.nii.gz:colormap=heat:opacity=0.5:heatscale=0.0,1.4,2.8:heatscale_options=truncate \
  --ras 0 -10 0 \
  --cc \
  --viewport axial \
  --colorscale \
  --screenshot ./axial.mean.unblocked-vs-blocked.png 2 true
```

```
freeview \
  --volume \
    ${FREESURFER_HOME}/subjects/fsaverage/mri/orig.mgz \
    ${SUBJECTS_DIR}/cox1.miba.unblocked-vs-blocked.fsaverage.nii.gz:colormap=heat:opacity=0.5:heatscale=0.0,1.4,2.8:heatscale_options=truncate \
  --ras 0 -10 0 \
  --cc \
  --viewport sagittal \
  --colorscale \
  --screenshot ./sagittal.mean.unblocked-vs-blocked.png 2 true
```

```
freeview \
  --surface \
    ${FREESURFER_HOME}/subjects/fsaverage/surf/lh.white:overlay=${SUBJECTS_DIR}/cox1.miba.unblocked-vs-blocked.fsaverage.lh.nii.gz:overlay_threshold=0.00,2.80:overlay_color=heat,truncate:annot=${FREESURFER_HOME}/subjects/fsaverage/label/lh.aparc.annot:annot_outline=1 \
  --viewport 3d \
  --colorscale \
  --screenshot ./lh.mean.white.unblocked-vs-blocked.png 2 true
```

```
freeview \
  --surface \
    ${FREESURFER_HOME}/subjects/fsaverage/surf/lh.inflated:overlay=${SUBJECTS_DIR}/cox1.miba.unblocked-vs-blocked.fsaverage.lh.nii.gz:overlay_threshold=0.00,2.80:overlay_color=heat,truncate:annot=${FREESURFER_HOME}/subjects/fsaverage/label/lh.aparc.annot:annot_outline=1 \
  --viewport 3d \
  --colorscale \
  --screenshot ./lh.mean.inflated.unblocked-vs-blocked.png 2 true
```

## References

- OHBM 2023 abstract: https://ww6.aievolution.com/hbm2301/index.cfm?do=abs.viewAbs&abs=2785
- PetSurfer: https://surfer.nmr.mgh.harvard.edu/fswiki/PetSurfer
- Bloodstream walkthrough: https://www.youtube.com/watch?v=Kud6MWYPKxg
- Logan method: https://www.pmod.com/files/download/v31/doc/pkin/2329.htm

