#!/usr/bin/env nextflow

// Define the list of reference and query files
params.REF = false
params.QUERY = false
params.EXT = '.fasta'
params.OUTPUT = false

// Process for running dnadiff and extracting the desired value
process dnaDiff {

    label 'long_process'
    input:
    tuple path(query, stageAs: "query/*"), path(ref, stageAs: "ref/*")

    output:
    tuple val(query_bname), val(ref_bname), env(DNADIFF_RESULT)

    script:
    ref_bname = ref.baseName
    query_bname = query.baseName
    """
    # Run dnadiff
    module load MUMmer
    dnadiff -p temp-${query.fileName.name} $ref $query 2>&1 > temp-${query.fileName.name}.log

    # Extract the desired value using head, tail, and awk
    DNADIFF_RESULT=\$(head -19 temp-${query.fileName.name}.report | tail -1 | awk '{{print \$2}}')

    # Use NR instead of head and tail
    """

    stub:
    ref_bname = ref.baseName
    query_bname = query.baseName
    """
    DNADIFF_RESULT='${ref_bname} ==== ${query_bname}'
    """
}

process export_tsv {
    input:
    val ref_bnames
    val data
    path output

    output:
    path "${output}"

    script:
    ref_bnames = ref_bnames.sort()
    header_row = "\t${ref_bnames.join('\t')}"

    rows = ["${header_row}"]
    data.each {
        refs = it[1]
        query = it[0]
        values = it[2]
        ref_to_val = [refs, values].transpose().collectEntries()
        row = ref_bnames.collect { ref_to_val[it] }
        rows << "${query}\t${row.join('\t')}"
    }
    """
    echo "${rows.join("\n")}" > ${output}
    # send it to a string of may be summarized_table.csv
    """

}
// Create pairs of reference and query samples and run the process for each pair
// Provide the appropriate queue for the cluster
workflow {

    query_files = Channel.fromPath("${params.QUERY}/*${params.EXT}")
    if (params.REF){
        reference_files = Channel.fromPath("${params.REF}/*${params.EXT}")
        file_pairs = query_files.combine(reference_files)
    } else {
        reference_files = Channel.fromPath("${params.QUERY}/*${params.EXT}")
        file_pairs = query_files.combine(reference_files) | unique {it.sort()}
    }

    reference_bnames = reference_files | map { it.baseName } | collect(sort: true)
    data = file_pairs | dnaDiff | groupTuple() | collect(sort: { it[0] }, flat: false)

    // reference_bnames = reference_files | map { it.baseName } | reduce("\t") { a, b -> return "${a}\t${b}" }

    export_tsv(reference_bnames, data, params.OUTPUT)
}