#!/usr/bin/env python3

import nibabel as nb
import numpy as np
import json
import matplotlib.pyplot as plt
import argparse
import sys

#be_verbose = True
be_verbose = False

label_datapoints = True
#label_datapoints = False

def parse_args():
    parser = argparse.ArgumentParser(description='Do something')
    parser.add_argument('-m', '--merge', help='json file describing how FreeSurfer labels should be merged (see occupancy-merge.json)', required=True)
    parser.add_argument('--seg-base', help='baseline segmentation file', required=True)
    parser.add_argument('--dvr-base', help='baseline dvr file', required=True)
    parser.add_argument('--seg-block', help='blocked segmentation file', required=True)
    parser.add_argument('--dvr-block', help='blocked dvr file', required=True)
    parser.add_argument('-o', '--output', help='output json file', default='output.json')
    parser.add_argument('-ofig', '--output-fig', help='output png file', default=None)
    return parser.parse_args()

def calc_Vnd(args):
    # There should be sanity checks here ensuring seg_baseline/dvr_baseline and 
    # seg_blocked/dvr_blocked are voxelwise comparable
    seg_baseline = nb.load(args.seg_base)
    dvr_baseline = nb.load(args.dvr_base)
    seg_blocked = nb.load(args.seg_block)
    dvr_blocked = nb.load(args.dvr_block)
    with open(args.merge) as f:
        merge_data = json.load(f)

    seg_baseline_voxels = nb.casting.float_to_int(seg_baseline.dataobj, np.int16)
    dvr_baseline_voxels = np.array(dvr_baseline.dataobj, dtype=float)
    seg_blocked_voxels = nb.casting.float_to_int(seg_blocked.dataobj, np.int16)
    dvr_blocked_voxels = np.array(dvr_blocked.dataobj, dtype=float)

    baseline_vals = []
    blocked_vals = []
    regions = []

    for region in merge_data['regions']:
        mask_baseline = np.isin(seg_baseline_voxels, merge_data['regions'][region]['labels'])
        mask_blocked = np.isin(seg_blocked_voxels, merge_data['regions'][region]['labels'])
        if be_verbose:
            print(region)
            print(merge_data['regions'][region]['labels'])
            print(np.count_nonzero(mask_baseline))
            print(np.count_nonzero(mask_blocked))
        regions.append(region)
        baseline_vals.append(np.mean(dvr_baseline_voxels[mask_baseline]))
        blocked_vals.append(np.mean(dvr_blocked_voxels[mask_blocked]))
        
    baseline_minus_blocked_vals = (np.array(baseline_vals) - np.array(blocked_vals)).tolist()

    x = baseline_vals
    y = baseline_minus_blocked_vals

    slope, intercept = np.polyfit(x, y, 1)
    p1d = np.poly1d([slope, intercept])
    Vnd = -1 * intercept / slope
    occupancy = slope

    output = {}
    output['regions'] = regions
    output['baseline_vals'] = baseline_vals
    output['blocked_vals'] = blocked_vals
    output['baseline_minus_blocked_vals'] = baseline_minus_blocked_vals
    output['Vnd'] = Vnd
    output['occupancy'] = occupancy
    
    return output

def make_fig(args, output):
    x = output['baseline_vals']
    y = output['baseline_minus_blocked_vals']
    regions = output['regions']
    slope, intercept = np.polyfit(x, y, 1)
    p1d = np.poly1d([slope, intercept])
    x.append(output['Vnd'])
    y.append(0)
    regions.append('Vnd')
    fig = plt.figure(figsize=(8, 8), dpi=150, facecolor='white')
    plt.scatter(x, y)
    plt.ylim(ymin=0)
    plt.xlim(xmin=0)
    plt.xlabel('baseline')
    plt.ylabel('baseline - blocked')
    plt.plot(np.unique(x), p1d(np.unique(x)))
    if label_datapoints: [plt.text(i, j, f'{region}', fontsize=8, ha='right') for (i, j, region) in zip(x, y, regions)]
    plt.savefig(args.output_fig, facecolor=fig.get_facecolor())
    return
    
def main():
    args = parse_args()
    output = calc_Vnd(args)
    with open(args.output, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=4)
    if args.output_fig is not None: make_fig(args, output)

if __name__ == "__main__":
    sys.exit(main())
