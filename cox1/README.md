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

## 6) Compute Vnd via Lassen plot

- Vnd is the x-intercept of the lassen plot
- regions to use/merge is specified in `occupancy-merge.json`

```
export SUBJECTS_DIR=/home/paul/lcn/20230918-bloodstream-r/fs-subs
export MERGE_DATA=/home/paul/lcn/git/miba/occupancy-merge.json
export CALC_VND=/home/paul/lcn/git/miba/calc_vnd.py

for SUBJECT in sub-PS50 sub-PS51 sub-PS52 sub-PS53 sub-PS54 sub-PS55 sub-PS56
do
    $CALC_VND \
      -m $MERGE_DATA \
      --seg-base $SUBJECTS_DIR/$SUBJECT/pet1/apas.nii.gz \
      --dvr-base $SUBJECTS_DIR/$SUBJECT/pet1/glmfit.logan/dvr/gamma.nii.gz \
      --seg-block $SUBJECTS_DIR/$SUBJECT/pet2/apas.nii.gz \
      --dvr-block $SUBJECTS_DIR/$SUBJECT/pet2/glmfit.logan/dvr/gamma.nii.gz \
      -o $SUBJECTS_DIR/$SUBJECT/pet-lassen.json \
      -ofig $SUBJECTS_DIR/$SUBJECT/pet-lassen.png
done
```

This generates the following values:

| Subject   | Vnd                | Occupancy          |
| ---------:| ------------------:| ------------------:|
| sub-PS50  | 1.1319486599814665 | 0.7869641734671312 |
| sub-PS51  | 1.1192285589034248 | 0.7959955315691787 |
| sub-PS52  | 1.0496236020838752 | 0.7542152189502245 |
| sub-PS53  | 1.153529523200513  | 0.8902525060612867 |
| sub-PS54  | 1.5011441337708775 | 0.9089416391564102 |
| sub-PS55  | 0.9736405141537436 | 0.6999053740530418 |
| sub-PS56  | 1.2181914901342907 | 0.7805440613678035 |

Values from Nafiseh:

| Subject   | Vnd                | Occupancy          |
| ---------:| ------------------:| ------------------:|
| sub-PS50  | 1.446              | 0.8343             |
| sub-PS51  | 1.349              | 0.8216             |
| sub-PS52  | 1.197              | 0.8483             |
| sub-PS53  | 1.112              | 0.9189             |
| sub-PS54  | 2.326              | 0.988              |
| sub-PS55  | 1.139              | 0.7026             |
| sub-PS56  | 2.379              | 0.8267             |
| sub-PS57  | 2.429              | 0.7932             |

## 7) Run `miba_gen.py`

### To generate the average across the first session of all subjects

In volumetric space:
```
export SUBJECTS_DIR=/home/paul/lcn/20230918-bloodstream-r/fs-subs

/home/paul/lcn/git/miba/miba_gen.py \
  --mean \
  -i ${SUBJECTS_DIR}/sub-PS19/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ${SUBJECTS_DIR}/sub-PS20/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ${SUBJECTS_DIR}/sub-PS21/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ${SUBJECTS_DIR}/sub-PS24/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ${SUBJECTS_DIR}/sub-PS26/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ${SUBJECTS_DIR}/sub-PS27/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ${SUBJECTS_DIR}/sub-PS28/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ${SUBJECTS_DIR}/sub-PS38/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ${SUBJECTS_DIR}/sub-PS39/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ${SUBJECTS_DIR}/sub-PS42/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ${SUBJECTS_DIR}/sub-PS50/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ${SUBJECTS_DIR}/sub-PS51/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ${SUBJECTS_DIR}/sub-PS52/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ${SUBJECTS_DIR}/sub-PS53/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ${SUBJECTS_DIR}/sub-PS54/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ${SUBJECTS_DIR}/sub-PS55/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
     ${SUBJECTS_DIR}/sub-PS56/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
   -o cox1.miba.vt.fsaverage.nii.gz
```

On the surface of the left hemisphere
```
export SUBJECTS_DIR=/home/paul/lcn/20230918-bloodstream-r/fs-subs

/home/paul/lcn/git/miba/miba_gen.py \
  --mean \
  -i ${SUBJECTS_DIR}/sub-PS19/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS20/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS21/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS24/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS26/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS27/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS28/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS38/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS39/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS42/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS50/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS51/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS52/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS53/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS54/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS55/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS56/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
   -o cox1.miba.vt.fsaverage.lh.nii.gz
```

