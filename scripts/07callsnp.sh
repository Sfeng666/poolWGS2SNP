#!/bin/bash

## 1. receive arguments from 07callsnp.sub
outdir_staging=$1
conda_pack_squid=$2
genome_seq_squid=$3
job_parent=$4
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
parent_tarball=$outdir_staging/$job_parent\.tar.gz
out_tarball=$outdir_staging/$job\.tar.gz

# 3.2 local paths at working directory
genome_seq_tarball=$(basename $genome_seq_squid)
genome_seq=$(basename $genome_seq_squid .tar.gz)
bam_list=bam_list.txt

# for step1 (5.1)
wd_abs=$(pwd)
path_poolsnp=biosoft/PoolSNP/PoolSNP.sh
mpileup=mpileup.gz

names=""
while read -r line
do
    sample=$(basename $line _sort_merge_dedup_indel.bam)
    if [ $names ]
    then
        names+=",${sample}"
    else
        names+=$sample
    fi
done < $bam_list

call_snp_log=call_snp_log
prefix=snp
out_snp=$prefix\.vcf.gz
out_BS=$prefix\_BS.txt.gz
out_cov=$prefix\-cov-0.98.txt

# for step2 (5.2)
path_DetectIndels=biosoft/DrosEU_pipeline/scripts/DetectIndels.py

out_indel_positions=inDel-positions_20.txt.gz

# for step3 (5.3)
path_FilterPosFromVCF=biosoft/DrosEU_pipeline/scripts/FilterPosFromVCF.py

out_snp_clean=snp_clean.vcf.gz

# 4. untar input tarballs
# 4.1. untar the mpileup file from the output tarball of last step, as input of snp calling
tar -xzf $parent_tarball -C ./ $mpileup

# 4.2. untar the genomic sequence tarball
tar -xzf $genome_seq_tarball -C ./
rm $genome_seq_tarball

## 5. run steps of the pipeline

## 5.1. call SNPs with PoolSNP
bash $path_poolsnp \
mpileup=$wd_abs/$mpileup \
reference=$wd_abs/$genome_seq \
names=$names \
max-cov=0.98 \
min-cov=20 \
min-count=10 \
min-freq=0 \
miss-frac=0.001 \
jobs=0 \
BS=1 \
output=$wd_abs/$prefix \
> $call_snp_log 2>&1

## 5.2. identify sites in proximity of InDels with a minimum count of 20 across all samples pooled and mask sites 5bp up- and downstream of InDel.
python2.7 $path_DetectIndels \
--mpileup $mpileup \
--minimum-count 20 \
--mask 5 \
| gzip > $out_indel_positions

rm $mpileup

## 5.3. filter SNPs around InDels and in TE's from the original VCF produced with PoolSNP
python2.7 $path_FilterPosFromVCF \
--indel $out_indel_positions \
--vcf $out_snp \
| gzip > $out_snp_clean

## 6. Handling output
# # 6.1. make sure to remove software packages from the working directory
# rm -r biosoft
# rm -r $ENVNAME

# 6.2. tar and move large output files to staging so they're not copied to the submit server
tar -czvf $out_tarball \
$out_snp $out_BS $out_cov $call_snp_log \
$out_indel_positions \
$out_snp_clean

# For log files (could be redirected stdout/stderr) that you want to check under home directory, 
# do not remove them at working directory, so that HTCondor will transfer them back to your home directory.
shopt -s extglob
rm -rf !($call_snp_log|_condor_stdout|_condor_stdout)
shopt -u extglob