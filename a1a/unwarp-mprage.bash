#!/bin/bash

INDIR=/autofs/vast/petsurfer/a1a-elmenhorst/unpacked/mprage
OUTDIR=/autofs/vast/gerenuk/pwighton/pet/a1a/mprage-unwarp
UNWARPDIR=/autofs/vast/freesurfer/unwarp/gradient_nonlin_unwarp
UNWARPFILE=/autofs/vast/freesurfer/unwarp/gradient_nonlin_unwarp/gradient_coil_files/coeff_AS097.grad
UNWARPSCRIPT=/autofs/vast/freesurfer/unwarp/gradient_nonlin_unwarp/gradient_nonlin_unwarp.sh

for INFILE in `find ${INDIR} -name '*.nii.gz'`
do
	BASEFILE=`basename "${INFILE}"`
	OUTFILE=$OUTDIR/$BASEFILE
	env MRIS="${UNWARPDIR}" \
	  ${UNWARPSCRIPT} \
          ${INFILE} \
          ${OUTFILE} \
          ${UNWARPFILE}
done
