##------------------------------------------------------------------------------
## FAIR script
## Author: T. Denecker & C. Toffano-Nioche
## Affiliation: I2BC
## Aim: A workflow to process RNA-Seq.
## Organism: O. tauri
## Date: Jan 2019
## Step :
## 1- Create tree structure
## 2- Download data from SRA
##------------------------------------------------------------------------------

echo "=============================================================="
echo "Creation of tree structure"
echo "=============================================================="

mkdir Project
mkdir Project/samples
mkdir Project/annotations
mkdir Project/bowtie2
mkdir Project/fastqc
mkdir Project/genome
mkdir Project/graphics
mkdir Project/htseq
mkdir Project/reference
mkdir Project/samtools

echo "=============================================================="
echo "Download data from SRA"
echo "=============================================================="

cd Project/samples

IFS=$'\n'       # make newlines the only separator
for j in $(tail -n +2 ../../conditions.txt)
do
    
    # Get important information from the line
    access=$( echo "$j" | cut -f6 )
    id=$( echo "$j" | cut -f1 )
    md5=$( echo "$j" | cut -f7 )

    echo "--------------------------------------------------------------"
    echo ${id}
    echo "--------------------------------------------------------------"

    # Download file
    wget ${access} # wget method

    # Get md5 of downloaded file
    md5_local="$(md5sum $id.fastq.gz | cut -d' ' -f1)"
    echo $md5_local
    
    # Test md5 
    if [ "$md5_local" == "$md5" ]
    then
        echo "OK"
    else
        echo "Error"
        exit 1
    fi

done

echo "=============================================================="
echo "Download annotations"
echo "=============================================================="

wget https://raw.githubusercontent.com/thomasdenecker/FAIR_Bioinfo/master/Data/O.tauri_annotation.gff -P Project/annotations

echo "=============================================================="
echo "Download genome"
echo "=============================================================="

wget https://raw.githubusercontent.com/thomasdenecker/FAIR_Bioinfo/master/Data/O.tauri_genome.fna -P Project/genome

# List fastq.gz files to be analyzed
dirlist=$(find Project/samples/*.fastq.gz)
# Reference genome
genome="./Project/genome/O.tauri_genome.fna"
# Annotation
annotations="./Project/annotations/O.tauri_annotation.gff"

echo "====================================================================="
echo "Reference genome indexing"
echo "====================================================================="
bowtie2-build ${genome} O_tauri

for file in ${dirlist}
do
    # Name without path
    file_name="$(basename $file)"
    # Name without path nor .gz
    nameFastq="${file_name%.*}"
    # Name without path, .gz nor fastq
    sample="${nameFastq%.*}"

    echo "====================================================================="
    echo "Quality control - Sample: ${sample}"
    echo "====================================================================="
    fastqc Project/samples/${sample}.fastq.gz --outdir Project/fastqc/

    echo "====================================================================="
    echo "Reads Alignement over the reference genome  - Sample: ${sample}"
    echo "====================================================================="
    bowtie2 -x O_tauri -U Project/samples/${sample}.fastq.gz -S Project/bowtie2/bowtie-${sample}.sam 2> Project/bowtie2/bowtie-${sample}.out

    echo "====================================================================="
    echo "Binary conversion, sorting and aligned reads indexing - Sample: ${sample}"
    echo "====================================================================="
    samtools view -b Project/bowtie2/bowtie-${sample}.sam > Project/samtools/bowtie-${sample}.bam
    samtools sort Project/samtools/bowtie-${sample}.bam -o Project/samtools/bowtie-${sample}.sorted.bam
    samtools index Project/samtools/bowtie-${sample}.sorted.bam

    echo "====================================================================="
    echo "Counting - Sample: ${sample}"
    echo "====================================================================="
    htseq-count --stranded=no --type='gene' --idattr='ID' --order=name --format=bam Project/samtools/bowtie-${sample}.sorted.bam ${annotations} > Project/htseq/count-${sample}.txt

    echo "=============================================================="
    echo "Garbage clean up - Sample: ${sample}"
    echo "=============================================================="
    rm -f Project/samtools/bowtie-${sample}.sam Project/bowtie2/bowtie-${sample}.bam

done

cd ../..
