# -*- coding: utf-8 -*-
################################################################################
##  *
##  *  Function: filter PE reads by the total length and each-read length of non-N high-quality bases from each pair]
##  *  Writer:Siyuan Feng
##  *  Mail: siyuanfeng.bioinfo@gmail.com
##  *  Version: 10.27.2020
##  *
################################################################################

import timeit
import os
import gzip
from optparse import OptionParser
starttime = timeit.default_timer()

### help and usage ### 
usage = "usage: %prog [options] args"
description = "filter PE reads by the total length of non-N high-quality bases from each pair"
version = '%prog 10.27.2020'
parser = OptionParser(usage=usage,version=version, description = description)
parser.add_option("--length_min",
                    action="store",
                    dest="length_min",
                    help="Minimum length of non-N bases from each pair. Default = 150",
                    metavar = 'CUTOFF',
                    type = 'int',
                    default = 150) 
parser.add_option("--length_max",
                    action="store",
                    dest="length_max",
                    help="Maximum length of non-N bases from each pair. Default = 300",
                    metavar = 'CUTOFF',
                    type = 'int',
                    default = 300)
parser.add_option("--length_min_each",
                    action="store",
                    dest="length_min_each",
                    help="Minimum length of non-N bases from each read. Default = 25",
                    metavar = 'CUTOFF',
                    type = 'int',
                    default = 25)                     
parser.add_option("--quality",
                    action="store",
                    dest="quality",
                    help="Minimum quality of a base to be considered as high-quality. Default = 20",
                    metavar = 'CUTOFF',
                    type = 'int',
                    default = 20)                    
parser.add_option("--phred",
                    action="store",
                    dest="phred",
                    help="Type of phred score in input fastq files. Only be set as 33 or 64. Default = 33",
                    metavar = 'CUTOFF',
                    type = 'int',
                    default = 33) 
parser.add_option("--in1",
                    action="store",
                    dest="in1",
                    help="path of read1 input file",
                    metavar = 'PATH')
parser.add_option("--in2",
                    action="store",
                    dest="in2",
                    help="path of read2 input file",
                    metavar = 'PATH')
parser.add_option("--out1",
                    action="store",
                    dest="out1",
                    help="output path of read1 filtered file",
                    metavar = 'PATH')
parser.add_option("--out2",
                    action="store",
                    dest="out2",
                    help="output path of read2 filtered file",
                    metavar = 'PATH')
parser.add_option("--report",
                    action="store",
                    dest="report",
                    help="output path of filtering report",
                    metavar = 'PATH')                                                                                                    
(options,args) = parser.parse_args()
#############################

### parameters ###
length_min = options.length_min
length_max = options.length_max
length_min_each = options.length_min_each
quality = options.quality
phred = options.phred
in1 = options.in1
in2 = options.in2
out1 = options.out1
out2 = options.out2
report = options.report
###################

### 1. Set variables to count filtering statistics  ###
total = 0
filtered_total = 0
filtered_each = 0
filtered_each_1 = 0 # swich the order of pair-end filtering and each-end filtering
filtered_total_2 = 0 # swich the order of pair-end filtering and each-end filtering
total_bases = 0
total_bases_passed = 0
q20_bases = 0
q20_bases_passed = 0
q30_bases = 0
q30_bases_passed = 0

### 2. Filter PE reads from fq.gz files ###
with gzip.open(in1, 'rt') as f1, gzip.open(in2, 'rt') as f2, gzip.open(out1, 'wt', compresslevel=4) as o1, gzip.open(out2, 'wt', compresslevel=4) as o2:
    i = 0
    temp1 = ''
    temp2 = ''
    for line1,line2 in zip(f1, f2):
        i += 1
        temp1 += line1
        temp2 += line2
        line1 = line1.strip()
        line2 = line2.strip()
        if i == 4:
            total += 1
            seq_elen1 = len(list(x for x in line1 if ord(x) >= phred + quality))
            seq_elen2 = len(list(x for x in line2 if ord(x) >= phred + quality))
            total_bases += len(line1) + len(line2)
            q20_bases += len(list(x for x in line1 if ord(x) >= phred + 20)) + len(list(x for x in line2 if ord(x) >= phred + 20))
            q30_bases += len(list(x for x in line1 if ord(x) >= phred + 30)) + len(list(x for x in line2 if ord(x) >= phred + 30))
            if seq_elen1 + seq_elen2 >= length_min and seq_elen1 + seq_elen2 <= length_max:
                if seq_elen1 >= length_min_each and seq_elen2 >= length_min_each:
                    o1.write(temp1)
                    o2.write(temp2)
                    total_bases_passed += len(line1) + len(line2)
                    q20_bases_passed += len(list(x for x in line1 if ord(x) >= phred + 20)) + len(list(x for x in line2 if ord(x) >= phred + 20))
                    q30_bases_passed += len(list(x for x in line1 if ord(x) >= phred + 30)) + len(list(x for x in line2 if ord(x) >= phred + 30))
                else:
                    filtered_each += 1
            else:
                filtered_total += 1

            if seq_elen1 >= length_min_each and seq_elen2 >= length_min_each:
                if seq_elen1 + seq_elen2 >= length_min and seq_elen1 + seq_elen2 <= length_max:
                    pass
                else:
                    filtered_total_2 += 1
            else:
                filtered_each_1 += 1

            temp1 = ''
            temp2 = ''
            i = 0

### 3. Report filtering statistics ###
endtime = timeit.default_timer()
with open(report, 'w') as f:
    f.write('### Before filtering ###\n')
    f.write('Number of pairs before filtering: {0}\n'.format(total))
    f.write('Number of bases before filtering: {0}\n'.format(total_bases))
    f.write('Number of Q20 bases before filtering: {0} (Q20 ratio: {1}%)\n'.format(q20_bases, format(q20_bases * 100/total_bases, '.2f')))
    f.write('Number of Q30 bases before filtering: {0} (Q30 ratio: {1}%)\n\n'.format(q30_bases, format(q30_bases * 100/total_bases, '.2f')))

    f.write('### After filtering ###\n')
    f.write('Number of pairs after filtering: {0}\n'.format(total - filtered_each - filtered_total))
    f.write('Number of bases after filtering: {0}\n'.format(total_bases_passed))
    f.write('Number of Q20 bases after filtering: {0} (Q20 ratio: {1}%)\n'.format(q20_bases_passed, format(q20_bases_passed * 100/total_bases_passed, '.2f')))
    f.write('Number of Q30 bases after filtering: {0} (Q30 ratio: {1}%)\n\n'.format(q30_bases_passed, format(q30_bases_passed * 100/total_bases_passed, '.2f')))

    f.write('### Reads that failed at filtering ###\n')
    f.write('Number of pairs failed at total length: {0}\n'.format(filtered_total))
    f.write('Number of pairs failed at length of each read (passed total length filtering): {0}\n'.format(filtered_each))
    f.write('Number of pairs failed at length of each read : {0}\n'.format(filtered_each_1))
    f.write('Number of pairs failed at total length (passed length of each read): {0}\n\n'.format(filtered_total_2))

    f.write('### Performance ###\n')
    f.write('Time used: {0} seconds\n'.format(format(endtime-starttime, '.0f')))
