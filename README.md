# LDblocks_GRCh38 <a name="top"/>

The goal of the code in this repository is to generate approximately
independent LD blocks for European, Asian, and African ancestries
based on the GRCh38 genome. While LD blocks currently exist for these
ancestries (for example [here](https://github.com/bogdanlab/RHOGE)),
they are based on GRCh37. Methods to convert genetic loci from one
genome build (notably the UCSC liftOver tool) do not work well for
genetic blocks, tending to fragment the block and often spreading
portions across different chromosomes.

Instead, we use
[LDetect](https://bitbucket.org/nygcresearch/ldetect/src/master/) to
generate new LD blocks, using GRCh38-based [1000Genomes
data](http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/1000_genomes_project/release/20181203_biallelic_SNV/)
and [recombination maps that have been lifted over to
GRCh38](http://csg.sph.umich.edu/locuszoom/download/recomb-hg38.tar.gz).


### Table of contents
+ [Pipeline prep](#pipelineprep)
+ [Parse data](#parseit)
+ [Process data](#processit)
+ [Technical addendum](#ughbro)

## Pipeline prep <a name="pipelineprep"/>

These data were generated on a Linux cluster, as it is beneficial to
parallelize many of the steps. We installed LDetect following the
recommendation to use `pip`

```sh
pip install ldetect
```
This installs the LDetect software, as well as downloading a set of
example scripts that can be used to perform many of the required
steps. We also used [bcftools](http://www.htslib.org/download/) to process the VCF files.


## Parse data <a name="parseit"/>

We downloaded the December 2018 biallelic SNV 1000Genomes GRCh38 VCF
files from the link noted above, as well as the GRCh38 recombination
maps from UM SPH. It appears that these recombination maps were
orignally generated by the HapMap consortium for NCBI build 36, (which
is equivalent to hg18 in UCSC Genome Build nomenclature), and have
been lifted over to GRCh37 by others, and then to GRCh38 by UM
SPH. This map file contains all chromosomes, but LDetect requires the
genetic maps to be by-chromosome and gzipped, so we did

```sh
awk '{if($1 !~ /chrom/) print $1"\t"$2"\t"$4 > $1.tab}' genetic_map_GRCh38_merged.tab
```
and then gzipped the resulting files. The VCF files
and the map files have to contain the same positions, or at least the
VCF files cannot have positions that are not in the map files, so we
filtered the VCF files based on the map file contents. As an example,
for chr1:

```sh
zcat chr1.tab.gz | cut -f 1-2 > vcfsubsets/chr1

bcftools view -R chr1 \
		 ALL.chr1.shapeit2_integrated_v1a.GRCh38.20181129.phased.vcf.gz \
		 -O z -o chr1.vcf.gz
```

This takes an inordinate amount of time, so we parallelized by using
the script called `subsetByChr.sh` which can be found in the scripts
directory of this repository (as can all other scripts mentioned in
this README), which processes all chromosomes at one time. The
`subsetByChr.sh` script also indexes the resulting VCF files.


## Process data <a name="processit"/>

To generate the LD blocks we followed the general instructions
provided at the [LDetect bitbucket
repository](https://bitbucket.org/nygcresearch/ldetect/src/master/)
with some small changes required by the particulars of our data. The
first step is to generate partitions of the genome that can then be
processed in parallel. Since we assume the GRCh38 genetic map from UM
SPH is based on the original HapMap data, we also assume 379
individuals. The general usage is

```sh
python3 P00_00_partition_chromosome.py <genetic_map> <n_individuals> <output_file>
```

Because each step is fast, we did it sequentially:

```sh
for f in chr{1..22}.tab.gz; do python3 P00_00_partition_chromosome.py $f 379 scripts/${f/.tab.gz/}_partitions; done
```
Note that the example scripts expect things to be in a `scripts/`
directory, so we followed that convention. The next step is to use
these partitions to compute the covariance matrix. In other words, we
want the covariance of the variants within a chromosomal region, for
those individuals of a given ancestry. The VCF files we have include
all of the 1000Genomes subjects, so we subsetted to European,
Asian, and African ancestries.

To subset, we selected individuals from a set of representative
populations. 

+ Europeans: TSI, IBS, CEU, GBR
+ Asians: CHB, JPT, CHS, CDX, KHV
+ Africans: YRI, LWK, GWD, MSL, ESN

We collected the 1000Genomes subject IDs that correspond to those
populations using a bash script. An example for the Europeans is:

```sh
for dir in TSI IBS CEU GBR 
 do
     curl -s -L ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/1000_genomes_project/data/"$dir"/ \
 | awk '{print $NF}' >> eurinds.txt
 done
```
Which collects all the 1000Genomes subject IDs in a text file. We
repeated this for Asians and Africans. There are more subjects in
these text files than we have in the VCF files, so we used a simple
script to get the intersection:

```sh

zcat vcfsubsets/chr9.vcf.gz | head -n 30 | awk '$1 ~/#CHR/ {print $0}' \
| cut -f 10- > subjects.txt

cat subjects.txt eurinds.txt | sort | uniq -d > tmp.txt; mv tmp.txt eurinds.txt

```

The first line simply captures the subject IDs in a VCF (they all have
the same IDs) and the second returns all the European subject IDs that
are found in both the VCFs and the IDs we got from 1000Genomes.

We then computed all the correlation values in parallel using
`runAllCov.sh` which can be found in the scripts directory.

```sh
runAllCov.sh eurinds.txt EUR 11418
```

The final argument for that script (11418) is the effective population
size for Europeans. We used 17469 and 14269 for Africans and Asians,
respectively.

There are three more steps; convert the covariance matrices into
vectors, calculate the minima across the covariance matrices, and then
extract the minima (which are output as python .pickle files) into .bed
files. We used three scripts to parallelize these steps (which are
steps 3-5 in the LDetect example). As an example for the European
ancestry:

```sh

runStep3.sh EUR
runStep4.sh EUR
runStep5.sh EUR

``` 

Which we then repeated for the African and Asian ancestries, after
which we have .bed files that delineate the approximate LD blocks,
by chromosome, for each ancestry.


## Technical addendum <a name=ughbro/>

This repository is mainly meant as a way for people to get the LD
blocks for their own use, as well as to document exactly how the LD
blocks were generated. If you just want the LD blocks, see the data
directory of this repository. However, it is not inconceivable that
someone might want to use the scripts themselves. To that end, we
provide some technical pointers. 

First, please note that the bash scripts provided are intended to be
used on a cluster environment, which usually means that `qsub` is
available. They will not work 'out of the box', as we have hard-coded
the queue that we used, as well as some of the paths to our
data. These will have to be adjusted to correspond to your own cluster
in order for them to work correctly. For example, here is
`runStep3.sh`:

```sh
#!/bin/bash

#$ -q lindstroem.q
#$ -cwd
#$ -l h_vmem=20G
#$ -t 1-22

## code to run step 3 run it by qsub runStep3.sh <population dir>
## e.g., qsub ./runStep3.sh EUR
pop=$1

source env/bin/activate

python3 P01_matrix_to_vector_pipeline.py --dataset_path="$pop"/ --name=chr"$SGE_TASK_ID" --out_fname="$pop"/chr"$SGE_TASK_ID".vector.txt.gz

```
We used our internal queue (the `#$ -q lindstroem.q` directive). This
will have to be modified to use your own queue.

Second, we installed LDetect in a `virtualenv` called 'env', and the
bash scripts (notably runStep3.sh, runStep4.sh and runStep5.sh) have a
line that activates that `virtualenv` prior to running the python code
(the line `source env/bin/activate`). The easiest thing to do would be
to copy that paradigm.

Third, there appears to be a bug in the LDetect codebase that causes
a problem in step 4, where the minima are computed. This only affects
the uniform local minima, which might not matter (we used the
fourier-ls breakpoints which correspond to the low-pass filter with
local search). There is a cryptic line in the README for LDetect that
says

> This file (P02_minima_pipeline.py) can be tweaked to remove all but
> the low-pass filter with local search algorithm in order to reduce
> total runtime.

What we had to do to 'fix' the problem is complicated and boring and
not worth going into. Suffice it to say that lines 103-105 in
`P02_minima_pipeline.py` look like this:

```python
    metric_out_uniform_local_search = apply_metric(chr_name, begin, end, config, breakpoint_loci_uniform_local_search['loci'])
    flat.print_log_msg('Global metric:')
    print_metric(metric_out_uniform_local_search)
```
And commenting out those lines will bypass the bug. And
commenting out everything from line 93-105 will accomplish what the
LDetect authors meant by 'remove all but the
low-pass filter with local search algorithm', which will bypass the
bug and also reduce the computational expense.

Fourth, the bug mentioned above has to do with `None` values in the
minima results at the beginning and the end of the individual blocks
being tested. This causes the uniform breakpoint code to get trapped
in a loop, but the other three methods continue without
failing. However, they do end up generating .bed files that contain
the `None` values (e.g., at the beginning of the block the start position will
be `None` and the end will be an actual position, and at the end of the block
there will be a position and a `None`). We concatenated all the
chromosome-wise .bed files into a genome-wide .bed using the following
bash script (these are the .bed files in the data directory of this repository).

```sh

awk '!/None/ {print $0}' chr1.bed > EUR_LD_blocks.bed
for $f in chr{2..22}.bed; do tail -n +2 $f | awk '!/None/ {print $0}' >> EUR_LD_blocks.bed; done

```

