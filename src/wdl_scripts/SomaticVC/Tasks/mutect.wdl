###########################################################################################

##              This WDL script performs tumor/normal Variant Calling  using mutect     ##

##                                Script Options
#               -t        "Number of Threads"                                     (Optional)
#               -G        "Reference Genome"                                      (Required)
#               -T        "Input Sorted Deduped Tumor Bam"                        (Required)
#               -N        "Input Sorted Deduped Normal Bam"                       (Required)
#               -s        "Name of the sample"                                    (Optional)
#               -o        "Mutect Extra Options"                                  (Required)
#               -S        "Path to the Mutect Tool"                               (Required)
#               -e        "Path to the environmental profile                      (Required)
#               -d        "debug mode on/off                        (Optional: can be empty)
#

############################################################################################

task mutectTask {

   File TumorBams                                 # Input Sorted Deduped Tumor Bam
   File TumorBais                                 # Input Sorted Deduped Tumor Bam Index
   File NormalBams                                # Input Sorted Deduped Normal Bam
   File NormalBais                                # Input Sorted Deduped Normal Bam Index

   File Ref                                       # Reference Genome
   File RefFai                                    # Reference Genome index

   String SampleName                              # Name of the Sample

   String MutectExtraOptionsString                # String of extra options for mutect, this can be an empty string

   String Mutect                                  # Path to Mutect 
   String MutectThreads                           # No of Threads for the Tool

   File BashPreamble                              # bash script to source before every task
   File MutectScript                              # Path to bash script called within WDL script
   File MutectEnvProfile                          # File containing the environmental profile variables

   String DebugMode                               # Enable or Disable Debug Mode


   command <<<
        source ${BashPreamble}
        /bin/bash ${MutectScript} -s ${SampleName} -S ${Mutect} -G ${Ref} -t ${MutectThreads} -T ${TumorBams} -N ${NormalBams} -o ${MutectExtraOptionsString} -e ${MutectEnvProfile} ${DebugMode}
   >>>

  output {
      File OutputVcf = "${SampleName}.vcf"
      File OutputVcfIdx = "${SampleName}.vcf.idx"
   }

}