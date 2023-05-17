#!/bin/bash

# 1. receive essential arguments from dag input
read1=$1
read2=$2
indir_staging=$3
outdir_home=$4
job=$5

# 2. set paths
outdir_condor=$outdir_home/$job
in_tarball=$indir_staging/$job\.tar.gz

# 3. mkdir for receiving output (log files) from HTCondor at home directories
mkdir -p $outdir_condor

# 4. prepare tarball for input files of the job
# !! be aware that when you tar a directory with absolute path, the absolute path will be turned into a relative path (by remove the first '/') 
# , and the directory structure will be added to the tarball. If possible, one should cd into the directory that contains all involved file (not always this case), and then tar them. 
if [ ! -f "$in_tarball" ];then
    tar -czvf $in_tarball $read1 $read2
fi