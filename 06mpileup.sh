#!/bin/bash

## 1. receive arguments from 06mpileup.sub
outdir_staging=$1
indir_staging=$2
conda_pack_squid=$3
genome_seq_squid=$4
job=$5

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
in_tarball=$indir_staging/all_samples_bam.tar.gz
out_tarball=$outdir_staging/$job\.tar.gz

# 3.2 local paths at working directory
genome_seq_tarball=$(basename $genome_seq_squid)
genome_seq=$(basename $genome_seq_squid .tar.gz)
bam_list=bam_list.txt
out_mpileup=mpileup.gz
mpileup_filter_log=mpileup_filter_log

# 4. untar input tarballs
# 4.1. untar the aligned bam files from the last step, as input of sorting alignment
tar -xzf $in_tarball -C ./ 

# 4.2. untar the genomic sequence tarball
tar -xzf $genome_seq_tarball -C ./
rm $genome_seq_tarball

## 5. run steps of the pipeline

## merge BAM files (in the order of the file paths in bam_list.txt) in a MPILEUP file only retaining nucleotides with BQ >20 and reads with MQ > 20
samtools \
mpileup -B \
-f $genome_seq \
-b $bam_list \
-q 20 \
-Q 20 \
2> $mpileup_filter_log \
| gzip > $out_mpileup

## 6. Handling output
# # 6.1. make sure to remove software packages from the working directory
# rm -r biosoft
# rm -r $ENVNAME

# 6.2. tar and move large output files to staging so they're not copied to the submit server
tar -czvf $out_tarball $out_mpileup $mpileup_filter_log 

# For log files (could be redirected stdout/stderr) that you want to check under home directory, 
# do not remove them at working directory, so that HTCondor will transfer them back to your home directory.
shopt -s extglob
rm -rf !($mpileup_filter_log)
shopt -u extglob