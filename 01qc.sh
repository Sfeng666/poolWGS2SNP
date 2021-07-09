#!/bin/bash

## 1. receive arguments from 01qc.sub
sequencing_run=$1
read1=$2
read2=$3
outdir_staging=$4
indir_staging=$5
job=$6
conda_pack_squid=$7

## 2. configure the conda enviroment
set -e

workdir_pac=$(basename $conda_pack_squid)
ENVNAME=$(basename $conda_pack_squid .tar.gz)
ENVDIR=$ENVNAME

# these lines handle setting up the environment; you shouldn't have to modify them
export PATH
mkdir $ENVDIR
tar -xzf $workdir_pac -C $ENVDIR
. $ENVDIR/bin/activate
rm $workdir_pac

## 3. set paths
# 3.1 remote paths at /staging/
in_tarball=$indir_staging/$job\.tar.gz
out_tarball=$outdir_staging/$job\.tar.gz

# 3.2 local paths at working directory
# for step1 (5.1)
in_tarball_wd=$job.tar.gz
in1=$(echo $read1|cut -f 2- -d"/")
in2=$(echo $read2|cut -f 2- -d"/")

out_tarball_wd=$job\.tar.gz
out1=trimmed_$sequencing_run\_1.fastq.gz
out2=trimmed_$sequencing_run\_2.fastq.gz
unpaired1=passed_$sequencing_run\_1.fastq.gz
unpaired2=passed_$sequencing_run\_2.fastq.gz
failed_out=failout_$sequencing_run.fastq.gz
fastp_log=fastp_log
json=fastp.json
html=fastp.html

t_fastp=16

# for step2 (5.2)
path_script=biosoft/myscripts/filter_PE_length_mem.py
out_filtered1=filtered_$out1
out_filtered2=filtered_$out2
filter_report=filter_report

## 4. copy large input files from staging
# copy the compressed tar file from /staging into the working directory,
# and un-tar it to reveal the large input file 
cp $in_tarball $in_tarball_wd
tar -xzvf $in_tarball_wd

# !!note: delete the compressed tar file from/at /staging once it is un-tarred, to reveal disk space
# also remove files that's no longer needded by subsequent steps
rm $in_tarball_wd
# rm $in_tarball

## 5. run steps of the pipeline
# 5.1. run fastp without no filtering
fastp \
--disable_length_filtering \
--disable_quality_filtering \
--cut_right --cut_right_window_size 4 --cut_right_mean_quality 20 \
--correction \
--in1 $in1 \
--in2 $in2 \
--out1 $out1 \
--out2 $out2 \
--unpaired1 $unpaired1 \
--unpaired2 $unpaired2 \
--failed_out $failed_out \
--json $json \
--html $html \
--thread $t_fastp \
> $fastp_log 2>&1
# --reads_to_process 1000000 \  # line for test

rm $in1 $in2

# 5.2. run filter_PE_length_mem.py for filtering
python $path_script \
--in1 $out1 \
--in2 $out2 \
--out1 $out_filtered1 \
--out2 $out_filtered2 \
--report $filter_report

## 6. Handling output
# # 6.1. make sure to remove software packages from the working directory
# rm -r biosoft
# rm -r $ENVNAME

# 6.2. tar and move large output files to staging so they're not copied to the submit server
tar -czvf $out_tarball_wd \
$out1 $out2 $unpaired1 $unpaired2 $failed_out $fastp_log $json $html \
$out_filtered1 $out_filtered2 $filter_report

mv $out_tarball_wd $out_tarball

# For log files (could be redirected stdout/stderr) that you want to check under home directory, 
# do not remove them at working directory, so that HTCondor will transfer them back to your home directory.
shopt -s extglob
rm -rf !($fastp_log|$filter_report)
shopt -u extglob