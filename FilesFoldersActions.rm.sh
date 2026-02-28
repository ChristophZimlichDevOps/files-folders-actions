#!/bin/bash

## Creator: Christoph Zimlich
##
##
## Summary
## This script will remove files and folders like you want. Useful for backups for example.
##
## Parameter 1: Folder Target i.e. "/home/backup/mysql/"
## Parameter 2: Name Part i.e. 		"current*"
## Parameter 4: Remove Mode Switch	0=Only files
##                             		1=Files and Folders
##                             		2=Only Folders
## Parameter 4: Remove Files Folders Deep "1"=Deep of the the folder(s) where file(s) and folder(s) can be find to remove. MAX VALUE IS 2 for security reason
## Parameter 5: Sys log i.e. 		"/var/log/bash/$file_name.log"
## Parameter 6: Job log i.e.		"/tmp/bash/$file_name.log"
## Parameter 7: Output Switch      	0=Console
##                                 	1=Logfile; Default
## Parameter 8: Verbose Switch     	0=Off
##                                 	1=On; Default
##
## Call it like this:
## sh FilesFoldersActions.rm.sh \
##		"/home/.backup/mysql" \
##		"$(date +%y%m%d*)" \
##		"0" \
##		"1" \
##		"/var/log/bash/$file_name.log" \
##		"/tmp/bash/$file_name.log" \
##		"0" \
##		"0" \
##		"1"

## Clear console to debug that stuff better
#clear

## Enhanced debugging with set -x
#set -x

## Set Stuff
version="0.0.1-alpha.1"
file_name_full="FilesFoldersActions.rm.sh"
file_name="${file_name_full%.*}"

run_as_user_name=$(whoami)
run_as_user_uid=$(id -u "$run_as_user_name")
run_as_group_name=$(id -gn "$run_as_user_name")
run_as_group_gid=$(getent group "$run_as_group_name" | cut -d: -f3)
run_on_hostname=$(hostname -f)

## Check this script is running as root !
#if [ "$(id -u)" != "0" ]; then
#	echo "Aborting, this script needs to be run as root! EXIT"
#	exit 1
#fi

## Only one instance of this script should ever be running and as its use is normally called via cron, if it's then run manually
## for test purposes it may intermittently update the ports.tcp & ports.udp files unnecessarily. So here we check no other instance
## is running. If another instance is running we pause for 3 seconds and then delete the PID anyway. Normally this script will run
## in under 150ms and via cron runs every 60 seconds, so if the PID file still exists after 3 seconds then it's a orphan PID file.
#if [ -f "$FilesFoldersRmPID" ]; then
#        sleep 3 #if PID file exists wait 3 seconds and test again, if it still exists delete it and carry on
#        echo "There appears to be another Process $file_name_full PID $FilesFoldersRmPID is already running, waiting for 3 seconds ..."
#        rm -f -- "$FilesFoldersRmPID"
#fi
#trap 'rm -f -- $FilesFoldersRmPID' EXIT
#echo $$ > "$FilesFoldersRmPID"

## Clear used stuff
declare    FOLDER_TARGET
declare    NAME_PART
declare	   MODE_SWITCH
declare    FOLDER_DEEP
declare -i CONFIG_SWITCH
declare -i OUTPUT_SWITCH
declare -i VERBOSE_SWITCH
## Clear stuff need for processing
declare    config_file_in
declare -a files
declare -a folders
declare -i operation_mode_switch
declare -i date_year
declare -i date_month
declare -i date_day
declare    date_tmp_1
declare    date_tmp_2
declare    date_tmp_3
declare -i sys_log_folder_missing_switch=0
declare -i sys_log_file_missing_switch=0
declare -i job_log_folder_missing_switch=0
declare -i job_log_file_missing_switch=0
declare -i status

## Check for arguments
FOLDER_TARGET=$1
NAME_PART=$2
MODE_SWITCH=$3
FOLDER_DEEP=$4
SYS_LOG=$5
JOB_LOG=$6
CONFIG_SWITCH=$7
OUTPUT_SWITCH=$8
VERBOSE_SWITCH=$9

