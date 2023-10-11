#!/usr/bin/env python3

import sys
import argparse
import nibabel as nb
import numpy as np

def parse_args():
    parser = argparse.ArgumentParser(description='Generate a MIBA by averaging over DVRs')
    parser.add_argument('-i', '--in-files', nargs='+', help='The list of files to average over', required=True)
    parser.add_argument('-o', '--out-file', default=None, help='The output file')
    op = parser.add_mutually_exclusive_group()
    op.add_argument('--mean', action='store_const', dest='op', const='mean', default='mean', help='Take the mean of the files in --in-files (default)')
    op.add_argument('--diff', action='store_const', dest='op', const='diff', help='Take the difference (all files after the first in --in-files is subtracted from the first)')

    return parser.parse_args()

def mean(in_files, out_file):
    num_files = len(in_files)
    if out_file is None:
        out_file="out.nii.gz"
        
    print("num_files: ", num_files)
    print("out_file:  ", out_file)
    
    cumulative_data = None
    for file in in_files:
        print("loading", file)
        vol = nb.load(file)
        if cumulative_data is None:
            cumulative_data = np.array(vol.dataobj)
        else:
            cumulative_data = cumulative_data + np.array(vol.dataobj)

    mean_data = cumulative_data / num_files
    mean_vol = nb.nifti1.Nifti1Image(mean_data, None, header=vol.header.copy())       
    
    print("writing", out_file)
    nb.save(mean_vol, out_file)

def diff(in_files, out_file):
    num_files = len(in_files)
    if out_file is None:
        out_file="out.nii.gz"
        
    print("num_files: ", num_files)
    print("out_file:  ", out_file)
    
    cumulative_data = None
    for file in in_files:
        print("loading", file)
        vol = nb.load(file)
        if cumulative_data is None:
            cumulative_data = np.array(vol.dataobj)
        else:
            cumulative_data = cumulative_data - np.array(vol.dataobj)

    diff_vol = nb.nifti1.Nifti1Image(cumulative_data, None, header=vol.header.copy())       
    
    print("writing", out_file)
    nb.save(diff_vol, out_file)
            
def main():
    args = parse_args()
    
    if (args.op=='mean'):
        mean(args.in_files, args.out_file)
    elif (args.op=='diff'):
        diff(args.in_files, args.out_file)
        
    return 0

if __name__ == "__main__":
    sys.exit(main())

