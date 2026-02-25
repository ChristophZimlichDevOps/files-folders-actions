#!/bin/bash

## Creator: Christoph Zimlich
##
##
## Summary
## This script will check the source and folders for copying to prevent cross copying. Useful for backups for example.
##
## Parameter  1: PID Full Path i.e.     "/var/run/test.pid"
## Parameter  2: PID i.e.               "54895"
## Parameter  3: Folder Source i.e.     "/home/backup/mysql/"
## Parameter  4: Folder Target i.e.     "/tmp/bash/test/"
## Parameter  5: Sys log i.e.           "/var/log/bash/$file_name.log"
## Parameter  6: Job log i.e.           "/tmp/bash/$file_name.log"
## Parameter  7: Output Switch          0=Console
##                                      1=Logfile; Default
## Parameter  8: Verbose Switch         0=Off
##                                      1=On; Default
##
## Call it like this:
## sh files-folders-cp-pid-create.sh "/var/run/files-folders-cp-pid-create.pid" "51822" "/home/.backup/mysql/" "/tmp/" "0" "1"


## Clear console to debug that stuff better
#clear

## Enhanced debugging with set -x
#set -x

## Set Stuff
version="0.0.1-alpha.1"
file_name_full="files-folders-cp-pid-create.sh"
file_name="${file_name_full%.*}"

run_as_user_name=$(whoami)
run_as_user_uid=$(id -u "$run_as_user_name")
run_as_group_name=$(id -gn "$run_as_user_name")
run_as_group_gid=$(getent group "$run_as_group_name" | cut -d: -f3)
run_on_hostname=$(hostname -f)

## Set the job config FILE from parameter
config_file_in="$HOME/bin/linux/shell/files-folders-actions/$file_name.conf.in"
echo "Using config file $config_file_in for $file_name_full"

## Check this script is running as root !
if [ "$run_as_user_uid" != "0" ]; then
    echo "!!! ATTENTION !!!		    YOU MUST RUN THIS SCRIPT AS ROOT / SUPERUSER	        !!! ATTENTION !!!"
    echo "!!! ATTENTION !!!		           TO USE chown AND chmod IN rsync	                !!! ATTENTION !!!"
    echo "!!! ATTENTION !!!		     ABORT THIS SCRIPT IF YOU NEED THIS FEATURES		    !!! ATTENTION !!!"
fi

## Only one instance of this script should ever be running and as its use is normally called via cron, if it's then run manually
## for test purposes it may intermittently update the ports.tcp & ports.udp files unnecessarily. So here we check no other instance
## is running. If another instance is running we pause for 5 seconds and then delete the PID anyway. Normally this script will run
## in under 150ms and via cron runs every 60 seconds, so if the PID file still exists after 5 seconds then it's a orphan PID file.
if [ -f "$PID_PATH_FULL" ]; then
        sleep 5 #if PID file exists wait 3 seconds and test again, if it still exists delete it and carry on
        echo "There appears to be another Process $file_name PID $PID_PATH_FULL is already running, waiting for 5 seconds ..."
        rm -f -- "$PID_PATH_FULL"
fi
trap 'rm -f -- $PID_PATH_FULL' EXIT #EXIT STATUS=0/SUCCESS)
echo $$ > "$PID_PATH_FULL"

## Clear needed stuff
declare    PID_PATH_FULL
declare -i PID
declare    FOLDER_SOURCE
declare    FOLDER_TARGET
declare    SYS_LOG
declare    JOB_LOG
declare -i OUTPUT_SWITCH
declare -i VERBOSE_SWITCH
## Clear stuff for processing
declare -i sys_log_file_missing_switch
declare -i job_log_file_missing_switch
declare -i status
declare -a pids_tmp
declare -a pids_source
declare -a pids_target

set -o allexport
# shellcheck source=$config_file_in disable=SC1091
. "$config_file_in"
set +o allexport

## Check for arguments
#PID_PATH_FULL=$1
#PID=$2
#FOLDER_SOURCE=$3
#FOLDER_TARGET=$4
#SYS_LOG=$5
#JOB_LOG=$6
#OUTPUT_SWITCH=$7
#VERBOSE_SWITCH=$8

