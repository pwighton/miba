## 1) Run `petprep_hmc`

See: https://github.com/mnoergaard/petprep_hmc

Fetch singularity container:
```
singularity pull docker://dockerhub.com/martinnoergaard/petprep_hmc:0.0.8
```

Run:
```
singularity run \
    -B /autofs/vast/gerenuk/pwighton/pet/ds004869/ds004869-download:/data/input \
    -B /autofs/vast/gerenuk/pwighton/pet/ds004869/petprep-output:/data/output \
    -B /autofs/vast/freesurfer/centos7_x86_64/dev/.license:/opt/freesurfer/license.txt \
    /autofs/vast/gerenuk/pwighton/pet/petprep_hmc_0.0.8.sif \
      --bids_dir /data/input \
      --output_dir /data/output \
      --analysis_level participant
```

## 2) Run `FreeSurfer`

- Runing the dev version (as of 2024/09/23).
- Copy `cox2/global-expert-options.txt` to the freesurfer subject's directory first
- Using `cox2/mlsc-recon-all.bash` to run on mlsc cluster
  - Which reads from `cox2/recon-all-sub-list.txt`

