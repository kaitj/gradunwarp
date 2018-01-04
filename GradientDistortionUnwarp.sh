#!/bin/bash

# Requirements for this script
#  installed versions of FSL (version 5.0.6+) and modified HCP-gradunwarp (version 1.0.2)
#  modified to account for spacing in gradient coefficients file of RRI 7T scanner

if [ "$#" -lt 4 ]
then
 echo "Usage $0 <input image> <output image> <grad coefficient file> <output warp>"
 exit 0
fi 

infile=$1
outfile=$2
coeffs=$3
owarp=$4

echo " " >> log.txt
echo " START: GradientDistortionUnwarp" >> log.txt
echo " " >> log.txt

# Record input options into log file
echo "$0 $@" >> log.txt
echo "PWD = `pwd`" >> log.txt
echo "date: `date`" >> log.txt
echo " " >> log.txt

BaseName=`remove_ext ${infile}`

OutputWarpName=`remove_ext ${owarp}` 

############### PERFORM GRADIENT DISTORTION CORRECTION ###############
# Accounts for 4D images by extracting first volume (all others will follow suit as scanner coordinate system is unchanged, even with subjection motion)

fslroi ${infile} ${BaseName}_vol1.nii.gz 0 1

echo "gradient_unwarp.py ${BaseName}_vol1.nii.gz trilinear.nii.gz siemens -g ${coeffs} -n" >> log.txt 
gradient_unwarp.py ${BaseName}_vol1.nii.gz trilinear.nii.gz siemens -g ${coeffs} -n

# Create appropriate warpfield output and apply it for all time of 4D image
convertwarp --abs --ref=trilinear.nii.gz --warp1=fullWarp_abs.nii.gz --relout --out=$owarp --jacobian=${OutputWarpName}_jacobian
fslmaths ${OutputWarpName}_jacobian -Tmean ${OutputWarpName}_jacobian
applywarp --rel --interp=spline -i $infile -r ${BaseName}_vol1.nii.gz -w $owarp -o $outfile

echo " " >> log.txt
echo " END: GradientDistortionUnwarp " >> log.txt
echo " `date`" >> log.txt

############### GENERATE GRADIENT PERCENT DEVATION MAP ###############
echo " "
echo " START: Compute gradient percent deviation map " >> log.txt
echo " `date` " >> log.txt

# Calculates individual gradient field deviations at each voxel
# Accompanies HCP diffusion data to correct for gradient nonlinearities
calc_grad_perc_dev --fullwarp=fullWarp_abs -o grad_dev
fslmerge -t grad_dev grad_dev_x grad_dev_y grad_dev_z
fslmaths grad_dev -div 100 grad_dev
imrm grad_dev_?
imrm trilinear
imrm ${BaseName}_vol1

echo " " >> log.txt
echo " END: Compute gradient percent deviation map " >> log.txt
echo " `date`" >> log.txt
