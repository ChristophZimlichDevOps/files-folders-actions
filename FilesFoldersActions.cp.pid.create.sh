#!/bin/bash

## Creator: Christoph Zimlich
##
##
## Summary
## This script will check the source and target folders for copying to prevent cross copying. Useful for backups for example.
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
## sh FilesFoldersActions.cp.pid.create.sh \
##      "/var/run/FilesFoldersActions.cp.pid.create.pid" \
##      "51822" \
##      "/home/.backup/mysql/" \
##      "/tmp/" \
##      "/var/log/$file_name.log" \
##	"/tmp/$file_name.log" \
##      "0" \
##      "1"


## Clear console to debug that stuff better
#clear

## Enhanced debugging with set -x
#set -x

## Set Stuff
version="0.0.1-alpha.1"
file_name_full="FilesFoldersActions.cp.pid.create.sh"
file_name="${file_name_full%.*}"

run_as_user_name=$(whoami)
run_as_user_uid=$(id -u "$run_as_user_name")
run_as_group_name=$(id -gn "$run_as_user_name")
run_as_group_gid=$(getent group "$run_as_group_name" | cut -d: -f3)
run_on_hostname=$(hostname -f)

## Check this script is running as root !
#if [ "$run_as_user_uid" != "0" ]; then
#    echo "!!! ATTENTION !!!		    YOU MUST RUN THIS SCRIPT AS ROOT / SUPERUSER	        !!! ATTENTION !!!"
#    echo "!!! ATTENTION !!!		           TO USE chown AND chmod IN rsync	                !!! ATTENTION !!!"
#    echo "!!! ATTENTION !!!		     ABORT THIS SCRIPT IF YOU NEED THIS FEATURES		    !!! ATTENTION !!!"
#fi

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
declare    config_file_in
declare -a pids_source
declare -a pids_target
declare -a pids_tmp
declare -i pid_folder_missing_switch
declare -i pid_file_missing_switch=0
declare -i folder_target_missing_switch
declare -i sys_log_folder_missing_switch=0
declare -i sys_log_file_missing_switch=0
declare -i job_log_folder_missing_switch=0
declare -i job_log_file_missing_switch=0
declare -i status

## Check for arguments
PID_PATH_FULL=$1
PID=$2
FOLDER_SOURCE=$3
FOLDER_TARGET=$4
SYS_LOG=$5
JOB_LOG=$6
OUTPUT_SWITCH=$7
VERBOSE_SWITCH=$8

## Set the job config file from parameter
config_file_in="$HOME/bin/linux/shell/local/FilesFoldersActions/$file_name.conf.in"
echo "Using config file $config_file_in for $file_name_full"

## Import stuff from config file
set -o allexport
# shellcheck source=$config_file_in disable=SC1091
. "$config_file_in"
set +o allexport

# Check if $run_as_user_name:$run_as_group_name have write access to log file(s)
if [ "$OUTPUT_SWITCH" -eq '1' ]; then

        # Check if log files are set
        if [ "$SYS_LOG" = "" ]; then
                echo "System Log parameter is empty. EXIT"
                exit 2
        fi
        
        if [ "$JOB_LOG" = "" ]; then
                echo "Job Log parameter is empty. EXIT"
                exit 2
        fi

        if [ ! -d "${SYS_LOG%/*}" ]; then       
                if [ $VERBOSE_SWITCH -eq '1' ]; then
                        mkdir -pv "${SYS_LOG%/*}"
                else
                        mkdir -p "${SYS_LOG%/*}"
                fi

                sys_log_folder_missing_switch=1
                sys_log_file_missing_switch=1
        fi

        # Check if user has write access to sys log file
        if [ ! -w "${SYS_LOG%/*}" ]; then
                echo "$run_as_user_name:$run_as_group_name don't have write access for sys log file $SYS_LOG. EXIT"
        fi

        if [ ! -d "${JOB_LOG%/*}" ]; then       
                if [ $VERBOSE_SWITCH -eq '1' ]; then
                        mkdir -pv "${JOB_LOG%/*}"
                else
                        mkdir -p "${JOB_LOG%/*}"
                fi

                job_log_folder_missing_switch=1
                job_log_file_missing_switch=1
        fi

        # Check if user has write access to job log file
	if [ ! -w "${JOB_LOG%/*}" ]; then
		echo "$run_as_user_name:$run_as_group_name don't have write access for job log file $JOB_LOG."
	fi

        if [ ! -w "${SYS_LOG%/*}" ] || \
	   [ ! -w "${JOB_LOG%/*}" ]; then
		echo "Please check the job config FILE $config_file_in. EXIT"
		exit 2
	fi

	# Set log files
	if [ ! -f "$SYS_LOG" ]; then
		sys_log_file_missing_switch=1
		touch "$SYS_LOG"
	fi

	if [ ! -f "$JOB_LOG" ]; then
		job_log_file_missing_switch=1
		touch "$JOB_LOG"
	fi

	# Mod Output
	exec 3>&1 4>&2
	trap 'exec 2>&4 1>&3' 0 1 2 3 RETURN
	exec 1>>"$SYS_LOG" 2>&1
