##########################################################################################################
####              This WDL script is used to run the Alignment steps as individual modules              ##
##########################################################################################################

import "src/wdl_scripts/Alignment/TestTasks/Runtrim_sequences.wdl" as CUTADAPTTRIM
import "src/wdl_scripts/Alignment/TestTasks/Runalignment.wdl" as ALIGNMENT
import "src/wdl_scripts/Alignment/Tasks/dedup.wdl" as DEDUP 

workflow CallAlignmentTasks {
   
   call CUTADAPTTRIM.RunTrimSequencesTask as trimseq 
    
   call ALIGNMENT.RunAlignmentTask as align {
      input:
         InputReads = trimseq.Outputs
   }
   
   call DEDUP.dedupTask as dedup {
      input:
         InputBams = align.OutputBams,
         InputBais = align.OutputBais
   }

   output {
     
      File InputBams = dedup.OutputBams,
      File InputBais = dedup.OutputBais
   }    
    
}