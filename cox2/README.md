## 1) Run `petprep_hmc`

Fetch singularity container:
```
singularity pull docker://dockerhub.com/martinnoergaard/petprep_hmc:0.0.8
```

## 2) Run `FreeSurfer`

- Runing the dev version (as of 2024/09/23).
- Copy `cox2/global-expert-options.txt` to the freesurfer subject's directory first
- Using `cox2/mlsc-recon-all.bash` to run on mlsc cluster
  - Which reads from `cox2/recon-all-sub-list.txt`
