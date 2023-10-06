#!/usr/bin/env python3

import sys
import numpy as np
import scipy as sp
import argparse
import json
import pandas

def parse_args():
    parser = argparse.ArgumentParser(description='Integrate AIF over the PET frames')
    parser.add_argument('-a', '--aif', help='Arterial input function data, currently expects output of bloodstream', required=True)
    parser.add_argument('-b', '--bids', help='BIDS sidecar file to PET data; expecting to find FrameTimesStart and FrameDuration', required=True)
    parser.add_argument('-o', '--out', help='Filename to write test results to, one per line', default='aif.bloodstream.dat')
    parser.add_argument('-tc', '--time-col', help='The name of the time column in the tsv (default="time")',
                        default='time')
    parser.add_argument('-ac', '--aif-col', help='Then name of the aif column in the tsv (deafult="AIF")',
                        default='AIF')
    return parser.parse_args()

def main(cmd_args):
    args = parse_args()

    # Read BIDS json sidecar
    with open(args.bids) as bids_sidecar_file:
      bids_sidecar_filedata = bids_sidecar_file.read()
    bids_sidecar = json.loads(bids_sidecar_filedata)

    # Read bloodstream output
    blood_data_df = pandas.read_csv(args.aif, delimiter='\t')
    blood_aif = blood_data_df[[args.aif_col]].to_numpy().squeeze()
    blood_time = blood_data_df[[args.time_col]].to_numpy().squeeze()

    # Calc Frame start and end times
    frame_start_times = np.asarray(bids_sidecar["FrameTimesStart"], dtype=np.float32).squeeze()
    frame_durations = np.asarray(bids_sidecar["FrameDuration"], dtype=np.float32).squeeze()
    frame_end_times = frame_start_times + frame_durations

    # Take the cum int and eval (via linear interpolation) at start and end times
    blood_aif_cumulative = sp.integrate.cumulative_trapezoid(blood_aif, x=blood_time, initial=0)
    blood_aif_cumulative_at_start_times = np.interp(frame_start_times, blood_time, blood_aif_cumulative)
    blood_aif_cumulative_at_end_times = np.interp(frame_end_times, blood_time, blood_aif_cumulative)

    # The integral over the PET timefreame is the difference
    blood_aif_cumulative_by_frame = blood_aif_cumulative_at_end_times - blood_aif_cumulative_at_start_times

    # Save to file
    np.savetxt(args.out, blood_aif_cumulative_by_frame, newline="\n")
	
if __name__ == "__main__":
    sys.exit(main(sys.argv))
