# -*- coding: utf-8 -*-
################################################################################
##  *
##  *  Function: prepare dag file to run the whole WGS pipeline on CHTC, from pair-end reads to SNP]
##  *  Writer:Siyuan Feng
##  *  Mail: siyuanfeng.bioinfo@gmail.com
##  *  Version: 12.5.2020
##  *
################################################################################

import os
from optparse import OptionParser

input_file = '/staging/sfeng77/dataset/suzukii_WGS/input_list.txt'
dag_input = '/home/sfeng77/jobs/test_pipeline/pipeline.dag'
outdir_staging = '/staging/sfeng77/test_pipeline/out'
indir_staging = '/staging/sfeng77/test_pipeline/in'
outdir_home = '/home/sfeng77/jobs/test_pipeline/out'
indir_home = '/home/sfeng77/jobs/test_pipeline/in'
dir_scripts = '/home/sfeng77/jobs/test_pipeline/scripts'
software_pack = '/home/sfeng77/biosoft/biosoft'
conda_pack_squid = 'http://proxy.chtc.wisc.edu/SQUID/sfeng77/suzukii_WGS/WGS_analysis.tar.gz'
conda_pack_align_squid = 'http://proxy.chtc.wisc.edu/SQUID/sfeng77/suzukii_WGS/align.tar.gz'
bwa_index_squid = 'http://proxy.chtc.wisc.edu/SQUID/sfeng77/suzukii_WGS/GCF_013340165.1_LBDM_Dsuz_2.1.pri_genomic.fna.bwa_index.tar.gz'
genome_seq_squid = 'http://proxy.chtc.wisc.edu/SQUID/sfeng77/suzukii_WGS/GCF_013340165.1_LBDM_Dsuz_2.1.pri_genomic.fna.tar.gz'
genome_ann_squid = 'http://proxy.chtc.wisc.edu/SQUID/sfeng77/suzukii_WGS/GCF_013340165.1_LBDM_Dsuz_2.1.pri_genomic.annotation.tar.gz'
genome = 'WT3-2.0'
ann_version = 'Dsuz-WT3_v2.0_refseq'
genome_info = 'Dsuz-WT3_v2.0_refseq.genome : Drosophila Suzukii'
split_lines = 100000

### 1. Set variables to count filtering statistics  ###
input_list = {}

### 2. Build a list of input files from input_file, with a hierachical structure of 'sample - sequencing_run - end'
with open(input_file, 'r') as f:
    i = 0
    for line in f:
        if i != 0:
            line = line.strip().split('\t')
            sample = line[0]
            sequencing_run = line[1]
            end = line[2]
            path = line[3]

            ## enable code below for pipeline test
            # if not sample in ['British-Columbia-BC', 'California-CA', 'BR-Pal']:
            #     continue

            if not sample in input_list:
                input_list[sample] = {sequencing_run: {end: path}}
            else:
                if not sequencing_run in input_list[sample]:
                    input_list[sample][sequencing_run] = {end: path}
                else:
                    input_list[sample][sequencing_run][end] = path
        i += 1

