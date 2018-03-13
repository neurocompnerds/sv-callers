rule gridss:
    input:
        fasta = get_fasta(),
        fai = get_faidx(),  # bwa index files also required
        tumor_bam = "{path}/{tumor}" + get_filext("bam"),
        tumor_bai = "{path}/{tumor}" + get_filext("bam_idx"),
        normal_bam = "{path}/{normal}" + get_filext("bam"),
        normal_bai = "{path}/{normal}" + get_filext("bam_idx")
    output:
        log = os.path.join("{path}", "{tumor}--{normal}", get_outdir("gridss"),
                           "{rule}.log")
    conda:
        "../environment.yaml"
    threads:
        get_nthreads("gridss")
    resources:
        mem_mb = get_memory("gridss"),
        tmp_mb = get_tmpspace("gridss")
    shell:
        """
        # if 'tmpspace' set to >0MB use TMPDIR otherwise use OUTDIR
        OUTDIR="$(dirname "{output}")"
        TMP=$([ "{resources.tmp_mb}" = "0" ] &&
            echo "${{OUTDIR}}" || echo "${{TMPDIR}}")

        # set JVM max. heap size dynamically (in GB)
        # N.B. take into account 'Compressed Oops'!!!
        MAX_HEAP=$(printf "%.f" $(bc <<< "scale=2;.8*{resources.mem_mb}/1024"))
        MAX_HEAP=$([[ "${{MAX_HEAP}}" -gt "31" &&
            "${{MAX_HEAP}}" -lt "49" ]] && echo "49g" || echo "${{MAX_HEAP}}g")

        # run dummy or real job
        if [ "{config[echo_run]}" -eq "1" ]; then
            echo "{input}" "${{TMP}}" > "{output}"
        else
            # clean-up outdir prior to SV calling
            rm -fr "${{TMP}}/*gridss*" "{input.fasta}.dict" &&
            gridss -Xmx${{MAX_HEAP}} gridss.CallVariants \
                WORKER_THREADS={threads} \
                REFERENCE_SEQUENCE="{input.fasta}" \
                INPUT="{input.normal_bam}" \
                INPUT="{input.tumor_bam}" \
                OUTPUT="${{OUTDIR}}/gridss.vcf" \
                ASSEMBLY="${{OUTDIR}}/gridss_assembly.bam" \
                WORKING_DIR="${{OUTDIR}}" \
                TMP_DIR="${{TMP}}/gridss.${{RANDOM}}" 2>&1
            date "+%Y-%m-%d %H:%M:%S" > "{output}"
        fi
        """