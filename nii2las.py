#!/usr/bin/env python3

import nibabel as nb
import argparse

script_desc = 'Converts nifti files to LAS. Written so that files from https://www.meduniwien.ac.at/neuroimaging/mRNA.html can be used with mri_vol2vol'
parser = argparse.ArgumentParser(description=script_desc)

parser.add_argument('infile', help='Input file')
parser.add_argument('outfile', help='Output file')

args = parser.parse_args()

input_img = nb.load(args.infile)

header = input_img.header.copy()

orig_orientation = nb.aff2axcodes(input_img.affine)
print(f"Original orientation: {orig_orientation}")

orig_affine = input_img.affine.copy()
orig_orientation = nb.aff2axcodes(orig_affine)

target_orientation = 'LAS'
transformation = nb.orientations.ornt_transform(
    nb.orientations.axcodes2ornt(orig_orientation),
    nb.orientations.axcodes2ornt(target_orientation),
)

# Apply the reorientation
reoriented_img = input_img.as_reoriented(transformation)

nb.save(reoriented_img, args.outfile)