#if [ $CONFIG_SWITCH -eq '1' ]; then 
	## Set the job config FILE from parameter
	config_file_in="$HOME/bin/linux/shell/local/FilesFoldersActions/$file_name.conf.in"
	echo "Using config file $config_file_in for $file_name_full"

	## Import stuff from config FILE
	set -o allexport
	# shellcheck source=$config_file_in disable=SC1091
	. "$config_file_in"
	set +o allexport
#fi

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

if [ "$MODE_SWITCH" -eq '0' ]; then
	mode="file(s)"
fi

if [ "$MODE_SWITCH" -eq '1' ]; then
	mode="file(s) and folder(s)"
fi

if [ "$MODE_SWITCH" -eq '2' ]; then
	mode="folder(s)"
fi

## Print file name
if [ "$OUTPUT_SWITCH" -eq '1' ] && \
   [ "$VERBOSE_SWITCH" -eq '0' ]; then
        sh OutputStyler "start"
        sh OutputStyler "start"
        echo ">>> Sub Module $file_name_full v$version starting >>>"
        echo ">>> PID Create Config: PID Path=$PID_PATH_FULL, PID=$PID, Folder Source=$FOLDER_SOURCE, Folder Target=$FOLDER_TARGET >>>"
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
	sh OutputStyler "start"
	sh OutputStyler "start"
	echo ">>> Sub Module $file_name_full v$version starting >>>"
	echo ">>> Remove Config: Folder Target=$FOLDER_TARGET, Name Part=$NAME_PART, Mode=$mode >>>"
    sh OutputStyler "start"
	sh OutputStyler "start"
	sh OutputStyler "middle"
	echo "!!! ATTENTION !!!						Parameter 3: Name Part				   !!! ATTENTION !!!"
    echo "!!! ATTENTION !!!		ONLY wildcards at the beginning and at the end with other real content will work   !!! ATTENTION !!!"
    echo "!!! ATTENTION !!!		ONLY wildcards with no other real content will NOT work				   !!! ATTENTION !!!"
	echo "Filename: $file_name_full"
	echo "Version: v$version"
	echo "Run as user name: $run_as_user_name"
	echo "Run as user uid: $run_as_user_uid"
	echo "Run as group: $run_as_group_name"
	echo "Run as group gid: $run_as_group_gid"
	echo "Run on host: $run_on_hostname"
	echo "Verbose is ON"
	echo "Folder Target: $FOLDER_TARGET"
	echo "$mode Name Part: $NAME_PART"

	echo -n "Removing File(s) is "
	if [ "$MODE_SWITCH" -eq '2' ]; then
		echo "OFF"
	else
		echo "ON"
	fi

	echo -n "Removing Folder(s) is "
	if [ "$MODE_SWITCH" -gt '0' ]; then
		echo "ON"
	else
		echo "OFF"
	fi

	echo "Removing $mode Folder(s) Deep $FOLDER_DEEP"
	
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

if [ "$FOLDER_TARGET" = "" ]; then
	echo "Folder Target parameter is empty. EXIT"
	exit 1
fi

if [ ! -d "$FOLDER_TARGET" ]; then
	echo "Folder Target parameter $FOLDER_TARGET is not a valid folder path. EXIT"
	exit 1
fi

if [ "$NAME_PART" = "" ]; then
	echo "$mode Name Part parameter is empty. EXIT"
	exit 1
fi

if [ "$MODE_SWITCH" -gt '1' ] ||
   [[ ! $MODE_SWITCH =~ [^[:digit:]] ]]; then
        echo "Mode Switch parameter $MODE_SWITCH is not a valid. EXIT"
        exit 2
fi

if [ "$FOLDER_DEEP" = "" ] || \
   [ "$FOLDER_DEEP" -gt '2' ] || \
   [ "$FOLDER_DEEP" -eq '0' ]; then
		echo "Remove Folder Deep Value $FOLDER_DEEP is too high, 0 or empty. Set to Default 1"
		FOLDER_DEEP=1
fi

if [ "$CONFIG_SWITCH" -gt '1' ] ||
   [[ ! $CONFIG_SWITCH =~ [^[:digit:]] ]]; then
        echo "Config Switch parameter $CONFIG_SWITCH is not a valid. EXIT"
        exit 2