#if [ -f "$PID_PATH_FULL" ]; then echo "PID file $PID_PATH_FULL not found. EXIT";EXIT STATUS=2/FAILURE;fi
if [ "$PID" = "" ]; then
        echo "PID Process ID is empty"
        exit 2
fi

if [ ! -d "$FOLDER_SOURCE" ]; then
        echo "Folder Source parameter $FOLDER_SOURCE is not a valid folder path. EXIT"
        exit 2
fi
if [ ! -d "$FOLDER_TARGET" ]; then
        echo "Folder Target parameter $FOLDER_TARGET is not a valid folder path. EXIT"
        exit 2
fi

# Check if $run_as_user_name:$run_as_group_name have write access to log FILEs
if [ ! -w "${SYS_LOG%/*}" ] || [[ ! -w "${JOB_LOG%/*}" && "$OUTPUT_SWITCH" -eq '0' ]]; then
    if [ ! -w "${SYS_LOG%/*}" ]; then
        echo "$run_as_user_name:$run_as_group_name don't have write access for syslog FILE $SYS_LOG."
    fi
    if [ ! -w "${JOB_LOG%/*}" ] && [ "$OUTPUT_SWITCH" -eq '0' ]; then
        echo "$run_as_user_name:$run_as_group_name don't have write access for job log FILE $JOB_LOG."
    fi
    echo "Please check the job config FILE $config_file_in. EXIT";exit 2
fi

## Set log files
if [ ! -f "$JOB_LOG" ]; then
        job_log_file_missing_switch=1
        touch "$JOB_LOG"
else
        job_log_file_missing_switch=0
fi
if [ ! -f "$SYS_LOG" ]; then
        sys_log_file_missing_switch=1
        touch "$SYS_LOG"
else
        sys_log_file_missing_switch=0
fi

if [ "$OUTPUT_SWITCH" -eq '1' ]; then
        exec 3>&1 4>&2
        trap 'exec 2>&4 1>&3' 0 1 2 3 RETURN
        exec 1>>"$SYS_LOG" 2>&1
fi

## Print file name
if [ "$VERBOSE_SWITCH" -eq '1' ]; then
        if [ "$OUTPUT_SWITCH" -eq '1' ]; then
	        sh output-styler "start"
        	sh output-styler "start"
                echo ">>> Sub Module $file_name_full v$version starting >>>"
        fi
        sh output-styler "start"
	sh output-styler "start"
	sh output-styler "middle"
	echo "!!! ATTENTION !!!		Parameter 3: Name Part Old i.e. current*					   !!! ATTENTION !!!"
        echo "!!! ATTENTION !!!		ONLY wildcards at the beginning and at the end with other real content will work   !!! ATTENTION !!!"
        echo "!!! ATTENTION !!!		ONLY wildcards with no other real content will NOT work				   !!! ATTENTION !!!"
	echo "Filename: $file_name_full"
        echo "Version: v$version"
        echo "Run as user name: $run_as_user_name"
        echo "Run as user uid: $run_as_user_uid"
        echo "Run as group: $run_as_group_name"
        echo "Run as group gid: $run_as_group_gid"
        echo "Run on host: $run_on_hostname"
	echo "PID file: $PID_PATH_FULL"
        echo "PID: $PID"
	echo "Folder Source: $FOLDER_SOURCE"
        echo "Folder Target: $FOLDER_TARGET"
        echo "Verbose is ON"

        if [ "$job_log_file_missing_switch" -eq '1' ]; then
                echo "Job log file: $JOB_LOG is missing"
                echo "Creating it at $JOB_LOG"
        fi

        if [ "$sys_log_file_missing_switch" -eq '1' ]; then
                echo "Sys log file: $SYS_LOG is missing"
                echo "Creating it at $SYS_LOG"
        fi

        if [ $OUTPUT_SWITCH -eq '0' ]; then
                echo "Output to console...As $run_as_user_name:$run_as_group_name can see ;)"
	else
		echo "Output to sys log file $SYS_LOG"
		echo "Output to job log file $JOB_LOG"
	fi
fi

