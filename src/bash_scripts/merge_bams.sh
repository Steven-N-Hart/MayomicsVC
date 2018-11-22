#!/bin/bash

#-------------------------------------------------------------------------------------------------------------------------------
## merge_bams.sh MANIFEST, USAGE DOCS, SET CHECKS
#-------------------------------------------------------------------------------------------------------------------------------

read -r -d '' MANIFEST << MANIFEST

*****************************************************************************
`readlink -m $0`
called by: `whoami` on `date`
command line input: ${@}
*****************************************************************************

MANIFEST
echo -e "${MANIFEST}"







read -r -d '' DOCS << DOCS

#############################################################################
#
# Merge bams produced in alignment  
# 
#############################################################################

 USAGE:
 merge_bams.sh     -s           <sample_name> 
                   -b		<lane1_aligned.sorted.bam[,lane2_aligned.sorted.bam,...]>
                   -S           </path/to/sentieon> 
                   -t           <threads> 
                   -e           </path/to/env_profile_file>
                   -d           turn on debug mode

 EXAMPLES:
 merge_bams.sh -h
 merge_bams.sh -s sample -b lane1.aligned.sorted.bam,lane2.aligned.sorted.bam,lane3.aligned.sorted.bam -S /path/to/sentieon_directory -t 12 -e /path/to/env_profile_file -d

#############################################################################

DOCS








set -o errexit
set -o pipefail
set -o nounset

SCRIPT_NAME=merge_bams.sh
SGE_JOB_ID=TBD  # placeholder until we parse job ID
SGE_TASK_ID=TBD  # placeholder until we parse task ID

#-------------------------------------------------------------------------------------------------------------------------------





#-------------------------------------------------------------------------------------------------------------------------------
## LOGGING FUNCTIONS
#-------------------------------------------------------------------------------------------------------------------------------

LOG_PATH="`dirname "$0"`"  ## Parse the directory of this script to locate the logging function script
source ${LOG_PATH}/log_functions.sh

#-------------------------------------------------------------------------------------------------------------------------------





#-------------------------------------------------------------------------------------------------------------------------------
## GETOPTS ARGUMENT PARSER
#-------------------------------------------------------------------------------------------------------------------------------

## Check if no arguments were passed
if (($# == 0))
then
        echo -e "\nNo arguments passed.\n\n${DOCS}\n"
        exit 1
fi

## Input and Output parameters
while getopts ":hs:b:S:t:e:d" OPT
do
        case ${OPT} in
                h )  # Flag to display usage 
                        echo -e "\n${DOCS}\n"
			exit 0
                        ;;
		s )  # Sample name
			SAMPLE=${OPTARG}
			checkArg
			;;
                b )  # Full path to the input BAM or list of BAMS
                        INPUTBAMS=${OPTARG}
			checkArg
                        ;;
                S )  # Full path to sentieon directory
                        SENTIEON=${OPTARG}
			checkArg
                        ;;
                t )  # Number of threads available
                        THR=${OPTARG}
			checkArg
                        ;;
                e )  # Path to file with environmental profile variables
                        ENV_PROFILE=${OPTARG}
                        checkArg
                        ;;
                d )  # Turn on debug mode. Initiates 'set -x' to print all text. Invoked with -d
                        echo -e "\nDebug mode is ON.\n"
			set -x
                        ;;
		\? )  # Check for unsupported flag, print usage and exit.
                        echo -e "\nInvalid option: -${OPTARG}\n\n${DOCS}\n"
                        exit 1
                        ;;
                : )  # Check for missing arguments, print usage and exit.
                        echo -e "\nOption -${OPTARG} requires an argument.\n\n${DOCS}\n"
                        exit 1
                        ;;
        esac
done

#-------------------------------------------------------------------------------------------------------------------------------





#-------------------------------------------------------------------------------------------------------------------------------
## PRECHECK FOR INPUTS AND OPTIONS
#-------------------------------------------------------------------------------------------------------------------------------

## Check if Sample Name variable exists
if [[ -z ${SAMPLE+x} ]] ## NOTE: ${VAR+x} is used for variable expansions, preventing unset variable error from set -o nounset. When $VAR is not set, we set it to "x" and throw the error.
then
        echo -e "$0 stopped at line ${LINENO}. \nREASON=Missing sample name option: -s"
        exit 1
fi