fi

## Only one instance of this script should ever be running and as its use is normally called via cron, if it's then run manually
## for test purposes it may intermittently update the ports.tcp & ports.udp files unnecessarily. So here we check no other instance
## is running. If another instance is running we pause for 5 seconds and then delete the PID anyway. Normally this script will run
## in under 150ms and via cron runs every 60 seconds, so if the PID file still exists after 5 seconds then it's a orphan PID file.
if [ -f "$PID_PATH_FULL" ]; then
        if [ "$(cat "$PID_PATH_FULL" | grep $PID)" != "" ]; then
                echo "There is already an entry in PID file $PID_PATH_FULL with PID $PID. EXIT"
                if [ $VERBOSE_SWITCH -eq '1' ]; then
                        echo "Please check this. THANKS"
                        echo "I will now quit"
                fi
                exit 2
        fi

        #sleep 5 #if PID file exists wait 3 seconds and test again, if it still exists delete it and carry on
        #echo "There appears to be another Process $file_name PID $PID_PATH_FULL is already running, waiting for 5 seconds ..."
        #rm -f -- "$PID_PATH_FULL"
fi
#trap 'echo $PID "\"$FOLDER_SOURCE"\" "\"$FOLDER_TARGET"\"  >> $PID_PATH_FULL' exit

if [ "$PID" = "" ]; then
        echo "PID Process ID is empty"
        exit 2
fi

if [ ! -f "$PID_PATH_FULL" ]; then
        echo "PID file $PID_PATH_FULL not found"
        pid_file_missing_switch=1
fi

# Check if pid folder exists
if [ ! -d "${PID_PATH_FULL%/*}" ]; then
        if [ $VERBOSE_SWITCH -eq '1' ]; then
                mkdir -pv "${PID_PATH_FULL%/*}"
        else
                mkdir -p "${PID_PATH_FULL%/*}"
        fi
        pid_folder_missing_switch=1
else
        pid_folder_missing_switch=0
fi

# Check if user has write access to sys log file
if [ ! -w "${PID_PATH_FULL%/*}" ]; then
        echo "$run_as_user_name:$run_as_group_name don't have write access for PID file ${PID_PATH_FULL%/*}."
        exit 3
fi

if [ ! -d "$FOLDER_SOURCE" ]; then
        echo "Folder Source parameter $FOLDER_SOURCE is not a valid folder path. EXIT"
        exit 2
fi

if [ ! -d "$FOLDER_TARGET" ]; then
        echo "Folder Target parameter $FOLDER_TARGET is not a valid folder path."
        if [ $VERBOSE_SWITCH -eq '1' ]; then
                mkdir -pv "${FOLDER_TARGET%/*}"
        else
                mkdir -p "${FOLDER_TARGET%/*}"
        fi
        folder_target_missing_switch=1
else
        folder_target_missing_switch=0
fi

# Check if user has write access to sys log file
if [ ! -w "${FOLDER_TARGET%/*}" ]; then
        echo "$run_as_user_name:$run_as_group_name don't have write access for PID file ${FOLDER_TARGET%/*}."
        exit 3
fi

## Print file name
if [ "$OUTPUT_SWITCH" -eq '1' ] && \
   [ "$VERBOSE_SWITCH" -eq '0' ]; then
        sh OutputStyler "start"
        sh OutputStyler "start"
        echo ">>> Sub Module $file_name_full v$version starting >>>"
        echo ">>> PID Create Config: PID Path=$PID_PATH_FULL, PID=$PID, Folder Source=$FOLDER_SOURCE, Folder Target=$FOLDER_TARGET >>>"
fi