FOLDER_SOURCE_1=$(echo "$FOLDER_SOURCE" | cut -d/ -f2)
FOLDER_SOURCE_2=$(echo "$FOLDER_SOURCE" | cut -d/ -f3)
FOLDER_SOURCE_3=$(echo "$FOLDER_SOURCE" | cut -d/ -f4)
FOLDER_SOURCE_4=$(echo "$FOLDER_SOURCE" | cut -d/ -f5)
FOLDER_SOURCE_5=$(echo "$FOLDER_SOURCE" | cut -d/ -f6)
FOLDER_SOURCE_6=$(echo "$FOLDER_SOURCE" | cut -d/ -f7)
FOLDER_SOURCE_7=$(echo "$FOLDER_SOURCE" | cut -d/ -f8)
FOLDER_SOURCE_8=$(echo "$FOLDER_SOURCE" | cut -d/ -f9)
FOLDER_SOURCE_9=$(echo "$FOLDER_SOURCE" | cut -d/ -f10)

FOLDER_TARGET_1=$(echo "$FOLDER_TARGET" | cut -d/ -f2)
FOLDER_TARGET_2=$(echo "$FOLDER_TARGET" | cut -d/ -f3)
FOLDER_TARGET_3=$(echo "$FOLDER_TARGET" | cut -d/ -f4)
FOLDER_TARGET_4=$(echo "$FOLDER_TARGET" | cut -d/ -f5)
FOLDER_TARGET_5=$(echo "$FOLDER_TARGET" | cut -d/ -f6)
FOLDER_TARGET_6=$(echo "$FOLDER_TARGET" | cut -d/ -f7)
FOLDER_TARGET_7=$(echo "$FOLDER_TARGET" | cut -d/ -f8)
FOLDER_TARGET_8=$(echo "$FOLDER_TARGET" | cut -d/ -f9)
FOLDER_TARGET_9=$(echo "$FOLDER_TARGET" | cut -d/ -f10)

