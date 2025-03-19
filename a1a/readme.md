Data that was provided included
  - Subject's anatomical MRI data (t1-weighted mprages)
  - Subject's average Vt values (PET data)
  
Processing steps:

1) the provided mprages were unwarped to account for gradient non-linearities (see `unwarp-mprage.bash`) Note the gradient file `coeff_AS097.grad` cannot be shared because it is considered to contain confidential Seimens information 

2) Both the unwarped mprages and the original mprages we run through recon-all (see `mlsc-recon-all.bash`)

3) `bbregister` was used to register the subjects average Vt (PET) data to both the original and unwarped mprage data (see `bbregister-orig.bash`, `bbregister-unwarped.bash`.  The unwarped data had lower registration costs.  This confirmed that `coeff_AS097.grad` was the proper gradient coefficient set to use.  The unwarped mprage data was used going forward.

4) `register-unwarped.bash` was used to register the pet data to
- fsaverage space, which was used to project the pet data onto FreeSurfer's surfaes
- mni152 1.0mm space
- mni152 1.5mm space
- mni152 2.0mm space

5) `miba_gen.py` was used to aggregate data aross subjects

6) `asegstats2table` was used to aggregate the `a1a.vt.fsaverage.segstats.txt` files.

`--no-segno` is excluding:
  - 0: unknown
  - 77: WM-hypointensities

```
asegstats2table \
  --meas mean \
  --tablefile a1a.vt.segstats.txt \
  --common-segs \
  --no-segno 0 77 \
  --inputs \
    ./105_006/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_009/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_014/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_036/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_041/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_043/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_053/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_081/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_089/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_096/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_111/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_119/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_131/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_137/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_139/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_149/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_151/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_152/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_155/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_172/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_173/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_195/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_196/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_199/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_212/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_217/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_225/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_253/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_263/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_265/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_269/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_288/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_319/pet/a1a.vt.fsaverage.segstats.txt \
    ./105_320/pet/a1a.vt.fsaverage.segstats.txt
```

7) `collate-asegstats2table.py` is used to collate `a1a.vt.fsaverage.segstats.txt` and create `a1a.vt.fsaverage.rois.tsv`

8) Filenames were renamed to be 'BIDS-like'.  Note the BIDS atlas specificaiton is a work-in-progress, so this might change in the future.  The [PS13 miba](https://openneuro.org/datasets/ds004401/versions/1.3.0) was used as an example

- `a1a.miba.vt.mean.fsaverage.lh.nii.gz` --> `atlas-a1a_hemi-L_space-fsaverage_stat-mean_mimap.nii.gz`
- `a1a.miba.vt.mean.fsaverage.rh.nii.gz` --> `atlas-a1a_hemi-R_space-fsaverage_stat-mean_mimap.nii.gz`
- `a1a.miba.vt.std.fsaverage.lh.nii.gz` --> `atlas-a1a_hemi-L_space-fsaverage_stat-std_mimap.nii.gz`
- `a1a.miba.vt.std.fsaverage.rh.nii.gz` --> `atlas-a1a_hemi-R_space-fsaverage_stat-std_mimap.nii.gz`
- `a1a.miba.vt.mean.mni152-1.0mm.nii.gz` --> `atlas-a1a_res-1_space-mni152_stat-mean_mimap.nii.gz`
- `a1a.miba.vt.mean.mni152-1.5mm.nii.gz` --> `atlas-a1a_res-1p5_space-mni152_stat-mean_mimap.nii.gz`
- `a1a.miba.vt.mean.mni152-2.0mm.nii.gz` --> `atlas-a1a_res-2_space-mni152_stat-mean_mimap.nii.gz`
- `a1a.miba.vt.std.mni152-1.0mm.nii.gz` --> `atlas-a1a_res-1_space-mni152_stat-std_mimap.nii.gz`
- `a1a.miba.vt.std.mni152-1.5mm.nii.gz` --> `atlas-a1a_res-1p5_space-mni152_stat-std_mimap.nii.gz`
- `a1a.miba.vt.std.mni152-2.0mm.nii.gz` --> `atlas-a1a_res-2_space-mni152_stat-std_mimap.nii.gz`
- `a1a.vt.fsaverage.rois.tsv` --> `atlas-a1a_dseg.tsv`
