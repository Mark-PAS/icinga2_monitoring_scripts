#!/bin/bash
#----------check_iostat.sh-----------
#
# Version 0.0.2 - Jan/2009
# Changes: added device verification
#
# by Thiago Varela - thiago@iplenix.com
#
# Version 0.0.3 - Dec/2011
# Changes:
# - changed values from bytes to mbytes
# - fixed bug to get traffic data without comma but point
# - current values are displayed now, not average values (first run of iostat)
#
# by Philipp Niedziela - pn@pn-it.com
#
# Version 0.0.4 - April/2014
# Changes:
# - Allow Empty warn/crit levels
# - Can check I/O, WAIT Time, or Queue
#
# by Warren Turner
#
# Version 0.0.5 - Jun/2014
# Changes:
# - removed -y flag from call since iostat doesn't know about it any more (June 2014)
# - only needed executions of iostat are done now (save cpu time whenever you can)
# - fixed the obvious problems of missing input values (probably because of the now unimplemented "-y") with -x values
# - made perfomance data optional (I like to have choice in the matter)
#
# by Frederic Krueger / fkrueger-dev-checkiostat@holics.at
#
# Version 0.0.6 - Jul/2014
# Changes:
# - Cleaned up argument checking, removed excess iostat calls, steamlined if statements and renamed variables to fit current use
# - Fixed all inputs to match current iostat output (Ubuntu 12.04)
# - Changed to take last ten seconds as default (more useful for nagios usage). Will go to "since last reboot" (previous behaviour) on -g flag.
# - added extra comments/whitespace etc to make add readability
#
# by Ben Field / ben.field@concreteplatform.com
#
# Version 0.0.7 - Sep/2014
# Changes:
# - Fixed performance data for Wait check
#
# by Christian Westergard / christian.westergard@gmail.com
#
# Version 0.0.8 - Jan/2019
# Changes:
# - Added Warn/Crit thresholds to performance output
#
# by Danny van Zunderd / danny_vz@live.nl
#
# Version 0.0.9 - Jun/2020
# Changes:
# - Updated to use bash 4.4 mechanisms
#
# by Joseph Waggy / joseph.waggy@gmail.com
# Version 0.1.0 Sept 2021
# Changes:
# - correct misaligned fields
# - renaming / parser changes
#
# by Mark Perkins / mark@perkinsadministrationservices.com.au
# Version 0.1.1 Apr 2023
# Changes:
# - complete re-write of the parser logic to improve immunity
#   to changes in field names and layouts
# - removed -d --Device option as incompatible with parser logic changes
# - removed -W = Wait Time Mode option as not present in sysstat version 11.7.3
iostat=$(which iostat 2>/dev/null)
bc=$(which bc 2>/dev/null)

help()
{
echo -e "
Usage:

-i = CPU utilization report

-q = device utilization report

-w,-c = pass warning and critical levels respectively. These are not required, but with out them, all queries will return as OK.

-p = Provide performance data for later graphing

-g = Since last reboot for system

-h = This help
"
}

# Ensuring we have the needed tools:
if [[ ! -f $iostat ]] || [[ ! -f $bc ]]; then
echo -e "ERROR: You must have iostat and bc installed in order to run this plugin\n"
exit -1
fi

io=0
queue=0
waittime=0
printperfdata=0
STATE="OK"
samples=2
STATUS=0

MSG=""
PERFDATA=" | "

#------------Argument Set-------------

while getopts "w:c:ipqhg" OPT; do
case $OPT in
"w")
warning=$OPTARG
;;
"c")
critical=$OPTARG
;;
"i")
io=1
;;
"p")
printperfdata=1
;;
"q")
queue=1
;;
"g")
samples=1
;;
"h")
echo "help:"
help
exit 0
;;
\?)
echo "Invalid option: -$OPTARG" >&2
help
exit -1
;;
esac
done

PERF_INDEX=0
IFS=, read -ers -a WARN < <(echo ${warning})
IFS=, read -ers -a CRIT < <(echo ${critical})
unset IFS

#------------Argument Set End-------------

# iostat parameters:
# -m: megabytes
# -k: kilobytes
# first run of iostat shows statistics since last reboot, second one shows current vaules of hdd
# -d is the duration for second run, -x the rest