## Lets roll
if [ -f "$PID_PATH_FULL" ]; then
        pids_string_full="cat $PID_PATH_FULL"

        pids_tmp=( $( cat "$PID_PATH_FULL") )
        echo "Count Array pids_tmp ${#pids_tmp[@]}"
	for item in "${pids_tmp[@]}"
        do
                echo "Array pids_tmp: $item"
        done

        #pids_tmp=$(${pids_string_full})
        pids_source=( $(echo "${pids_tmp[@]}" | awk '{print substr($2, index($0,$1))}') )
        pids_target=( $(echo "${pids_tmp[@]}" | awk '{print $NF}') )

        echo "Count Array pids_source ${#pids_source[@]}"
	for item in "${pids_source[@]}"
        do
                echo "Array pids_source: $item"
        done

        echo "Count Array pids_target ${#pids_target[@]}"
	for item in "${pids_target[@]}"
        do
                echo "Array files: $item"
        done

        if [ $VERBOSE_SWITCH -eq '1' ]; then
                echo "PIDs String Full: $pids_string_full"
                echo "Stating comparing the folders"
                echo "Max Folder Deep for check is 9"
        fi
        ## Split PIDs source and compare folders
        found_switch=0
        for pid_source in "${pids_source[@]}"
        do
		pid_source_folder_1=$(echo "$pid_source" | cut -d/ -f2)
                pid_source_folder_2=$(echo "$pid_source" | cut -d/ -f3)
                pid_source_folder_3=$(echo "$pid_source" | cut -d/ -f4)
                pid_source_folder_4=$(echo "$pid_source" | cut -d/ -f5)
                pid_source_folder_5=$(echo "$pid_source" | cut -d/ -f6)
                pid_source_folder_6=$(echo "$pid_source" | cut -d/ -f7)
                pid_source_folder_7=$(echo "$pid_source" | cut -d/ -f8)
                pid_source_folder_8=$(echo "$pid_source" | cut -d/ -f9)
                pid_source_folder_9=$(echo "$pid_source" | cut -d/ -f10)
                ## Split PIDs target and compare folders
                for pid_target in "${pids_target[@]}"
                do
                	pid_target_folder_1=$(echo "$pid_target" | cut -d/ -f2)
                	pid_target_folder_2=$(echo "$pid_target" | cut -d/ -f3)
                	pid_target_folder_3=$(echo "$pid_target" | cut -d/ -f4)
                	pid_target_folder_4=$(echo "$pid_target" | cut -d/ -f5)
                	pid_target_folder_5=$(echo "$pid_target" | cut -d/ -f6)
                	pid_target_folder_6=$(echo "$pid_target" | cut -d/ -f7)
                	pid_target_folder_7=$(echo "$pid_target" | cut -d/ -f8)
                	pid_target_folder_8=$(echo "$pid_target" | cut -d/ -f9)
                	pid_target_folder_9=$(echo "$pid_target" | cut -d/ -f10)

			if [ $VERBOSE_SWITCH -eq '1' ]; then
                                echo "Working on Folder Source $FOLDER_SOURCE and PID Target $pid_target"
                        fi
			## Compare $FOLDER_SOURCE with pids_target and a folder deep of 9
                        if [ "$FOLDER_SOURCE_1" != "$pid_target_folder_1" ]; then found_switch=0; else
				if [ "$FOLDER_SOURCE_2" != "$pid_target_folder_2" ] && [ "$FOLDER_SOURCE_2" != "" ] && [ "$pid_target_folder_2" != "" ]; then found_switch=0; else
	                                if [ "$FOLDER_SOURCE_3" != "$pid_target_folder_3" ] && [ "$FOLDER_SOURCE_3" != "" ] && [ "$pid_target_folder_3" != "" ]; then found_switch=0; else
						if [ "$FOLDER_SOURCE_4" != "$pid_target_folder_4" ] && [ "$FOLDER_SOURCE_4" != "" ] && [ "$pid_target_folder_4" != "" ]; then found_switch=0; else
							if [ "$FOLDER_SOURCE_5" != "$pid_target_folder_5" ] && [ "$FOLDER_SOURCE_5" != "" ] && [ "$pid_target_folder_5" != "" ]; then found_switch=0; else
	                                                        if [ "$FOLDER_SOURCE_6" != "$pid_target_folder_6" ] && [ "$FOLDER_SOURCE_6" != "" ] && [ "$pid_target_folder_6" != "" ]; then found_switch=0; else
		                                                        if [ "$FOLDER_SOURCE_7" != "$pid_target_folder_7" ] && [ "$FOLDER_SOURCE_7" != "" ] && [ "$pid_target_folder_7" != "" ]; then found_switch=0; else
			                                                        if [ "$FOLDER_SOURCE_8" != "$pid_target_folder_8" ] && [ "$FOLDER_SOURCE_8" != "" ] && [ "$pid_target_folder_8" != "" ]; then found_switch=0; else
				                                                        if [ "$FOLDER_SOURCE_9" != "$pid_target_folder_9" ] && [ "$FOLDER_SOURCE_9" != "" ] && [ "$pid_target_folder_9" != "" ]; then
											found_switch=0; else found_switch=1;fi
										found_switch=1;fi
									found_switch=1;fi
								found_switch=1;fi
							found_switch=1;fi
						found_switch=1;fi
					found_switch=1;fi
				found_switch=1;fi
			found_switch=1;fi

                        if [ $VERBOSE_SWITCH -eq '1' ]; then
                        echo "Working on Folder Target $FOLDER_TARGET and PID Source $pid_source"
                        fi
			## Compare $FOLDER_TARGET with pids_source and a folder deep of 9
                        if [ "$FOLDER_TARGET_1" != "$pid_source_folder_1" ]; then found_switch=0; else
                                if [ "$FOLDER_TARGET_2" != "$pid_source_folder_2" ] && [ "$FOLDER_TARGET_2" != "" ] && [ "$pid_source_folder_2" != "" ]; then found_switch=0; else
                                        if [ "$FOLDER_TARGET_3" != "$pid_source_folder_3" ] && [ "$FOLDER_TARGET_3" != "" ] && [ "$pid_source_folder_3" != "" ]; then found_switch=0; else
                                                if [ "$FOLDER_TARGET_4" != "$pid_source_folder_4" ] && [ "$FOLDER_TARGET_4" != "" ] && [ "$pid_source_folder_4" != "" ]; then found_switch=0; else
                                                        if [ "$FOLDER_TARGET_5" != "$pid_source_folder_5" ] && [ "$FOLDER_TARGET_5" != "" ] && [ "$pid_source_folder_5" != "" ]; then found_switch=0; else
                                                                if [ "$FOLDER_TARGET_6" != "$pid_source_folder_6" ] && [ "$FOLDER_TARGET_6" != "" ] && [ "$pid_source_folder_6" != "" ]; then found_switch=0; else
                                                                        if [ "$FOLDER_TARGET_7" != "$pid_source_folder_7" ] && [ "$FOLDER_TARGET_7" != "" ] && [ "$pid_source_folder_7" != "" ]; then found_switch=0; else
                                                                                if [ "$FOLDER_TARGET_8" != "$pid_source_folder_8" ] && [ "$FOLDER_TARGET_8" != "" ] && [ "$pid_source_folder_8" != "" ]; then found_switch=0; else
                                                                                        if [ "$FOLDER_TARGET_9" != "$pid_source_folder_9" ] && [ "$FOLDER_TARGET_9" != "" ] && [ "$pid_source_folder_9" != "" ]; then
											found_switch=0; else found_switch=1;fi
                                                                                found_switch=1;fi
                                                                        found_switch=1;fi
                                                                found_switch=1;fi
                                                        found_switch=1;fi
                                                found_switch=1;fi
                                        found_switch=1;fi
                                found_switch=1;fi
                        found_switch=1;fi

                        if [ $found_switch -eq '1' ]; then
                                break
                                break
                        fi
                done
        done
        if [ $found_switch -eq '1' ]; then
		if [ $VERBOSE_SWITCH -eq '1' ]; then
			echo "!!! Cross Copy Match found !!!"
			echo "!!! Folder Source $FOLDER_SOURCE and PID Target $pid_target are the same or is a Subfolder!!!"
			echo "!!! OR !!!"
		        echo "!!! Folder Target $FOLDER_TARGET and PID Source $pid_source are the same or is a Subfolder!!!"
                fi
                echo "Match found...Cross copying is not allowed. Please wait until the other job is finished. EXIT"
                exit 99 #sleep 10
        else
                if [ $VERBOSE_SWITCH -eq '1' ]; then
			echo "No Cross Copy Match found in PID $PID_PATH_FULL Folder Source $FOLDER_SOURCE Folder Target $FOLDER_TARGET"
		        echo "Updating PID $PID_PATH_FULL PID Process ID $PID Folder Source $FOLDER_SOURCE Folder Target $FOLDER_TARGET"
                fi
		echo "$PID" "$FOLDER_SOURCE" "$FOLDER_TARGET" >> "$PID_PATH_FULL"
        fi
