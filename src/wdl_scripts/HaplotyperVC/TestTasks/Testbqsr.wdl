##############################################################

###       This WDL script calls the BQSR WDL Task       ##

##############################################################

import "src/wdl_scripts/HaplotyperVC/Tasks/bqsr.wdl" as BQSR

workflow CallbqsrTask {

   call BQSR.bqsrTask

}
