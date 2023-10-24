#!/usr/bin/env nextflow

nextflow.enable.dsl=2

//includeConfig 'basecalling.config' // Include the configuration file
// run as nextflow run basecalling.nf --ONT_FAST5 /scicomp/home-pure/psg4/storage/projects/abil/davidSue/Mutants/fast5/2022-08-17_Tucker/barcode09 --OUTDIR /scicomp/home-pure/psg4/Pima_nextflow/pima_out

params.OUTDIR = false
params.ONT_FAST5 = false

process basecalling {

    input:
    path ONT_FAST5
    path OUTDIR

    output:
    path "${OUTDIR}/${ONT_FAST5.name}"

    script:
    """
    module load guppy/6.4.6-gpu
    guppy_basecaller -i ${ONT_FAST5} -r -s ${OUTDIR} --num_callers 14 --gpu_runners_per_device 8 --device "cuda:0" -c dna_r9.4.1_450bps_sup.cfg

    """
}

process demultiplexing {

    input:
    path basecalled_fastq
    path OUTDIR

    output:
    path "${OUTDIR}/${basecalled_fastq}"

    script:

    """
    module load guppy/6.4.6-gpu
    guppy_basecaller -i ${basecalled_fastq} -s ${OUTDIR} --trim_barcodes --require_barcodes_both_ends

    """
}

workflow {

basecalling(params.ONT_FAST5, params.OUTDIR)
demultiplexing(basecalling.out, params.OUTDIR)
}