## If no PID exists... create it
else
        if [ $VERBOSE_SWITCH -eq '1' ]; then
                echo "NO PID $PID_PATH_FULL found"
                echo "Creating PID $PID_PATH_FULL PID Process ID $PID"
                echo "Folder Source $FOLDER_SOURCE"
                echo "Folder Target $FOLDER_TARGET"
        fi
        echo "$PID" "$FOLDER_SOURCE" "$FOLDER_TARGET" > "$PID_PATH_FULL"
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
        sh output-styler "middle"
        sh output-styler "end"
fi

## Check last task for errors
status=$?
if [ $status != 0 ]; then
	if [ $VERBOSE_SWITCH -eq '1' ]; then
                sh output-styler "error"
        fi
        echo "!!! Error Sub Module $file_name_full from $FOLDER_SOURCE to $FOLDER_TARGET, code=$status !!!"
        if [ $VERBOSE_SWITCH -eq '1' ]; then
                echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
		sh output-styler "error"
		sh output-styler "end"
	        sh output-styler "end"
        fi
        exit $status
else
        if [ $VERBOSE_SWITCH -eq '1' ]; then
                echo "<<< Sub Module $file_name_full v$version finished successfully <<<"
	        sh output-styler "end"
	        sh output-styler "end"
        fi
        exit $status
fi