### 3. Write the DAG input file (.dag)
with open(dag_input, 'w') as f: 
    # set configuration variables for this dag, to remove default limits on job submissions
    # note!! the assumption to allow unlimited job submissions, is there should not be too many job submissions at the same time.
    f.write('CONFIG {0}/unlimited.config\n'.format(dir_scripts))

    disk_unit_sample_merge = 0
    memory_unit_sample_merge = 0
    for sample in input_list:
        disk_unit_sample = 0
        memory_unit_sample = 0
        
        for sequencing_run in input_list[sample]:
            read1 = input_list[sample][sequencing_run]['1']
            read2 = input_list[sample][sequencing_run]['2']

            # 3.0. get the size of input fastq files, as a reference unit for request dick space (KB) and memory (MB) for each job
            fastq_size = os.path.getsize(read1) + os.path.getsize(read2)
            disk_unit = fastq_size/float(1024)
            memory_unit = fastq_size/float(1024**2)

            # obtain the size of fastq files of all sequencing runs
            disk_unit_sample += disk_unit
            memory_unit_sample += memory_unit

            # 3.1. write job node for: QC steps (trim adapter/low quality reads + filter low quality reads)
            request_disk = int(round(2 * disk_unit + 3*1024**2, 0))
            request_memory = int(round(2 * memory_unit + 3*1024, 0))
            request_cpus = 2
            job_qc = 'JOB 01qc_{0} {1}/01qc.sub\n'.format(sequencing_run, dir_scripts)
            vars_qc = '''VARS 01qc_{0} sequencing_run="{0}" read1="{1}" read2="{2}" outdir_staging="{3}"\
            indir_staging="{4}" outdir_home="{5}" request_disk="{6}" request_memory="{7}" request_cpus="{8}"\
            conda_pack_squid="{9}" software_pack="{10}" dir_scripts="{11}"  job="$(JOB)"\n'''.format(
            sequencing_run, read1, read2, outdir_staging, indir_staging, outdir_home, request_disk, request_memory, 
            request_cpus, conda_pack_squid, software_pack, dir_scripts)
            pre_qc = 'SCRIPT PRE 01qc_{0} {5}/01qc_pre.sh {1} {2} {3} {4} $JOB\n'.format(
            sequencing_run, read1, read2, indir_staging, outdir_home, dir_scripts) 
            # f.writelines([job_qc, vars_qc, pre_qc])

            # 3.2. write the job node for: alignment (split + align + combine)
            job_relation = 'PARENT 01qc_{0} CHILD 02align_{0}\n'.format(sequencing_run)
            job_align = 'SUBDAG EXTERNAL 02align_{0} {1}/02align_{0}/02align_{0}.dag\n'.format(sequencing_run, outdir_home)
            pre_align = 'SCRIPT PRE 02align_{0} {5}/02align_pre.sh {0} {1} {2} {3} {4} {5} {6} {7} {8} {9} 01qc_{0} $JOB\n'.format(
            sequencing_run, sample, outdir_staging, outdir_home, indir_home, dir_scripts, 
            genome, split_lines, bwa_index_squid, conda_pack_align_squid) 
            post_align = 'SCRIPT POST 02align_{0} {4}/02align_post.sh {0} {1} {2} {3} $JOB\n'.format(
            sequencing_run, outdir_staging, outdir_home, indir_home, dir_scripts)
            # f.writelines([job_relation, job_align, pre_align, post_align])

             # 3.3. write the job node for: sort alignment (sort alignment + calculate alignment metrics)
            request_disk = int(round(1.5 * disk_unit + 3*1024**2, 0))
            request_memory = int(round(1 * memory_unit + 3*1024, 0))
            request_cpus = 1
            job_relation = 'PARENT 02align_{0} CHILD 03sort_{0}\n'.format(sequencing_run)
            job_sort = 'JOB 03sort_{0} {1}/03sort.sub\n'.format(sequencing_run, dir_scripts)
            vars_sort = '''VARS 03sort_{0} sequencing_run="{0}" outdir_staging="{1}" outdir_home="{2}"\
            request_disk="{3}" request_memory="{4}" request_cpus="{5}"\
            conda_pack_squid="{6}" genome_seq_squid="{7}" dir_scripts="{8}" job_parent="02align_{0}"  job="$(JOB)"\n'''.format(
            sequencing_run, outdir_staging, outdir_home, request_disk, request_memory, request_cpus, conda_pack_squid, genome_seq_squid, dir_scripts)
            pre_sort = 'SCRIPT PRE 03sort_{0} {2}/mkdir_pre.sh {1} $JOB\n'.format(sequencing_run, outdir_home, dir_scripts) 
            # f.writelines([job_relation, job_sort, vars_sort, pre_sort])
        
        # 3.4. write the job node for: mark/remove PCR duplicate
        parent_list_sample = {x: '03sort_{0}'.format(x) for x in input_list[sample]}
        request_disk = int(round(0.5 * disk_unit_sample + 2*1024**2, 0))
        request_memory = int(round(0.5 * memory_unit_sample + 2*1024, 0))
        request_cpus = 1

        job_relation_sample = 'PARENT {0} CHILD 04rmdup_{1}\n'.format(' '.join(parent_list_sample.values()), sample)
        job_rmdup = 'JOB 04rmdup_{0} {1}/04rmdup.sub\n'.format(sample, dir_scripts)
        vars_rmdup = '''VARS 04rmdup_{0} sample="{0}" outdir_staging="{1}" outdir_home="{2}"\
        request_disk="{3}" request_memory="{4}" request_cpus="{5}" conda_pack_squid="{6}" job="$(JOB)"\n'''.format(
        sample, outdir_staging, outdir_home, request_disk, request_memory, request_cpus, conda_pack_squid)
        # f.writelines([job_relation_sample, job_rmdup, vars_rmdup])

        # Since several lines of the executable depend on the number of sequencing runs, which might defer between samples, 
        # we need to print the executable specific to each sample, instead of using the same executable as previous steps.
        os.system('mkdir -p {0}/04rmdup_{1}'.format(outdir_home, sample))
        with open('{0}/04rmdup_{1}/04rmdup.sh'.format(outdir_home, sample), 'w') as f_exec:
            f_exec.write('''#!/bin/bash

## 1. receive arguments from 01qc.sub
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
out_tarball=$outdir_staging/$job\\.tar.gz

# 3.2 local paths at working directory
# for step1 (5.1)
sort_merge_dedup_bam=$sample\\_sort_merge_dedup.bam
sort_merge_dedup_bam_index=$sample\\_sort_merge_dedup.bai
dedup_metrics=$sample\\_dedup_metrics.txt
dedup_log=dedup_log
TMP_DIR=./

# 4. untar sorted alignments from sequencing run(s) as single/multiple input for mark/remove duplicate
# note that the number of sequencing runs of samples could differ from one another, so we choose to print the executable specific to each sample.\n''')
            picard_I = []
            for sequencing_run in parent_list_sample:
                tar = 'tar -xzf {0}/{1}.tar.gz -C ./ {2}_sort.bam\n'.format(outdir_staging, parent_list_sample[sequencing_run], sequencing_run)
                f_exec.write(tar)

                I = 'I={0}_sort.bam \\\n'.format(sequencing_run)
                picard_I.append(I)
            f_exec.write('''
## 5. run steps of the pipeline
## 5. remove PCR duplicates using Picard MarkDuplicates (while merge sequencing runs of a sample into one bam file, if there're multiple sequencing runs )
picard \\
MarkDuplicates \\
REMOVE_DUPLICATES=true \\\n''')
            f_exec.writelines(picard_I)
            f_exec.write('''O=$sort_merge_dedup_bam \\
M=$dedup_metrics \\
TMP_DIR=$TMP_DIR \\
VALIDATION_STRINGENCY=SILENT \\
CREATE_INDEX=true \\
> $dedup_log 2>&1

## 6. Handling output
# 6.1. tar and move large output files to staging so they're not copied to the submit server
tar -czvf $out_tarball \
$sort_merge_dedup_bam $sort_merge_dedup_bam_index $dedup_metrics $dedup_log

# 6.2. For log files (could be redirected stdout/stderr) that you want to check under home directory, 
# do not remove them at working directory, so that HTCondor will transfer them back to your home directory.
shopt -s extglob
rm -rf !($dedup_log|$dedup_metrics)
shopt -u extglob''')

        # 3.5. write the job node for: re-align around inDels (re-align + validate BAM files + stat depth & coverage from BAM files)
        request_disk = int(round(1 * disk_unit_sample + 2*1024**2, 0))
        request_memory = int(round(0.5 * memory_unit_sample + 2*1024, 0))
        request_cpus = 1

        job_relation_sample = 'PARENT 04rmdup_{0} CHILD 05realign_{0}\n'.format(sample)
        job_realign = 'JOB 05realign_{0} {1}/05realign.sub\n'.format(sample, dir_scripts)
        vars_realign = '''VARS 05realign_{0} sample="{0}" outdir_staging="{1}" indir_staging="{2}" outdir_home="{3}"\
        request_disk="{4}" request_memory="{5}" request_cpus="{6}" conda_pack_squid="{7}"\
        genome_seq_squid="{8}" dir_scripts="{9}" software_pack="{10}" job_parent="04rmdup_{0}" job="$(JOB)"\n'''.format(
        sample, outdir_staging, indir_staging, outdir_home, request_disk, request_memory, request_cpus, conda_pack_squid,
        genome_seq_squid, dir_scripts, software_pack)
        pre_realign = 'SCRIPT PRE 05realign_{0} {2}/mkdir_pre.sh {1} $JOB\n'.format(sample, outdir_home, dir_scripts) 
        # f.writelines([job_relation_sample, job_realign, vars_realign, pre_realign])

        # 3.6.0. obtain the size of fastq files of all samples
        disk_unit_sample_merge += disk_unit_sample
        memory_unit_sample_merge += memory_unit_sample

    # 3.6. write the job node for: merge BAM files into a MPILEUP file only retaining nucleotides with BQ >20 and reads with MQ > 20
    request_disk = int(round(0.7 * disk_unit_sample_merge + 2*1024**2, 0))
    request_memory = int(round(0.05 * memory_unit_sample_merge + 2*1024, 0))
    request_cpus = 1

    parent_list_sample_merge = list('05realign_{0}'.format(x) for x in input_list)
    job_relation_sample_merge = 'PARENT {0} CHILD 06mpileup\n'.format(' '.join(parent_list_sample_merge))
    job_mpileup = 'JOB 06mpileup {0}/06mpileup.sub\n'.format(dir_scripts)
    vars_mpileup = '''VARS 06mpileup outdir_staging="{0}" indir_staging="{1}" outdir_home="{2}"\
    request_disk="{3}" request_memory="{4}" request_cpus="{5}" conda_pack_squid="{6}"\
    genome_seq_squid="{7}" dir_scripts="{8}" job="$(JOB)"\n'''.format(
    outdir_staging, indir_staging, outdir_home, request_disk, request_memory, request_cpus, conda_pack_squid,
    genome_seq_squid, dir_scripts)
    pre_mpileup = 'SCRIPT PRE 06mpileup {0}/06mpileup_pre.sh {1} {2} $JOB\n'.format(dir_scripts, outdir_home, indir_staging)
    # f.writelines([job_relation_sample_merge, job_mpileup, vars_mpileup, pre_mpileup])
    f.writelines([job_mpileup, vars_mpileup, pre_mpileup])

    # write a list of bam files of all samples, as an input for samtools mpileup
    bam_list = '{0}/bam_list.txt'.format(indir_staging)
    with open(bam_list, 'w') as f_bamlist:
        for sample in input_list:
            f_bamlist.write('{0}_sort_merge_dedup_indel.bam\n'.format(sample))
    
    # 3.7. write the job node for: SNP Calling & filtering (SNP Calling & filtering + Identify & mask sites around InDels + filter SNPs around InDels)
    request_disk = int(round(0.8 * disk_unit_sample_merge + 2*1024**2, 0))
    request_memory = int(round(0.1 * memory_unit_sample_merge + 2*1024, 0))
    request_cpus = 8

    job_relation_sample_merge = 'PARENT 06mpileup CHILD 07callsnp\n'
    job_callsnp = 'JOB 07callsnp {0}/07callsnp.sub\n'.format(dir_scripts)
    vars_callsnp = '''VARS 07callsnp outdir_staging="{0}" outdir_home="{1}"\
    request_disk="{2}" request_memory="{3}" request_cpus="{4}" conda_pack_squid="{5}"\
    genome_seq_squid="{6}" dir_scripts="{7}" bam_list="{8}" software_pack="{9}"job_parent="06mpileup" job="$(JOB)"\n'''.format(
    outdir_staging, outdir_home, request_disk, request_memory, request_cpus, conda_pack_squid,
    genome_seq_squid, dir_scripts, bam_list, software_pack)
    pre_callsnp = 'SCRIPT PRE 07callsnp {0}/mkdir_pre.sh {1} $JOB\n'.format(dir_scripts, outdir_home)
    f.writelines([job_relation_sample_merge, job_callsnp, vars_callsnp, pre_callsnp])

    # 3.8. write the job node for: SNP annotation
    request_disk = int(round(0.1 * disk_unit_sample_merge + 2*1024**2, 0))
    request_memory = int(round(0.01 * memory_unit_sample_merge + 2*1024, 0))
    request_cpus = 1

    job_relation_sample_merge = 'PARENT 07callsnp CHILD 08annotate\n'
    job_annotate = 'JOB 08annotate {0}/08annotate.sub\n'.format(dir_scripts)
    vars_annotate = '''VARS 08annotate outdir_staging="{0}" outdir_home="{1}"\
    request_disk="{2}" request_memory="{3}" request_cpus="{4}" conda_pack_squid="{5}"\
    dir_scripts="{6}" ann_version="{7}" genome_seq_squid="{8}" genome_ann_squid="{9}" genome_info="{10}" job_parent="07callsnp" job="$(JOB)"\n'''.format(
    outdir_staging, outdir_home, request_disk, request_memory, request_cpus, conda_pack_squid, dir_scripts, ann_version, genome_seq_squid, genome_ann_squid, genome_info)
    pre_annotate = 'SCRIPT PRE 08annotate {0}/mkdir_pre.sh {1} $JOB\n'.format(dir_scripts, outdir_home)
    f.writelines([job_relation_sample_merge, job_annotate, vars_annotate, pre_annotate])