if [ "$VERBOSE_SWITCH" -eq '1' ]; then
        sh OutputStyler "start"
	sh OutputStyler "start"
        echo ">>> Sub Module $file_name_full v$version starting >>>"
        echo ">>> PID Create Config: PID Path=$PID_PATH_FULL, PID=$PID, Folder Source=$FOLDER_SOURCE, Folder Target=$FOLDER_TARGET >>>"
	sh OutputStyler "middle"
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
        
        if [ "$pid_folder_missing_switch" -eq '1' ]; then
                echo "PID folder: ${PID_PATH_FULL%/*} is missing"
                echo "Creating it at ${PID_PATH_FULL%/*}"
        fi

        if [ "$pid_file_missing_switch" -eq '1' ]; then
                echo "PID file: $PID_PATH_FULL is missing"
                echo "Creating it at $PID_PATH_FULL"
        fi

        if [ "$folder_target_missing_switch" -eq '1' ]; then
                echo "Folder Target: ${FOLDER_TARGET%/*} is missing"
                echo "Creating it at ${FOLDER_TARGET%/*}"
        fi

        if [ "$sys_log_folder_missing_switch" -eq '1' ]; then
		echo "Sys log folder: ${SYS_LOG%/*} is missing"
		echo "Creating it at ${SYS_LOG%/*}"
	fi

	if [ "$sys_log_file_missing_switch" -eq '1' ]; then
		echo "Sys log file: $SYS_LOG is missing"
		echo "Creating it at $SYS_LOG"
	fi

	if [ "$job_log_file_missing_switch" -eq '1' ]; then
		echo "Job log file: $JOB_LOG is missing"
		echo "Creating it at $JOB_LOG"
	fi

        if [ "$job_log_folder_missing_switch" -eq '1' ]; then
		echo "Sys log folder: ${JOB_LOG%/*} is missing"
		echo "Creating it at ${JOB_LOG%/*}"
	fi

	if [ "$OUTPUT_SWITCH" -eq '0' ]; then
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

        #pids_tmp=( $( cat "$PID_PATH_FULL") )
        readarray -t pids_tmp < <(cat "$PID_PATH_FULL")
        echo "Count Array pids_tmp ${#pids_tmp[@]}"
	for pid_tmp in "${!pids_tmp[@]}"
        do
                echo "Array pids_tmp element $pid_tmp: ${pids_tmp[$pid_tmp]}"
        done

        #pids_tmp=$(${pids_string_full})
        pids_source=( "$(echo "${pids_tmp[@]}" | awk '{print substr($2, index($0,$1))}')" )
        pids_target=( "$(echo "${pids_tmp[@]}" | awk '{print $NF}')" )

        echo "Count Array pids_source ${#pids_source[@]}"
	for pid_source in "${!pids_source[@]}"
        do
                echo "Array pids_source element $pid_source: ${pids_source[$pid_source]}"
        done

        echo "Count Array pids_target ${#pids_target[@]}"
	for pid_target in "${!pids_target[@]}"
        do
                echo "Array pids_target element $pid_target: ${pids_target[$pid_target]}"
        done

        if [ $VERBOSE_SWITCH -eq '1' ]; then
                echo "PIDs String Full: $pids_string_full"
                echo "Stating comparing the folders"
                echo "Max Folder Deep for check is 9"
        fi
        ## Split PIDs source and compare folders
        found_switch=0
        for pid_source in "${!pids_source[@]}"
        do
		pid_source_folder_sub_1=$(echo "${pids_source[$pid_source]}" | cut -d/ -f2)
                pid_source_folder_sub_2=$(echo "${pids_source[$pid_source]}" | cut -d/ -f3)
                pid_source_folder_sub_3=$(echo "${pids_source[$pid_source]}" | cut -d/ -f4)
                pid_source_folder_sub_4=$(echo "${pids_source[$pid_source]}" | cut -d/ -f5)
                pid_source_folder_sub_5=$(echo "${pids_source[$pid_source]}" | cut -d/ -f6)
                pid_source_folder_sub_6=$(echo "${pids_source[$pid_source]}" | cut -d/ -f7)
                pid_source_folder_sub_7=$(echo "${pids_source[$pid_source]}" | cut -d/ -f8)
                pid_source_folder_sub_8=$(echo "${pids_source[$pid_source]}" | cut -d/ -f9)
                pid_source_folder_sub_9=$(echo "${pids_source[$pid_source]}" | cut -d/ -f10)
                ## Split PIDs target and compare folders
                for pid_target in "${!pids_target[@]}"
                do
                	pid_target_folder_sub_1=$(echo "${pids_target[$pid_target]}" | cut -d/ -f2)
                	pid_target_folder_sub_2=$(echo "${pids_target[$pid_target]}" | cut -d/ -f3)
                	pid_target_folder_sub_3=$(echo "${pids_target[$pid_target]}" | cut -d/ -f4)
                	pid_target_folder_sub_4=$(echo "${pids_target[$pid_target]}" | cut -d/ -f5)
                	pid_target_folder_sub_5=$(echo "${pids_target[$pid_target]}" | cut -d/ -f6)
                	pid_target_folder_sub_6=$(echo "${pids_target[$pid_target]}" | cut -d/ -f7)
                	pid_target_folder_sub_7=$(echo "${pids_target[$pid_target]}" | cut -d/ -f8)
                	pid_target_folder_sub_8=$(echo "${pids_target[$pid_target]}" | cut -d/ -f9)
                	pid_target_folder_sub_9=$(echo "${pids_target[$pid_target]}" | cut -d/ -f10)

			if [ $VERBOSE_SWITCH -eq '1' ]; then
                                echo "Working on Folder Source $FOLDER_SOURCE and PID Target $pid_target"
                        fi
			## Compare $FOLDER_SOURCE with pids_target and a folder deep of 9
                        if [ "$FOLDER_SOURCE_1" != "$pid_target_folder_sub_1" ]; then found_switch=0; else
				if [ "$FOLDER_SOURCE_2" != "$pid_target_folder_sub_2" ] && [ "$FOLDER_SOURCE_2" != "" ] && [ "$pid_target_folder_sub_2" != "" ]; then found_switch=0; else
	                                if [ "$FOLDER_SOURCE_3" != "$pid_target_folder_sub_3" ] && [ "$FOLDER_SOURCE_3" != "" ] && [ "$pid_target_folder_sub_3" != "" ]; then found_switch=0; else
						if [ "$FOLDER_SOURCE_4" != "$pid_target_folder_sub_4" ] && [ "$FOLDER_SOURCE_4" != "" ] && [ "$pid_target_folder_sub_4" != "" ]; then found_switch=0; else
							if [ "$FOLDER_SOURCE_5" != "$pid_target_folder_sub_5" ] && [ "$FOLDER_SOURCE_5" != "" ] && [ "$pid_target_folder_sub_5" != "" ]; then found_switch=0; else
	                                                        if [ "$FOLDER_SOURCE_6" != "$pid_target_folder_sub_6" ] && [ "$FOLDER_SOURCE_6" != "" ] && [ "$pid_target_folder_sub_6" != "" ]; then found_switch=0; else
		                                                        if [ "$FOLDER_SOURCE_7" != "$pid_target_folder_sub_7" ] && [ "$FOLDER_SOURCE_7" != "" ] && [ "$pid_target_folder_sub_7" != "" ]; then found_switch=0; else
			                                                        if [ "$FOLDER_SOURCE_8" != "$pid_target_folder_sub_8" ] && [ "$FOLDER_SOURCE_8" != "" ] && [ "$pid_target_folder_sub_8" != "" ]; then found_switch=0; else
				                                                        if [ "$FOLDER_SOURCE_9" != "$pid_target_folder_sub_9" ] && [ "$FOLDER_SOURCE_9" != "" ] && [ "$pid_target_folder_sub_9" != "" ]; then
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
                        if [ "$FOLDER_TARGET_1" != "$pid_source_folder_sub_1" ]; then found_switch=0; else
                                if [ "$FOLDER_TARGET_2" != "$pid_source_folder_sub_2" ] && [ "$FOLDER_TARGET_2" != "" ] && [ "$pid_source_folder_sub_2" != "" ]; then found_switch=0; else
                                        if [ "$FOLDER_TARGET_3" != "$pid_source_folder_sub_3" ] && [ "$FOLDER_TARGET_3" != "" ] && [ "$pid_source_folder_sub_3" != "" ]; then found_switch=0; else
                                                if [ "$FOLDER_TARGET_4" != "$pid_source_folder_sub_4" ] && [ "$FOLDER_TARGET_4" != "" ] && [ "$pid_source_folder_sub_4" != "" ]; then found_switch=0; else
                                                        if [ "$FOLDER_TARGET_5" != "$pid_source_folder_sub_5" ] && [ "$FOLDER_TARGET_5" != "" ] && [ "$pid_source_folder_sub_5" != "" ]; then found_switch=0; else
                                                                if [ "$FOLDER_TARGET_6" != "$pid_source_folder_sub_6" ] && [ "$FOLDER_TARGET_6" != "" ] && [ "$pid_source_folder_sub_6" != "" ]; then found_switch=0; else
                                                                        if [ "$FOLDER_TARGET_7" != "$pid_source_folder_sub_7" ] && [ "$FOLDER_TARGET_7" != "" ] && [ "$pid_source_folder_sub_7" != "" ]; then found_switch=0; else
                                                                                if [ "$FOLDER_TARGET_8" != "$pid_source_folder_sub_8" ] && [ "$FOLDER_TARGET_8" != "" ] && [ "$pid_source_folder_sub_8" != "" ]; then found_switch=0; else
                                                                                        if [ "$FOLDER_TARGET_9" != "$pid_source_folder_sub_9" ] && [ "$FOLDER_TARGET_9" != "" ] && [ "$pid_source_folder_sub_9" != "" ]; then
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
			echo "!!! Folder Source $FOLDER_SOURCE and PID Target $pid_target are the same or is a subfolder!!!"
			echo "!!! OR !!!"
		        echo "!!! Folder Target $FOLDER_TARGET and PID Source $pid_source are the same or is a subfolder!!!"
                fi
                echo "!!! Cross copy match found. That's not allowed. Please wait until the other job is finished !!! EXIT"
                exit 99 #sleep 10
        else
                if [ $VERBOSE_SWITCH -eq '1' ]; then
			echo "No Cross Copy Match found in PID $PID_PATH_FULL Folder Source $FOLDER_SOURCE Folder Target $FOLDER_TARGET"
		        echo "Updating PID $PID_PATH_FULL with PID $PID, folder source $FOLDER_SOURCE and folder target $FOLDER_TARGET"
                        echo "$PID "\"$FOLDER_SOURCE"\" "\"$FOLDER_TARGET"\""
                fi

		echo "$PID" "\"$FOLDER_SOURCE"\" "\"$FOLDER_TARGET"\" >> "$PID_PATH_FULL"

                ## Check if the job has worked correctly
                if [ "$(cat "$PID_PATH_FULL" | grep $PID)" != "" ]; then
                        if [ $VERBOSE_SWITCH -eq '1' ]; then
                                echo "PID entry for $PID was created successfully in $PID_PATH_FULL"
                        fi
                else
                        echo "There was a problem creating the entry for PID $PID in PID $PID_PATH_FULL"
                        exit 1
                fi

        fi
