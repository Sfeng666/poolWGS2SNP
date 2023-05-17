#!/bin/bash

# 1. receive essential arguments from dag input
sequencing_run=$1
sample=$2
outdir_staging=$3
outdir_home=$4
indir_home=$5
dir_scripts=$6
genome=$7
split_lines=$8
bwa_index_squid=$9
conda_pack_align_squid=${10}
job_parent=${11}
job=${12}

# 2. set paths
path_splitFastq=/home/sfeng77/biosoft/fastq-tools/bin/splitFastq
indir_condor=$indir_home/$job
outdir_condor=$outdir_home/$job
parent_tarball=$outdir_staging/$job_parent\.tar.gz
out_filtered1=filtered_trimmed_$sequencing_run\_1.fastq.gz
out_filtered2=filtered_trimmed_$sequencing_run\_2.fastq.gz
in_split1=$indir_condor/$out_filtered1
in_split2=$indir_condor/$out_filtered2
indir_condor_split1=$indir_condor/split1
indir_condor_split2=$indir_condor/split2
pre_fix1=$indir_condor_split1/filtered_trimmed_$sequencing_run\_1
pre_fix2=$indir_condor_split2/filtered_trimmed_$sequencing_run\_2
subdag_input=$outdir_condor/$job.dag

# 3. mkdir for receiving output (log files) from HTCondor at home directories
# and for store split fastq files at home directories
mkdir -p $indir_condor
mkdir -p $outdir_condor
mkdir -p $indir_condor_split1
mkdir -p $indir_condor_split2

# 4. untar the trimmed & filtered fastq files from the previous step as input for split
tar -xzf $parent_tarball -C $indir_condor $out_filtered1 $out_filtered2

# 5. split
## important assumption!! Reads in fastq files of both ends must have the same order, and must be perfectly paired.
## this could guaranteed by using fastp, which already removed unpaired reads in the output 
$path_splitFastq \
-i $in_split1 \
-n $split_lines \
-o $pre_fix1 \
-z

rm $in_split1

$path_splitFastq \
-i $in_split2 \
-n $split_lines \
-o $pre_fix2 \
-z

rm $in_split2

# 6. write the subdag input file that includes alignment of all split fastq pairs
echo "CONFIG $dir_scripts/unlimited.config" >> $subdag_input

sort_in_split1=($indir_condor_split1/*.fastq.gz)
sort_in_split2=($indir_condor_split2/*.fastq.gz)
for ((i=0;i<${#sort_in_split1[@]};i++))
do
    read1=${sort_in_split1[i]}
    read2=${sort_in_split2[i]}
    echo "JOB ${job}_$i $dir_scripts/02align_split.sub" >> $subdag_input
    echo "VARS ${job}_$i sample=\"$sample\" read1=\"$read1\" read2=\"$read2\" genome=\"$genome\" outdir_condor=\"$outdir_condor\" request_disk=\"$(($split_lines*10/10 + 1*1024**2))\" request_memory=\"$(($split_lines*10/10/1024 + 5*1024))\" request_cpus=\"1\" bwa_index_squid=\"$bwa_index_squid\" conda_pack_align_squid=\"$conda_pack_align_squid\" dir_scripts=\"$dir_scripts\" job=\"\$(JOB)\"" >> $subdag_input
done