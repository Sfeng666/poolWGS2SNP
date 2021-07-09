#!/bin/bash

# 1. receive essential arguments from dag input
outdir_home=$1
indir_staging=$2
job=$3

# 2. set paths
outdir_condor=$outdir_home/$job
in_tarball=$indir_staging/all_samples_bam.tar.gz

# 3. mkdir for receiving output (log files) from HTCondor at home directories
mkdir -p $outdir_condor

# 4. tar bam files of all samples into a tarball
cd $indir_staging
if [ ! -f "$in_tarball" ];then
    tar czvf $in_tarball *_sort_merge_dedup_indel.bam bam_list.txt
fi