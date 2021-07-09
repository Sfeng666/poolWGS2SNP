#!/bin/bash

## 1. receive arguments from 05realign.sub
sample=$1
outdir_staging=$2
indir_staging=$3
conda_pack_squid=$4
genome_seq_squid=$5
job_parent=$6
job=$7

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
genome_seq_tarball=$(basename $genome_seq_squid)
genome_seq=$(basename $genome_seq_squid .tar.gz)
sort_merge_dedup_bam=$sample\_sort_merge_dedup.bam
sort_merge_dedup_bam_index=$sample\_sort_merge_dedup.bai

path_gatk3=$ENVDIR/opt/gatk-3.8/gatk.py
sed -i "s|#!/opt/anaconda1anaconda2anaconda3/bin/python|#!${ENVDIR}/bin/python|" $path_gatk3

# for step1 (5.1)
indel_list=$sample\_sort_merge_dedup_indel.list
indel_list_log=indel_list_log

# for step2 (5.2)
sort_merge_dedup_indel_bam=$sample\_sort_merge_dedup_indel.bam
realign_log=realign_log

# for step 3 (5.3)
out_validate=$sample\_bam_validate.txt
validate_log=validate_log

# for step 4 (5.4)
path_bamdst=biosoft/bamdst/bamdst
genome_index=$genome_seq\.fai
genome_bed=$genome_seq\.bed
bamdst_outdir=$sample\_depth_coverage
bamdst_log=bamdst_log

mkdir -p $bamdst_outdir

# 4. untar input tarballs
# 4.1. untar the aligned bam files from the previous step as input for sort alignment
tar -xzf $parent_tarball -C ./ $sort_merge_dedup_bam $sort_merge_dedup_bam_index

# 4.2. untar the genomic sequence tarball
tar -xzf $genome_seq_tarball -C ./
rm $genome_seq_tarball

## 5. run steps of the pipeline
## 5.1. generate target list of InDel positions using GATK RealignerTargetCreator
gatk3 \
-T RealignerTargetCreator \
-R $genome_seq \
-I $sort_merge_dedup_bam \
-o $indel_list \
> $indel_list_log 2>&1

## 5.2. re-align around InDels using GATK IndelRealigner
# $path_gatk3 \
gatk3 \
-T IndelRealigner \
-R $genome_seq \
-I $sort_merge_dedup_bam \
-targetIntervals $indel_list \
-o $sort_merge_dedup_indel_bam \
> $realign_log 2>&1

rm $sort_merge_dedup_bam

# ## 5.3. Validating BAM files using Picard ValidateSamFile, to make sure there were no issues or mistakes associated with previous processing steps
# picard \
# ValidateSamFile \
# I=$sort_merge_dedup_indel_bam \
# O=$out_validate \
# MODE=SUMMARY \
# > $validate_log 2>&1

# the Validating BAM step was annotated because of an unknown error that would make this job fail right after this step.

## 5.4. stat the depth coverage of whole genome of each sample
# generate bed file from whole genome reference sequences
awk '{print $1, 0, $2}' $genome_index  > $genome_bed

# stat the depth coverage using bamdst
$path_bamdst \
-p $genome_bed \
-o $bamdst_outdir \
$sort_merge_dedup_indel_bam \
> $bamdst_log 2>&1

## 6. Handling output
# # 6.1. make sure to remove software packages from the working directory
# rm -r biosoft
# rm -r $ENVNAME

# 6.2. tar and move large output files to staging so they're not copied to the submit server
tar -czvf $out_tarball \
$indel_list $indel_list_log \
$sort_merge_dedup_indel_bam $realign_log \
$bamdst_outdir $bamdst_log
# $out_validate $validate_log \

# 6.3. copy output bam file to the input directory under /staging, as input of the next step (merge bam files into mpileup)
cp $sort_merge_dedup_indel_bam $indir_staging

# For log files (could be redirected stdout/stderr) that you want to check under home directory, 
# do not remove them at working directory, so that HTCondor will transfer them back to your home directory.
shopt -s extglob
rm -rf !($indel_list_log|$realign_log|$out_validate|$validate_log|$bamdst_log)
shopt -u extglob