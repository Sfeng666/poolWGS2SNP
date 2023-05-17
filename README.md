# poolWGS2SNP: a high-performance workflow to identify SNPs from pool-seq data
----
The bioinformatic workflow to call SNPs from Fastq files of raw pool-sequenced pair-end DNA reads. Please check out our corresponding paper:

## Features
* Built and optimized for pool-sequenced data.
* The alignment step is made hundreds or even thousands of times as fast, depending on the number of threads available at your computer/cluster. Other than processing each sample as a whole, we automatically split each fastq file into files of any given size, align parallelly to the reference genome, and then combine them into one aligned BAM file for downstream processing.

## Environment
This workflow was built on [DAGMan (Directed Acyclic Graph Manager)][DAGMan], and is primarily designed to run through the [HTCondor][HTCondor] job scheduler (set up to run on UW-Madison's CHTC). 

However, shell scripts of each step could still be run independently, as long as required input is provided.

To install the software environment, you could use conda:
```
conda env create -n WGS_analysis --file WGS_analysis.yml
```
If you have not installed conda, run the following command:
```
# download miniconda
curl -sL \
  "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh" > \
  "Miniconda3.sh"
```
```  
# install miniconda
bash Miniconda3.sh
```
## Input
* a table of paths to fastq files containing raw pair-end (PE) whole genome sequencing (WGS) reads ([example](docs/input_list.txt));
* reference genomic sequence (.fasta) and an fasta index (.fai) to allow fast access to the genome;
* bwa index of reference genomic sequence;
* annotation of reference genome in .gff and .gtf formats

## Output
* a table of SNPs in VCF format with an additional column of variant annotations;
* (optional) a report of the depth and coverage of clean mapped reads;
* (optional) a full report on the number and proportion of remaining reads after each step of quality control and filtering, as well as the depth and coverage of clean mapped reads;

## Workflow diagram
![Workflow diagram](docs/pipeline.jpg)

The analysis pipeline to call SNPs from pool-seq raw reads. Grey shadings and bold texts represent the three major parts of this pipeline. Input and output are indicated by elliptical boxes. Required steps are indicated by rectangular boxes and arrows in solid lines. Optional steps are indicated by dashed boxes and arrows. Names and versions of used software are colored in blue

## Reference
[DrosEU pipeline](https://github.com/capoony/DrosEU_pipeline): Kapun, M., Barrón, M. G., Staubach, F., Obbard, D. J., Wiberg, R. A. W., Vieira, J., Goubert, C., Rota-Stabelli, O., Kankare, M., Bogaerts-Márquez, M., Haudry, A., Waidele, L., Kozeretska, I., Pasyukova, E. G., Loeschcke, V., Pascual, M., Vieira, C. P., Serga, S., Montchamp-Moreau, C., … González, J. (2020). Genomic Analysis of European Drosophila melanogaster Populations Reveals Longitudinal Structure, Continent-Wide Selection, and Previously Unknown DNA Viruses. Molecular Biology and Evolution, 37(9), 2661–2678. https://doi.org/10.1093/molbev/msaa120

[fastp](https://github.com/OpenGene/fastp): Shifu Chen, Yanqing Zhou, Yaru Chen, Jia Gu; fastp: an ultra-fast all-in-one FASTQ preprocessor, Bioinformatics, Volume 34, Issue 17, 1 September 2018, Pages i884–i890, https://doi.org/10.1093/bioinformatics/bty560

[bwa mem](https://github.com/lh3/bwa): Li, H. (2013). Aligning sequence reads, clone sequences and assembly contigs with BWA-MEM (arXiv:1303.3997). arXiv. https://doi.org/10.48550/arXiv.1303.3997

[Samtools](https://github.com/samtools/samtools): Li, H., Handsaker, B., Wysoker, A., Fennell, T., Ruan, J., Homer, N., Marth, G., Abecasis, G., Durbin, R., & 1000 Genome Project Data Processing Subgroup. (2009). The Sequence Alignment/Map format and SAMtools. Bioinformatics, 25(16), 2078–2079. https://doi.org/10.1093/bioinformatics/btp352

[Picard](https://github.com/broadinstitute/picard)

[GATK](https://github.com/broadgsa/gatk): Auwera, G. A. V. der, & O’Connor, B. D. (2020). Genomics in the Cloud: Using Docker, GATK, and WDL in Terra. O’Reilly Media, Inc.

[bamdst](https://github.com/shiquan/bamdst)

[PoolSNP](https://github.com/capoony/PoolSNP)

[SnpEff](https://pcingola.github.io/SnpEff/): Cingolani, P., Platts, A., Wang, L. L., Coon, M., Nguyen, T., Wang, L., Land, S. J., Lu, X., & Ruden, D. M. (2012). A program for annotating and predicting the effects of single nucleotide polymorphisms, SnpEff: SNPs in the genome of Drosophila melanogaster strain w 1118 ; iso-2; iso-3. Fly, 6(2), 80–92. https://doi.org/10.4161/fly.19695

----
[DAGMan]: https://htcondor.org/dagman/dagman.html
[HTCondor]: https://htcondor.org/htcondor/overview/
[DrosEU pipeline]: https://github.com/capoony/DrosEU_pipeline
