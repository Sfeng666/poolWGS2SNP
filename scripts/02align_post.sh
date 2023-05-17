#!/bin/bash

# 0. activate the conda environment under /home/sfeng77 to run samtools
source /home/sfeng77/anaconda3/bin/activate WGS_analysis

# 1. receive essential arguments from dag input
sequencing_run=$1
outdir_staging=$2
outdir_home=$3
indir_home=$4
job=$5

# 2. set paths
outdir_condor=$outdir_home/$job
indir_condor=$indir_home/$job
merged_bam=$outdir_condor/$sequencing_run.bam
split_bam=$outdir_condor/*.bam
split_log=$outdir_condor/*.bwa_log
outdir_staging_tarball=$outdir_staging/$job\.tar.gz

# 3. merge split bam outputs into one
samtools merge -c $merged_bam $split_bam

# 4. tar the merged bam file and log files of bwa, and move the tarred file to /staging
cd $outdir_condor
merged_bam_wd=$(basename $merged_bam)
tar -czf $outdir_staging_tarball $merged_bam_wd *.bwa_log
rm $split_bam $split_log $merged_bam
rm -r $indir_condor