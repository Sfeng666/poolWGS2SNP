#!/bin/bash

## 1. receive arguments from 04rmdup.sub
sample=$1
outdir_staging=$2
conda_pack_squid=$3
job=$4

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
out_tarball=$outdir_staging/$job\.tar.gz

# 3.2 local paths at working directory
# for step1 (5.1)
sort_merge_dedup_bam=$sample\_sort_merge_dedup.bam
sort_merge_dedup_bam_index=$sample\_sort_merge_dedup.bai
dedup_metrics=$sample\_dedup_metrics.txt
dedup_log=dedup_log
TMP_DIR=./

# 4. untar sorted alignments from sequencing run(s) as single/multiple input for mark/remove duplicate
# note that the number of sequencing runs of samples could differ from one another, so we choose to print the executable specific to each sample.
# parent_tarball=$outdir_staging/$job_parent\.tar.gz
# sort_bam=$sequencing_run\_sort.bam
tar -xzf $parent_tarball -C ./ $sort_bam

## 5. run steps of the pipeline
## 5. remove PCR duplicates using Picard MarkDuplicates (while merge sequencing runs of a sample into one bam file, if there're multiple sequencing runs )
picard \
MarkDuplicates \
REMOVE_DUPLICATES=true \
I=$sort_bam1 \
I=$sort_bam2 \
O=$sort_merge_dedup_bam \
M=$dedup_metrics \
TMP_DIR=$TMP_DIR \
VALIDATION_STRINGENCY=SILENT \
CREATE_INDEX=true \
> $dedup_log 2>&1

## 6. Handling output
# 6.1. tar and move large output files to staging so they're not copied to the submit server
tar -czvf $out_tarball \
$sort_merge_dedup_bam $sort_merge_dedup_bam_index $dedup_metrics $dedup_log

# 6.2. For log files (could be redirected stdout/stderr) that you want to check under home directory, 
# do not remove them at working directory, so that HTCondor will transfer them back to your home directory.
shopt -s extglob
rm -rf !($dedup_log|$dedup_metrics)
shopt -u extglob