if [[ ${#WARN[@]} -ne ${#CRIT[@]} ]]; then
echo "ERR: mismatched quantity between warn and crit values"
exit -1
fi

CAPTURE=$($iostat $disk -x -k 10 $samples)

mapfile -t CAPTURE_ARRAY_ROWS < <(echo "${CAPTURE}")
CAPTURE_LEN=${#CAPTURE_ARRAY_ROWS[@]}
BLOCK_LEN=$((${CAPTURE_LEN} - 1))
BLOCK_LEN=$((${BLOCK_LEN} / $samples))
START_ROW=$(($samples - 1))
START_ROW=$((${START_ROW} * ${BLOCK_LEN}))
START_ROW=$((${START_ROW} + 2))
DISK_POS_COUNT=$((${BLOCK_LEN} - 6))
read -ers -a CPU_HEADER < <(echo ${CAPTURE_ARRAY_ROWS[${START_ROW}]})
CPU_HEADER=("${CPU_HEADER[@]:1}") #removed the 1st element which is row descriptor
read -ers -a CPU_RESULTS < <(echo ${CAPTURE_ARRAY_ROWS[$((${START_ROW}+1))]})
INDEX_i=$((${#CPU_HEADER[@]}-1))
for i in `seq 0 ${INDEX_i}`; do

if [[ "$io" == "1" ]] || [[ "$io" == "0" && "$queue" == "0" ]]; then
    MSG+=${CPU_HEADER[i]}
    MSG+="="
    MSG+=${CPU_RESULTS[i]}
    MSG+=", "
    PERFDATA+=${CPU_HEADER[i]}
    PERFDATA+="="
    PERFDATA+=${CPU_RESULTS[i]}
    PERFDATA+=";"

    if [[ $(echo "${PERF_INDEX} < ${#WARN[@]}" | bc) -eq 1 ]]; then # check actually have a value
        if [[ ! -z "${WARN[${PERF_INDEX}]}" ]] || [[ ! -z "${CRIT[${PERF_INDEX}]}" ]]; then 
            if [[ $(echo "${WARN[${PERF_INDEX}]} > ${CRIT[${PERF_INDEX}]}" | bc) -eq 1 ]]; then # sanity check
                echo "ERR: warn threshold exceeds crit threshold"
                exit -1
            fi
        fi
    fi

    if [[ $(echo "${PERF_INDEX} < ${#WARN[@]}" | bc) -eq 1 ]]; then # check actually have a value
        PERFDATA+=${WARN[${PERF_INDEX}]}
        if [[ ! -z "${WARN[${PERF_INDEX}]}" ]]; then
            if [[ $(echo "${CPU_RESULTS[i]} > ${WARN[${PERF_INDEX}]}" | bc) -eq 1 ]]; then
                if [[ $STATUS -lt 1 ]]; then
                    STATUS=1
                fi
            fi
        fi
    fi

    PERFDATA+=";"

    if [[ $(echo "${PERF_INDEX} < ${#CRIT[@]}" | bc) -eq 1 ]]; then # check actually have a value
        PERFDATA+=${CRIT[${PERF_INDEX}]}
        if [[ ! -z "${CRIT[${PERF_INDEX}]}" ]]; then 
            if [[ $(echo "${CPU_RESULTS[i]} > ${CRIT[${PERF_INDEX}]}" | bc) -eq 1 ]]; then
                if [[ $STATUS -lt 2 ]]; then
                    STATUS=2
                fi
            fi
        fi
    fi

    PERFDATA+="; "
    ((PERF_INDEX++))
fi
done

for j in `seq 0 ${DISK_POS_COUNT}`; do
read -ers -a DISK_HEADER < <(echo ${CAPTURE_ARRAY_ROWS[((${START_ROW}+3))]})
DISK_HEADER=("${DISK_HEADER[@]:1}") #removed the 1st element which is row descriptor
read -ers -a DISK_RESULTS < <(echo ${CAPTURE_ARRAY_ROWS[((${START_ROW}+4+${j}))]})
DISK_IDENT=${DISK_RESULTS[0]}
DISK_RESULTS=("${DISK_RESULTS[@]:1}") #removed the 1st element which is row descriptor
INDEX_j=$((${#DISK_HEADER[@]}-1))
for k in `seq 0 ${INDEX_j}`; do

if [[ "$queue" == "1" ]] || [[ "$io" == "0" && "$queue" == "0" ]]; then
    MSG+=${DISK_IDENT}
    MSG+="_"
    MSG+=${DISK_HEADER[k]}
    MSG+="="
    MSG+=${DISK_RESULTS[k]}
    MSG+=", "
    PERFDATA+=${DISK_IDENT}
    PERFDATA+="_"
    PERFDATA+=${DISK_HEADER[k]}
    PERFDATA+="="
    PERFDATA+=${DISK_RESULTS[k]}
    PERFDATA+=";"

    if [[ $(echo "${PERF_INDEX} < ${#WARN[@]}" | bc) -eq 1 ]]; then # check actually have a value
        if [[ ! -z "${WARN[${PERF_INDEX}]}" ]] || [[ ! -z "${CRIT[${PERF_INDEX}]}" ]]; then 
            if [[ $(echo "${WARN[${PERF_INDEX}]} > ${CRIT[${PERF_INDEX}]}" | bc) -eq 1 ]]; then # sanity check
                echo "ERR: warn threshold exceeds crit threshold"
                exit -1
            fi
        fi
    fi

    if [[ $(echo "${PERF_INDEX} < ${#WARN[@]}" | bc) -eq 1 ]]; then # check actually have a value
        PERFDATA+=${WARN[${PERF_INDEX}]}
        if [[ ! -z "${WARN[${PERF_INDEX}]}" ]]; then
            if [[ $(echo "${CPU_RESULTS[i]} > ${WARN[${PERF_INDEX}]}" | bc) -eq 1 ]]; then
                if [[ $STATUS -lt 1 ]]; then
                    STATUS=1
                fi
            fi
        fi
    fi

    PERFDATA+=";"

    if [[ $(echo "${PERF_INDEX} < ${#CRIT[@]}" | bc) -eq 1 ]]; then # check actually have a value
        PERFDATA+=${CRIT[${PERF_INDEX}]}
        if [[ ! -z "${CRIT[${PERF_INDEX}]}" ]]; then
            if [[ $(echo "${CPU_RESULTS[i]} > ${CRIT[${PERF_INDEX}]}" | bc) -eq 1 ]]; then
                if [[ $STATUS -lt 2 ]]; then
                    STATUS=2
                fi
            fi
        fi
    fi

    PERFDATA+="; "
    ((PERF_INDEX++))
fi
done
done


# now output the official result
if [[ $STATUS -eq 2 ]]; then
    STATE="CRITICAl"
elif [[ $STATUS -eq 1 ]]; then
    STATE="WARNING"
else
    STATE="OK"
fi

MSG="${STATE} - ${MSG}"

echo -n "${MSG%??}"
if [[ "x$printperfdata" == "x1" ]]; then
echo -n "$PERFDATA"
fi
echo ""
exit $STATUS
