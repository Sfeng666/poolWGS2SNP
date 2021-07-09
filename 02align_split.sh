#!/bin/bash

## 1. receive arguments from 02align_split.sub
sample=$1
read1=$2
read2=$3
genome=$4
job=$5
bwa_index_squid=$6
conda_pack_align_squid=$7

## 2. configure the conda enviroment
set -e

workdir_pac=$(basename $conda_pack_align_squid)
ENVNAME=$(basename $conda_pack_align_squid .tar.gz)
ENVDIR=$ENVNAME

# these lines handle setting up the environment; you shouldn't have to modify them
export PATH
mkdir $ENVDIR
tar -xzf $workdir_pac -C $ENVDIR
. $ENVDIR/bin/activate
rm $workdir_pac

## 3. set local paths at working directory

# for step1 (5.1)
genome_tarball_wd=$(basename $bwa_index_squid)
# genome_tarball_wd=${bwa_index_squid##*/} //or use parameter extention to get the same filename
genome_index=$genome
in1=$(basename $read1)
in2=$(basename $read2)

out_bam=$job.bam
bwa_log=$job.bwa_log

t_bwa=2

## 4. untar input tarballs
# untar the tarball of bwa index of refernce genome
tar -xzf $genome_tarball_wd
rm $genome_tarball_wd

## 5. run steps of the pipeline
# 5.1. run bwa mem (Alignment & add read group tags & filter low quality alighments)
# add read group tags based on the description line of fastq files (line 1)
header=$(zless $in1 | head -n 1)
# extract ID and library-specific identifier based on sources of fastq files (fastq files from NCBI Sequence Read Archive, or other sources With Casava 1.8)
# here we assume that each sequencing run of fastq files from NCBI Sequence Read Archive is from a different sequencing library.
if [ ${header:0:4} = '@SRR' ]
then
    ID=$(echo $header | cut -f 2 -d" "| cut -f 1-4 -d":" | sed 's/:/./g')
    lib_spec_identifier=$(echo $header | cut -f 1 -d" "| cut -f 1 -d"." | sed 's/@//')
else
    ID=$(echo $header | cut -f 1-4 -d":" | sed 's/@//' | sed 's/:/./g')
    lib_spec_identifier=$(echo $header | cut -f 10 -d":")
fi

SM=$sample
PL=ILLUMINA
PU=$ID.$lib_spec_identifier
LB=$SM.$lib_spec_identifier
RG="@RG\tID:$ID\tPU:$PU\tSM:$SM\tLB:$LB\tPL:$PL"

bwa mem \
-M \
-t $t_bwa \
-R $RG \
-v 2 \
$genome_index \
$in1 \
$in2 \
2> $bwa_log \
| samtools view \
-Sbh -q 20 -F 0x100 - > $out_bam

## 5. Delete files other than those that you want to transfer back to home directory by HTCondor. 
shopt -s extglob
rm -rf !($out_bam|$bwa_log)
shopt -u extglob