## Create log for JOB_ID/script
ERRLOG=${SAMPLE}.merge_bams.${SGE_JOB_ID}.log
truncate -s 0 "${ERRLOG}"
truncate -s 0 ${SAMPLE}.merge_sentieon.log

## Write manifest to log
echo "${MANIFEST}" >> "${ERRLOG}"

## source the file with environmental profile variables
if [[ ! -z ${ENV_PROFILE+x} ]]
then
        source ${ENV_PROFILE}
else
        EXITCODE=1
        logError "$0 stopped at line ${LINENO}. \nREASON=Missing environmental profile option: -e"
fi

## Check if input files, directories, and variables are non-zero
if [[ -z ${INPUTBAMS+x} ]]
then
        EXITCODE=1
        logError "$0 stopped at line ${LINENO}. \nREASON=Missing input BAM option: -b"
fi
for LANE in $(echo ${INPUTBAMS} | sed "s/,/ /g")
do
	if [[ ! -s ${LANE} ]]
	then 
		EXITCODE=1
        	logError "$0 stopped at line ${LINENO}. \nREASON=Input sorted BAM file ${LANE} is empty or does not exist."
	fi
	if [[ ! -s ${LANE}.bai ]]
	then
		EXITCODE=1
        	logError "$0 stopped at line ${LINENO}. \nREASON=Sorted BAM index file ${LANE}.bai is empty or does not exist."
	fi
done
if [[ -z ${SENTIEON+x} ]]
then
        EXITCODE=1
        logError "$0 stopped at line ${LINENO}. \nREASON=Missing Sentieon path option: -S"
fi
if [[ ! -d ${SENTIEON} ]]
then
	EXITCODE=1
        logError "$0 stopped at line ${LINENO}. \nREASON=Sentieon directory ${SENTIEON} is not a directory or does not exist."
fi
if [[ -z ${THR+x} ]]
then
        EXITCODE=1
        logError "$0 stopped at line ${LINENO}. \nREASON=Missing threads option: -t"
fi

#-------------------------------------------------------------------------------------------------------------------------------





#-------------------------------------------------------------------------------------------------------------------------------
## FILENAME PARSING
#-------------------------------------------------------------------------------------------------------------------------------

## Defining file names
BAMS=`sed -e 's/,/ -i /g' <<< ${INPUTBAMS}`  ## Replace commas with spaces
MERGED_BAM=${SAMPLE}.aligned.sorted.bam

#-------------------------------------------------------------------------------------------------------------------------------





#-------------------------------------------------------------------------------------------------------------------------------
## BAM Merging
#-------------------------------------------------------------------------------------------------------------------------------

## Record start time
logInfo "[SENTIEON] Merging BAMs using Sentieon ReadWrite."

## Read Writer bam merge command
TRAP_LINE=$(($LINENO + 1))
trap 'logError " $0 stopped at line ${TRAP_LINE}. Sentieon BAM merging error. " ' INT TERM EXIT
${SENTIEON}/bin/sentieon driver -t ${THR} -i ${BAMS} --algo ReadWriter ${MERGED_BAM} >> ${SAMPLE}.merge_sentieon.log 2>&1
EXITCODE=$?
trap - INT TERM EXIT

if [[ ${EXITCODE} -ne 0 ]]
then
	logError "$0 stopped at line ${LINENO} with exit code ${EXITCODE}."
fi
logInfo "[SENTIEON] BAM merging complete."

#-------------------------------------------------------------------------------------------------------------------------------





#-------------------------------------------------------------------------------------------------------------------------------
## POST-PROCESSING
#-------------------------------------------------------------------------------------------------------------------------------

## Check for creation of output BAM and index. Open read permissions to the user group
if [[ ! -s ${MERGED_BAM} ]]
then
	EXITCODE=1
        logError "$0 stopped at line ${LINENO}. \nREASON=Output merged BAM file ${MERGED_BAM} is empty."
fi
if [[ ! -s ${MERGED_BAM}.bai ]]
then
	EXITCODE=1
        logError "$0 stopped at line ${LINENO}. \nREASON=Output merged BAM index file ${MERGED_BAM}.bai is empty."
fi

chmod g+r ${MERGED_BAM}
chmod g+r ${MERGED_BAM}.bai

#-------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------------------------------------
## END
#-------------------------------------------------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------------------------------------
exit 0;