fi

if [ "$OUTPUT_SWITCH" -gt '1' ] ||
   [[ ! $OUTPUT_SWITCH =~ [^[:digit:]] ]]; then
        echo "Output Switch parameter $OUTPUT_SWITCH is not a valid. EXIT"
        exit 2
fi

if [ "$VERBOSE_SWITCH" -gt '1' ] ||
   [[ ! $VERBOSE_SWITCH =~ [^[:digit:]] ]]; then
        echo "Verbose Switch parameter $VERBOSE_SWITCH is not a valid. EXIT"
        exit 2
fi

## Lets roll
## If name_part is no pure 10 digit as timestamp
if [ ${#NAME_PART} -gt '7' ] || \
   [[ ! $NAME_PART =~ [^[:digit:]] ]]; then
		operation_mode_switch=0

		readarray -t files < <( find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART" )
		readarray -t folders < <( find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART" )

else
		if [ "$(echo "$NAME_PART" | rev | cut -b 1)" != "*" ]; then
			echo "Something is wrong here..."
			echo "I accept only one wildcard on the last position. That's * "
			echo "Please check this. EXIT"
			exit 1
		fi

		date_year=$(echo "$NAME_PART" | cut -b 1-2)
		date_month=$(echo "$NAME_PART" | cut -b 3-4)
		date_day=$(echo "$NAME_PART" | cut -b 5-6)

		if [ $VERBOSE_SWITCH -eq '1' ]; then
			echo "date_year $date_year"
			echo "date_month $date_month"
			echo "date_day $date_day"
		fi

		if [ "$date_month" -eq '1' ];then
			## If months is January
			operation_mode_switch=1
			date_tmp_1="\"?${date_year}01[1-$date_day]*"\"
			date_tmp_2="\"?[0-$((date_year-1))?[1-12][1-31]*"\"

			readarray -t files < <( find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f \( -name "$date_tmp_1" -o -name "$date_tmp_2" \) )
			readarray -t folders < <( find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d \( -name "$date_tmp_1" -o -name "$date_tmp_2" \) )

		else
			## If months is not January
			operation_mode_switch=2

			#?[20-21]?[1-12][1-31]*
			#?[0-24]?[1-12][1-31]*
			date_tmp_1="$date_year?[1-$date_month][1-$date_day]*"
			date_tmp_2="$date_year?[1-$((date_month-1))][1-31]*"
			date_tmp_3="?[0-$((date_year-1))]?[1-12][1-31]*"

			if [ $VERBOSE_SWITCH -eq '1' ]; then
				echo "date_tmp_1 $date_tmp_1"
				echo "date_tmp_2 $date_tmp_2"
				echo "date_tmp_3 $date_tmp_3"
			fi
	
			readarray -t files < <( find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f \( -name "$date_tmp_1" -o -name "$date_tmp_2" -o -name "$date_tmp_3" \) )
			readarray -t folders < <( find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d \( -name "$date_tmp_1" -o -name "$date_tmp_2" -o -name "$date_tmp_3" \) )
		fi
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
	echo "Remove $mode in $FOLDER_TARGET with name like $NAME_PART started"
fi

## Job containing file(s)
if [ "$MODE_SWITCH" -lt '2' ]; then
	## If job is file(s) only and no file(s) are present with current parameters
	if [ ${#files[@]} -eq '0' ]; then
		echo "You selected $mode to remove...But there are NO $mode with your parameters"
		#exit 1
	fi

	if [ $VERBOSE_SWITCH -eq '1' ]; then
		echo "This will effect the following ${#files[@]} x file(s)..."

		for file in "${!files[@]}"
		do
			echo "Array files element $file: ${files[$file]}"
		done

		echo "Starting removing file(s) now..."

		if [ $operation_mode_switch -eq '0' ]; then
			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART" \
				-exec rm -f -v --interactive=never {} ";"
		fi

		if [ $operation_mode_switch -eq '1' ]; then
			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f \( -name "$date_tmp_1" -o -name "$date_tmp_2" \) \
				-exec rm -f -v --interactive=never {} ";"
		fi

		if [ $operation_mode_switch -eq '2' ]; then
			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f \( -name "$date_tmp_1" -o -name "$date_tmp_2" -o -name "$date_tmp_3" \) \
				-exec rm -f -v --interactive=never {} ";"
		fi

	else
		if [ $operation_mode_switch -eq '0' ]; then
			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART" \
				-exec rm -f --interactive=never {} ";"
		fi

		if [ $operation_mode_switch -eq '1' ]; then
			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f \( -name "$date_tmp_1" -o -name "$date_tmp_2" \) \
				-exec rm -f --interactive=never {} ";"
		fi

		if [ $operation_mode_switch -eq '2' ]; then
			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f \( -name "$date_tmp_1" -o -name "$date_tmp_2" -o -name "$date_tmp_3" \) \
				-exec rm -f --interactive=never {} ";"
		fi
	fi
fi
## Check last task for error(s)
status=$?
if [ $status != 0 ]; then
		# shellcheck disable=SC2154
		echo "Error removing file(s) at $FOLDER_TARGET with name like $NAME_PART, code=$status, EXIT"
		if [ "$VERBOSE_SWITCH" -eq '1' ]; then
				echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
		fi
		exit $status
else
		if [ "$VERBOSE_SWITCH" -eq '1' ]; then
			echo "Removing file(s) at $FOLDER_TARGET with name like $NAME_PART finished successfully"
		fi
fi

## Job containing folder(s)
if [ "$MODE_SWITCH" -gt '0' ]; then
	## If job is folder(s) only and no folder(s) are present with current parameters
	if [ ${#folders[@]} -eq '0' ]; then
		echo "You selected $mode to remove...But there are NO $mode with your parameters. Please check this. EXIT"
		exit 1
	fi

	if [ $VERBOSE_SWITCH -eq '1' ]; then
		echo "This will effect the following ${#folders[@]} folder(s)..."

		for folder in "${!folders[@]}"
		do
			echo "Array folders element $folder: ${folders[$folder]}"
		done

		echo "Starting removing folder(s) now..."

		if [ $operation_mode_switch -eq '0' ]; then
			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART" \
				-exec rmdir --ignore-fail-on-non-empty -v {} ";"
		fi

		if [ $operation_mode_switch -eq '1' ]; then
			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d \( -name "$date_tmp_1" -o -name "$date_tmp_2" \) \
				-exec rmdir --ignore-fail-on-non-empty -v {} ";"
		fi

		if [ $operation_mode_switch -eq '2' ]; then
			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d \( -name "$date_tmp_1" -o -name "$date_tmp_2" -o -name "$date_tmp_3" \) \
				-exec rmdir --ignore-fail-on-non-empty -v {} ";"
		fi

	else

		if [ $operation_mode_switch -eq '0' ]; then
			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART" \
				-exec rmdir --ignore-fail-on-non-empty {} ";"
		fi

		if [ $operation_mode_switch -eq '1' ]; then
			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d \( -name "$date_tmp_1" -o -name "$date_tmp_2" \) \
				-exec rmdir --ignore-fail-on-non-empty {} ";"
		fi

		if [ $operation_mode_switch -eq '2' ]; then
			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d \( -name "$date_tmp_1" -o -name "$date_tmp_2" -o -name "$date_tmp_3" \) \
				-exec rmdir --ignore-fail-on-non-empty {} ";"
		fi	
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
		echo "Remove $mode in $FOLDER_TARGET with name like $NAME_PART stopped with error $status"
	fi

    echo "!!! Error Sub Module $file_name_full from $FOLDER_SOURCE to $FOLDER_TARGET, code=$status"
    if [ $VERBOSE_SWITCH -eq '1' ]; then
        echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
		sh OutputStyler "error"
		sh OutputStyler "end"
	    sh OutputStyler "end"
    fi
	exit $status
else
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		echo "Remove $mode in $FOLDER_TARGET with name like $NAME_PART finished successfully"
		echo "<<< Sub Module $file_name_full v$version finished successfully <<<"
		sh OutputStyler "end"
		sh OutputStyler "end"
	fi
	exit $status
fi