On the surface of the right hemisphere
```
cd $SUBJECTS_DIR
/home/paul/lcn/git/miba/miba_gen.py \
  --mean \
  -i ${SUBJECTS_DIR}/sub-PS19/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS20/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS21/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS24/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS26/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS27/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS28/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS38/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS39/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS42/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS50/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS51/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS52/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS53/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS54/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS55/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
     ${SUBJECTS_DIR}/sub-PS56/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
   -o cox1.miba .vt.fsaverage.rh.nii.gz
```

### To generate Vs (Vt - Vnd) for each baseline/blocked subject

First generate Vs (Vt - Vnd) for each subject:

```
export SUBJECTS_DIR=/home/paul/lcn/20230918-bloodstream-r/fs-subs
SUB_LIST=(sub-PS50 sub-PS51 sub-PS52 sub-PS53 sub-PS54 sub-PS55 sub-PS56)
VND_LIST=(1.446 1.349 1.197 1.112 2.326 1.139 2.379)

for i in "${!SUB_LIST[@]}"
do
  SUB=${SUB_LIST[i]}
  VND=${VND_LIST[i]}
  echo $SUB $VND
  /home/paul/lcn/git/miba/miba_gen.py \
    --diff-const \
    -i ${SUBJECTS_DIR}/${SUB}/pet1/glmfit.logan/dvr/dvr.fsaverage.nii.gz \
    -cv ${VND} \
    -o cox1.${SUB}.vnd.fsaverage.nii.gz
  /home/paul/lcn/git/miba/miba_gen.py \
    --diff-const \
    -i ${SUBJECTS_DIR}/${SUB}/pet1/glmfit.logan/dvr/dvr.fsaverage.lh.nii.gz \
    -cv ${VND} \
    -o cox1.${SUB}.vnd.fsaverage.lh.nii.gz
  /home/paul/lcn/git/miba/miba_gen.py \
    --diff-const \
    -i ${SUBJECTS_DIR}/${SUB}/pet1/glmfit.logan/dvr/dvr.fsaverage.rh.nii.gz \
    -cv ${VND} \
    -o cox1.${SUB}.vnd.fsaverage.rh.nii.gz
done
```

Then average:
```
/home/paul/lcn/git/miba/miba_gen.py \
  --mean \
  -i cox1.sub-PS50.vnd.fsaverage.nii.gz \
     cox1.sub-PS51.vnd.fsaverage.nii.gz \
     cox1.sub-PS52.vnd.fsaverage.nii.gz \
     cox1.sub-PS53.vnd.fsaverage.nii.gz \
     cox1.sub-PS54.vnd.fsaverage.nii.gz \
     cox1.sub-PS55.vnd.fsaverage.nii.gz \
     cox1.sub-PS56.vnd.fsaverage.nii.gz \
  -o cox1.miba.vnd.fsaverage.nii.gz
```

```
/home/paul/lcn/git/miba/miba_gen.py \
  --mean \
  -i cox1.sub-PS50.vnd.fsaverage.rh.nii.gz \
     cox1.sub-PS51.vnd.fsaverage.rh.nii.gz \
     cox1.sub-PS52.vnd.fsaverage.rh.nii.gz \
     cox1.sub-PS53.vnd.fsaverage.rh.nii.gz \
     cox1.sub-PS54.vnd.fsaverage.rh.nii.gz \
     cox1.sub-PS55.vnd.fsaverage.rh.nii.gz \
     cox1.sub-PS56.vnd.fsaverage.rh.nii.gz \
  -o cox1.miba.vnd.fsaverage.rh.nii.gz
```

```
/home/paul/lcn/git/miba/miba_gen.py \
  --mean \
  -i cox1.sub-PS50.vnd.fsaverage.lh.nii.gz \
     cox1.sub-PS51.vnd.fsaverage.lh.nii.gz \
     cox1.sub-PS52.vnd.fsaverage.lh.nii.gz \
     cox1.sub-PS53.vnd.fsaverage.lh.nii.gz \
     cox1.sub-PS54.vnd.fsaverage.lh.nii.gz \
     cox1.sub-PS55.vnd.fsaverage.lh.nii.gz \
     cox1.sub-PS56.vnd.fsaverage.lh.nii.gz \
  -o cox1.miba.vnd.fsaverage.lh.nii.gz
```

### To generate BPND (Vs / Vnd) for each baseline/blocked subject

