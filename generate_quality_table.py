import os
import re
import tarfile

input_file = '/staging/sfeng77/dataset/suzukii_WGS/input_list.txt'
metrics_table_sample = '/home/sfeng77/jobs/test_pipeline/quality_metrics_sample.txt'
metrics_table_run = '/home/sfeng77/jobs/test_pipeline/quality_metrics_run.txt'

outdir_staging = '/staging/sfeng77/test_pipeline/out'
outdir_home = '/home/sfeng77/jobs/test_pipeline/out'

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

### write the tables of quality metrics

f = open(metrics_table_sample, 'w')
header_sample = '\t'.join(['Sample', 'Total reads (before qc)', 'Total reads (after qc)', 'QC rate', 
'Total reads (after BQ filtering)', 'BQ rate', 'Total reads (after alignment)', 'MQ rate',
'Total reads (after rmdup)', 'Duplication rate', 'Average depth', 'Total target bases (Mb)', 
'Lengh of genome', 'Coverage >0x', 'Coverage >10x', 'Regions of genome', 'Region covered > 0x', 
'Region covered > 10x'])
f.write(header_sample + '\n')

f_run = open(metrics_table_run, 'w')
header_run = '\t'.join(['Sample', 'Sequencing run', 'Total reads (before qc)', 'Total reads (after qc)',
'QC rate', 'Total reads (after BQ filtering)', 'BQ rate', 'Total reads (after alignment)', 'MQ rate'])
f_run.write(header_run + '\n')

for sample in input_list:
    tr1, tr2, tr3, tr4 = 0, 0, 0, 0

    # 1. extract sample depth & coverage information from output files of bamdst
    tar = tarfile.open('{0}/05realign_{1}.tar.gz'.format(outdir_staging, sample))
    f_cov = tar.extractfile('{0}_depth_coverage/coverage.report'.format(sample))
    for line in f_cov:
        line = line.decode('UTF-8')
        if re.search(r'\[Total\] Raw Reads \(All reads\)', line):
            tr5 = re.sub(r'^.*\[Total\] Raw Reads \(All reads\)|\s', '', line)
        elif re.search(r'\[Target\] Average depth\t', line):
            ad = re.sub(r'^.*\[Target\] Average depth|\s', '', line)
        elif re.search(r'\[Target\] Target Data\(Mb\)', line):
            td = re.sub(r'^.*\[Target\] Target Data\(Mb\)|\s', '', line)
        elif re.search(r'\[Target\] Len of region', line):
            lr = re.sub(r'^.*\[Target\] Len of region|\s', '', line)
        elif re.search(r'\[Target\] Coverage \(>0x\)', line):
            c0 = re.sub(r'^.*\[Target\] Coverage \(>0x\)|\s', '', line)
        elif re.search(r'\[Target\] Coverage \(>=10x\)', line):
            c10 = re.sub(r'^.*\[Target\] Coverage \(>=10x\)|\s', '', line)
        elif re.search(r'\[Target\] Target Region Count', line):
            trc = re.sub(r'^.*\[Target\] Target Region Count|\s', '', line)
        elif re.search(r'\[Target\] Fraction Region covered > 0x', line):
            rc0 = re.sub(r'^.*\[Target\] Fraction Region covered > 0x|\s', '', line)
        elif re.search(r'\[Target\] Fraction Region covered >= 10x', line):
            rc10 = re.sub(r'^.*\[Target\] Fraction Region covered >= 10x|\s', '', line)
    tar.close()

    # 2. extract duplication rate from dedup metrics
    with open('{0}/04rmdup_{1}/{1}_dedup_metrics.txt'.format(outdir_home, sample), 'r') as f_dup:
        for line in f_dup:
            if re.search(r'{0}.*\t\d*'.format(sample), line):
                dr = '{:.2%}'.format(float(line.strip().split('\t')[8]))
    
    # 3. extract metrics on the level of sequencing runs
    for sequencing_run in input_list[sample]:

        # 3.1. extract the total number of reads after MQ filtering at the alignment step
        with open('{0}/03sort_{1}/{1}_alignment_metrics.txt'.format(outdir_home, sequencing_run), 'r') as f_aln:
            for line in f_aln:
                if re.search(r'^PAIR\t', line):
                    r4 = int(line.strip().split('\t')[1])
                    tr4 += r4
                    break

        # 3.2. extract the total number of reads after BQ filtering and after qc
        with open('{0}/01qc_{1}/filter_report'.format(outdir_home, sequencing_run), 'r') as f_flt:
            for line in f_flt:
                if re.search('Number of pairs before filtering: ', line):
                    r2 = int(re.sub(r'Number of pairs before filtering:|\s', '', line))*2
                    tr2 += r2
                elif re.search('Number of pairs after filtering: ', line):
                    r3 = int(re.sub(r'Number of pairs after filtering:|\s', '', line))*2
                    tr3 += r3

        # 3.3. extract the total number of reads before qc
        with open('{0}/01qc_{1}/fastp_log'.format(outdir_home, sequencing_run), 'r') as f_qc:
            for line in f_qc:
                if re.search('total reads: ', line):
                    r1 = int(re.sub(r'total reads:|\s', '', line))*2
                    tr1 += r1
                    break

        # 3.4. write metrics on the level of sequencing runs to a table
        line_run = '\t'.join(map(str,[sample, sequencing_run, r1, r2, '{:.2%}'.format(r2/r1), r3, 
        '{:.2%}'.format(r3/r2), r4, '{:.2%}'.format(r4/r3)])) + '\n'
        f_run.write(line_run)
    
    # 4. write metrics on the level of samples to a table
    line_sample = '\t'.join(map(str, [sample, tr1, tr2, '{:.2%}'.format(tr2/tr1), tr3, 
    '{:.2%}'.format(tr3/tr2), tr4, '{:.2%}'.format(tr4/tr3), tr5, dr, ad, td, lr, c0, c10, trc, rc0, rc10])) + '\n'
    f.write(line_sample)

f.close()
f_run.close()

        


