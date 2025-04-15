#!/usr/bin/env python3

import pandas as pd
import argparse

parser = argparse.ArgumentParser(description='Computes the mean and standard devation for column of the output from `asegstats2table`')

parser.add_argument('infile', help='Input file (ouput from `asegstats2table`)')
parser.add_argument('outfile', help='Output file')

args = parser.parse_args()

df_in = pd.read_csv(args.infile, sep='\t')

means = df_in.mean(numeric_only=True)
stds = df_in.std(numeric_only=True)

df_out = pd.DataFrame({
    'ROI': means.index,
    'Mean': means.values,
    'StdDev': stds.values
})

# Remove rows where ROI equals 'Measure:*'
df_out = df_out[~df_out['ROI'].str.startswith('Measure:')]

df_out.to_csv(args.outfile, sep='\t', index=False, encoding='utf-8')