## If no PID exists... create it
else
        if [ $VERBOSE_SWITCH -eq '1' ]; then
                echo "NO PID $PID_PATH_FULL found"
                echo "Creating PID $PID_PATH_FULL PID Process ID $PID"
                echo "Folder Source $FOLDER_SOURCE"
                echo "Folder Target $FOLDER_TARGET"
        fi

        echo "$PID" "\"$FOLDER_SOURCE"\" "\"$FOLDER_TARGET"\" > "$PID_PATH_FULL"

        ## Check if the job has worked correctly
        if [ -f "$PID_PATH_FULL" ]; then
                if [ "$(cat "$PID_PATH_FULL" | grep $PID)" != "" ]; then
                        if [ $VERBOSE_SWITCH -eq '1' ]; then
                                echo "PID file $PID_PATH_FULL was created successfully"
                        fi
                fi
        else
                echo "There was a problem creating the PID file $PID_PATH_FULL with PID $PID"
                exit 1
        fi
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
        sh OutputStyler "middle"
        sh OutputStyler "end"
fi

## Check last task for errors
status=$?
if [ $status != 0 ]; then
	if [ $VERBOSE_SWITCH -eq '1' ]; then
                sh OutputStyler "error"
        fi
        echo "!!! Error Sub Module $file_name_full from $FOLDER_SOURCE to $FOLDER_TARGET, code=$status !!!"
        if [ $VERBOSE_SWITCH -eq '1' ]; then
                echo "!!! PID Create Config: PID Path=$PID_PATH_FULL, PID=$PID, Folder Source=$FOLDER_SOURCE, Folder Target=$FOLDER_TARGET !!!"
                echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
		sh OutputStyler "error"
		sh OutputStyler "end"
	        sh OutputStyler "end"
        fi
        exit $status
else
        if [ $VERBOSE_SWITCH -eq '1' ]; then
                echo "<<< PID Create Config: PID Path=$PID_PATH_FULL, PID=$PID, Folder Source=$FOLDER_SOURCE, Folder Target=$FOLDER_TARGET <<<"
                echo "<<< Sub Module $file_name_full v$version finished successfully <<<"
	        sh OutputStyler "end"
	        sh OutputStyler "end"
        fi
        exit $status
fi
