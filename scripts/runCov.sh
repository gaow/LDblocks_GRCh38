## Copyright 2022 University of Washington

## Permission is hereby granted, free of charge, to any person obtaining
## a copy of this software and associated documentation files (the
## "Software"), to deal in the Software without restriction, including
## without limitation the rights to use, copy, modify, merge, publish,
## distribute, sublicense, and/or sell copies of the Software, and to
## permit persons to whom the Software is furnished to do so, subject to
## the following conditions:

## The above copyright notice and this permission notice shall be
## included in all copies or substantial portions of the Software.

## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
## EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
## MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
## NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
## LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
## OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
## WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


#!/bin/sh

#$ -q lindstroem.q
#$ -cwd
#$ -l h_vmem=20G
#$ -t 101-105


source ../venv/bin/activate
export PYTHONPATH=/projects/lindstroem/.py-site-packages/

fn=$1
chr=${fn/_partitions/}
chr=${chr/scripts\//}
vcf=$2
map=$3
indfile=$4
pop=$5
popsize=$6

## get the row of the partition file and read into an array
inline=(`awk "NR==$SGE_TASK_ID" $fn`)
start=${inline[0]}
stop=${inline[1]}


tabix -h "$vcf" "$chr":"$start"-"$stop" | python3 ../P00_01_calc_covariance.py "$map" "$indfile" "$popsize" 1e-7 "$pop"/"$chr"/"$chr"."$start"."$stop".gz 