```
SUB_LIST=(sub-PS50 sub-PS51 sub-PS52 sub-PS53 sub-PS54 sub-PS55 sub-PS56)
VND_LIST=(1.446 1.349 1.197 1.112 2.326 1.139 2.379)

for i in "${!SUB_LIST[@]}"
do
  SUB=${SUB_LIST[i]}
  VND=${VND_LIST[i]}
  echo $SUB $VND
  /home/paul/lcn/git/miba/miba_gen.py \
    --div-const \
    -i cox1.${SUB}.vnd.fsaverage.nii.gz \
    -cv ${VND} \
    -o cox1.${SUB}.bpnd.fsaverage.nii.gz
  /home/paul/lcn/git/miba/miba_gen.py \
    --div-const \
    -i cox1.${SUB}.vnd.fsaverage.lh.nii.gz \
    -cv ${VND} \
    -o cox1.${SUB}.bpnd.fsaverage.lh.nii.gz
  /home/paul/lcn/git/miba/miba_gen.py \
    --div-const \
    -i cox1.${SUB}.vnd.fsaverage.rh.nii.gz \
    -cv ${VND} \
    -o cox1.${SUB}.bpnd.fsaverage.rh.nii.gz
done
```

Then average:
```
/home/paul/lcn/git/miba/miba_gen.py \
  --mean \
  -i cox1.sub-PS50.bpnd.fsaverage.nii.gz \
     cox1.sub-PS51.bpnd.fsaverage.nii.gz \
     cox1.sub-PS52.bpnd.fsaverage.nii.gz \
     cox1.sub-PS53.bpnd.fsaverage.nii.gz \
     cox1.sub-PS54.bpnd.fsaverage.nii.gz \
     cox1.sub-PS55.bpnd.fsaverage.nii.gz \
     cox1.sub-PS56.bpnd.fsaverage.nii.gz \
  -o cox1.miba.bpnd.fsaverage.nii.gz
```

```
/home/paul/lcn/git/miba/miba_gen.py \
  --mean \
  -i cox1.sub-PS50.bpnd.fsaverage.rh.nii.gz \
     cox1.sub-PS51.bpnd.fsaverage.rh.nii.gz \
     cox1.sub-PS52.bpnd.fsaverage.rh.nii.gz \
     cox1.sub-PS53.bpnd.fsaverage.rh.nii.gz \
     cox1.sub-PS54.bpnd.fsaverage.rh.nii.gz \
     cox1.sub-PS55.bpnd.fsaverage.rh.nii.gz \
     cox1.sub-PS56.bpnd.fsaverage.rh.nii.gz \
  -o cox1.miba.bpnd.fsaverage.rh.nii.gz
```

```
/home/paul/lcn/git/miba/miba_gen.py \
  --mean \
  -i cox1.sub-PS50.bpnd.fsaverage.lh.nii.gz \
     cox1.sub-PS51.bpnd.fsaverage.lh.nii.gz \
     cox1.sub-PS52.bpnd.fsaverage.lh.nii.gz \
     cox1.sub-PS53.bpnd.fsaverage.lh.nii.gz \
     cox1.sub-PS54.bpnd.fsaverage.lh.nii.gz \
     cox1.sub-PS55.bpnd.fsaverage.lh.nii.gz \
     cox1.sub-PS56.bpnd.fsaverage.lh.nii.gz \
  -o cox1.miba.bpnd.fsaverage.lh.nii.gz
```

## 8) Generate figures

### Figures of the average across the first session of all subjects

```
freeview \
  --volume \
    ${FREESURFER_HOME}/subjects/fsaverage/mri/orig.mgz \
    cox1.vt.fsaverage.nii.gz:colormap=heat:opacity=0.5:heatscale=1.8,2.3,2.8:heatscale_options=truncate \
  --ras 0 -10 0 \
  --cc \
  --viewport axial \
  --colorscale \
  --screenshot ./cox1.miba.vt.axial.mean.png 2 true
```

```
freeview \
  --volume \
    ${FREESURFER_HOME}/subjects/fsaverage/mri/orig.mgz \
    cox1.vt.fsaverage.nii.gz:colormap=heat:opacity=0.5:heatscale=1.8,2.3,2.8:heatscale_options=truncate \
  --ras 0 -10 0 \
  --cc \
  --viewport sagittal \
  --colorscale \
  --screenshot ./cox1.miba.vt.sagittal.mean.png 2 true
```

```
freeview \
  --surface \
    ${FREESURFER_HOME}/subjects/fsaverage/surf/lh.white:overlay=cox1.vt.fsaverage.lh.nii.gz:overlay_threshold=1.80,2.80:overlay_color=heat,truncate:annot=${FREESURFER_HOME}/subjects/fsaverage/label/lh.aparc.annot:annot_outline=1 \
  --viewport 3d \
  --colorscale \
  --screenshot ./cox1.miba.vt.lh.mean.white.png 2 true
```

```
freeview \
  --surface \
    ${FREESURFER_HOME}/subjects/fsaverage/surf/lh.inflated:overlay=cox1.vt.fsaverage.lh.nii.gz:overlay_threshold=1.80,2.80:overlay_color=heat,truncate:annot=${FREESURFER_HOME}/subjects/fsaverage/label/lh.aparc.annot:annot_outline=1 \
  --viewport 3d \
  --colorscale \
  --screenshot ./cox1.miba.vt.lh.mean.inflated.png 2 true
```

