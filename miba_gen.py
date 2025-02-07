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
    op.add_argument('--mean', action='store_const', dest='op', const='mean', default='mean',
                    help='Take the mean of the files in --in-files (default)')
    op.add_argument('--std', action='store_const', dest='op', const='std',
                    help='Take the standard deviation of the files in --in-files')    
    op.add_argument('--diff', action='store_const', dest='op', const='diff',
                    help='Take the difference (all files after the first in --in-files is subtracted from the first)')
    op.add_argument('--diff-const', action='store_const', dest='op', const='diff-const',
                    help='The value in --const-val is subtracted from the first file in --in-files (other in-files are ignored)')
    op.add_argument('--div-const', action='store_const', dest='op', const='div-const',
                    help='The first file in --in-files is divided by the value in --const-val (other in-files are ignored)')
    parser.add_argument('-cv', '--const-val', default=None, type=float, help='Value for --diff-const or --div-const')
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

def std(in_files, out_file):
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

    cumulative_data = None
    for file in in_files:
        print("loading", file)
        vol = nb.load(file)
        if cumulative_data is None:
            cumulative_data = (np.array(vol.dataobj) - mean_data)**2
        else:
            cumulative_data = cumulative_data + (np.array(vol.dataobj) - mean_data)**2
    std_data = np.sqrt(cumulative_data / num_files)
    
    std_vol = nb.nifti1.Nifti1Image(std_data, None, header=vol.header.copy())
    
    print("writing", out_file)
    nb.save(std_vol, out_file)

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

def diff_const(in_files, out_file, const_val):
    num_files = len(in_files)
    if num_files > 1:
        print('More than one input file specified; all but the first will be ignored')
    if out_file is None:
        out_file="out.nii.gz"
        
    print("num_files: ", num_files)
    print("out_file:  ", out_file)
    print("const_val: ", const_val)
    
    vol = nb.load(in_files[0])
    diff_data = np.array(vol.dataobj) - const_val
    
    diff_vol = nb.nifti1.Nifti1Image(diff_data, None, header=vol.header.copy())       
    
    print("writing", out_file)
    nb.save(diff_vol, out_file)

def div_const(in_files, out_file, const_val):
    num_files = len(in_files)
    if num_files > 1:
        print('More than one input file specified; all but the first will be ignored')
    if out_file is None:
        out_file="out.nii.gz"
        
    print("num_files: ", num_files)
    print("out_file:  ", out_file)
    print("const_val: ", const_val)
    
    vol = nb.load(in_files[0])
    div_data = np.array(vol.dataobj) / const_val
    
    div_vol = nb.nifti1.Nifti1Image(div_data, None, header=vol.header.copy())       
    
    print("writing", out_file)
    nb.save(div_vol, out_file)
                    
def main():
    args = parse_args()
    
    if (args.op=='mean'):
        mean(args.in_files, args.out_file)
    if (args.op=='std'):
        std(args.in_files, args.out_file)        
    elif (args.op=='diff'):
        diff(args.in_files, args.out_file)
    elif (args.op=='diff-const'):
        diff_const(args.in_files, args.out_file, args.const_val)
    elif (args.op=='div-const'):
        div_const(args.in_files, args.out_file, args.const_val)
    
    return 0

if __name__ == "__main__":
    sys.exit(main())

