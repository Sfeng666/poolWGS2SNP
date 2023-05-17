#!/bin/bash

## 1. receive arguments from 03sort.sub
sequencing_run=$1
outdir_staging=$2
conda_pack_squid=$3
genome_seq_squid=$4
job_parent=$5
job=$6

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
parent_tarball=$outdir_staging/$job_parent\.tar.gz
out_tarball=$outdir_staging/$job\.tar.gz

# 3.2 local paths at working directory
# for step1 (5.1)
out_bam=$sequencing_run.bam

out_sort_bam=$sequencing_run\_sort.bam
sort_log=sortsam_log
TMP_DIR=./

# for step2 (5.2)
genome_seq_tarball=$(basename $genome_seq_squid)
genome_seq=$(basename $genome_seq_squid .tar.gz)
out_alignment_metrics=$sequencing_run\_alignment_metrics.txt
alignment_metrics_log=alignment_metrics_log

# 4. untar input tarballs
# 4.1. untar the aligned bam files from the previous step as input for sort alignment
tar -xzf $parent_tarball -C ./ $out_bam

# 4.2. untar the genomic sequence tarball
tar -xzf $genome_seq_tarball -C ./
rm $genome_seq_tarball

## 5. run steps of the pipeline
## 5.1. sort BAM by reference position using Picard SortSam
picard \
SortSam \
I=$out_bam \
O=$out_sort_bam \
TMP_DIR=$TMP_DIR \
SORT_ORDER=coordinate \
VALIDATION_STRINGENCY=SILENT \
CREATE_INDEX=true \
> $sort_log 2>&1
#-Dsnappy.loader.verbosity=true //used to test if Snappy has been found by Picard

## 5.2. Alignment Metrics (It may also be useful to calculate metrics on the aligned sequences)
picard \
CollectAlignmentSummaryMetrics \
I=$out_sort_bam \
R=$genome_seq \
METRIC_ACCUMULATION_LEVEL=SAMPLE \
METRIC_ACCUMULATION_LEVEL=READ_GROUP \
O=$out_alignment_metrics \
> $alignment_metrics_log 2>&1

## 6. Handling output
# # 6.1. make sure to remove software packages from the working directory
# rm -r biosoft
# rm -r $ENVNAME

# 6.2. tar and move large output files to staging so they're not copied to the submit server
tar -czvf $out_tarball \
$out_sort_bam $sort_log \
$out_alignment_metrics $alignment_metrics_log 

# For log files (could be redirected stdout/stderr) that you want to check under home directory, 
# do not remove them at working directory, so that HTCondor will transfer them back to your home directory.
shopt -s extglob
rm -rf !($sort_log|$out_alignment_metrics|$alignment_metrics_log)
shopt -u extglob