### Figures of the average Vs across unblocked/blocked subjects

```
freeview \
  --volume \
    ${FREESURFER_HOME}/subjects/fsaverage/mri/orig.mgz \
    cox1.miba.vnd.fsaverage.nii.gz:colormap=heat:opacity=0.5:heatscale=0.0,1.9,3.8:heatscale_options=truncate \
  --ras 0 -10 0 \
  --cc \
  --viewport axial \
  --colorscale \
  --screenshot ./cox1.miba.vs.axial.meanpng 2 true
```

```
freeview \
  --volume \
    ${FREESURFER_HOME}/subjects/fsaverage/mri/orig.mgz \
    cox1.miba.vnd.fsaverage.nii.gz:colormap=heat:opacity=0.5:heatscale=0.0,1.9,3.8:heatscale_options=truncate \
  --ras 0 -10 0 \
  --cc \
  --viewport sagittal \
  --colorscale \
  --screenshot ./cox1.miba.vs.sagittal.mean.png 2 true
```

```
freeview \
  --surface \
    ${FREESURFER_HOME}/subjects/fsaverage/surf/lh.white:overlay=cox1.miba.vnd.fsaverage.lh.nii.gz:overlay_threshold=0.00,2.80:overlay_color=heat,truncate:annot=${FREESURFER_HOME}/subjects/fsaverage/label/lh.aparc.annot:annot_outline=1 \
  --viewport 3d \
  --colorscale \
  --screenshot ./cox1.miba.vs.lh.white.png 2 true
```

```
freeview \
  --surface \
    ${FREESURFER_HOME}/subjects/fsaverage/surf/lh.inflated:overlay=cox1.miba.vnd.fsaverage.lh.nii.gz:overlay_threshold=0.00,2.80:overlay_color=heat,truncate:annot=${FREESURFER_HOME}/subjects/fsaverage/label/lh.aparc.annot:annot_outline=1 \
  --viewport 3d \
  --colorscale \
  --screenshot ./cox1.miba.vs.lh.inflated.png 2 true
```

### Figures of the average BPND across unblocked/blocked subjects

```
freeview \
  --volume \
    ${FREESURFER_HOME}/subjects/fsaverage/mri/orig.mgz:grayscale=30,150 \
    cox1.miba.bpnd.fsaverage.nii.gz:colormap=nih:colorscale=0.0,4.0 \
  --ras 0 -10 0 \
  --cc \
  --viewport axial \
  --colorscale \
  --screenshot ./cox1.miba.bpnd.axial.mean.png 2 true
```

```
freeview \
  --volume \
    ${FREESURFER_HOME}/subjects/fsaverage/mri/orig.mgz:grayscale=30,150 \
    cox1.miba.vnd.fsaverage.nii.gz:colormap=heat:opacity=0.5:heatscale=0.0,1.3,2.6:heatscale_options=truncate \
  --ras 0 -10 0 \
  --cc \
  --viewport sagittal \
  --colorscale \
  --screenshot ./cox1.miba.bpnd.sagittal.mean.png 2 true
```

```
freeview \
  --surface \
    ${FREESURFER_HOME}/subjects/fsaverage/surf/lh.white:overlay=cox1.miba.bpnd.fsaverage.lh.nii.gz:overlay_threshold=0.50,1.50:overlay_color=heat,truncate:annot=${FREESURFER_HOME}/subjects/fsaverage/label/lh.aparc.annot:annot_outline=1 \
  --viewport 3d \
  --colorscale \
  --screenshot ./cox1.miba.bpnd.lh.white.png 2 true
```

```
freeview \
  --surface \
    ${FREESURFER_HOME}/subjects/fsaverage/surf/lh.inflated:overlay=cox1.miba.bpnd.fsaverage.lh.nii.gz:overlay_threshold=0.50,1.50:overlay_color=heat,truncate:annot=${FREESURFER_HOME}/subjects/fsaverage/label/lh.aparc.annot:annot_outline=1 \
  --viewport 3d \
  --colorscale \
  --screenshot ./cox1.miba.bpnd.lh.inflated.png 2 true
```

## References

- OHBM 2023 abstract: https://ww6.aievolution.com/hbm2301/index.cfm?do=abs.viewAbs&abs=2785
- PetSurfer: https://surfer.nmr.mgh.harvard.edu/fswiki/PetSurfer
- Bloodstream walkthrough: https://www.youtube.com/watch?v=Kud6MWYPKxg
- Logan method: https://www.pmod.com/files/download/v31/doc/pkin/2329.htm

