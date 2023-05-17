#!/bin/bash

## 1. receive arguments from 08annotate.sub
outdir_staging=$1
conda_pack_squid=$2
genome_seq_squid=$3
genome_ann_squid=$4
genome_info=$5
ann_version=$6
job_parent=$7
job=$8

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
wd_abs=$(pwd)
genome_seq_tarball=$(basename $genome_seq_squid)
genome_seq=$(basename $genome_seq_squid .tar.gz)
genome_ann_tarball=$(basename $genome_ann_squid)
genome_ann_gtf=$(basename $genome_ann_squid .annotation.tar.gz).gtf

# for step1 (5.1)
## set variables
snpEff_dir=$wd_abs/WGS_analysis/share/snpeff-5.0-0
snpEff_data_dir=$snpEff_dir/data
snpEff_config=$snpEff_dir/snpEff.config

genome_version=$ann_version
genome_dir=$snpEff_data_dir/$genome_version
genome_seq_rename=$genome_dir/sequences.fa
genome_anno_rename=$genome_dir/genes.gtf
build_log=build_log

# for step2 (5.2)
snp_clean=snp_clean.vcf.gz
stats=snp_clean

snp_clean_ann=snp_clean-ann.vcf.gz
out_stats_html=$stats.html
out_stats_count=$stats.genes.txt
ann_log=ann_log

# 4. untar input tarballs
# 4.1. untar the mpileup file from the output tarball of last step, as input of snp calling
tar -xzf $parent_tarball -C ./ $snp_clean

# 4.2. untar the genomic sequence tarball
tar -xzf $genome_seq_tarball -C ./
rm $genome_seq_tarball

# 4.3. untar the genomic annotation tarball
tar -xzf $genome_ann_tarball -C ./
rm $genome_ann_tarball

## 5. run steps of the pipeline
# 5.1. build a snpEff database from annotation and sequences of the reference genome

## copy the genome assembly and annotation file to required directories, ref: https://pcingola.github.io/SnpEff/se_buildingdb/#option-1-building-a-database-from-gtf-files
mkdir -p $snpEff_data_dir
mkdir -p $genome_dir
cp $genome_seq $genome_seq_rename
cp $genome_ann_gtf $genome_anno_rename

## Add a genome to the configuration file, ref: https://pcingola.github.io/SnpEff/se_buildingdb/#add-a-genome-to-the-configuration-file
echo -e $genome_info >> $snpEff_config

## Building a snpEff database from GTF files, ref: https://pcingola.github.io/SnpEff/se_buildingdb/#option-1-building-a-database-from-gtf-files
cd $snpEff_dir
# echo SimulansFima| sudo -S \
snpEff \
build -gtf22 \
-v $genome_version \
> $build_log 2>&1

cd $wd_abs # cd back to the chtc working directory

# 5.2. annotate SNPs with snpEff
snpEff \
-ud 2000 \
$ann_version \
-stats $out_stats_html \
$snp_clean \
2> $ann_log \
| gzip > $snp_clean_ann

## 6. Handling output
# 6.1. make sure to remove software packages from the working directory
# rm -r biosoft
# rm -r $ENVNAME

# 6.2. tar and move large output files to staging so they're not copied to the submit server
tar -czvf $out_tarball \
$snp_clean_ann $out_stats_html $out_stats_count $ann_log

# For log files (could be redirected stdout/stderr) that you want to check under home directory, 
# do not remove them at working directory, so that HTCondor will transfer them back to your home directory.
shopt -s extglob
rm -rf !($ann_log)
shopt -u extglob