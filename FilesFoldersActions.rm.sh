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
## Parameter 5: Recreate Folder Switch	0=Off
##                                     	1=On
## Parameter 6: Sys log i.e. 		"/var/log/bash/$file_name.log"
## Parameter 7: Job log i.e.		"/tmp/bash/$file_name.log"
## Parameter 8: Verbose Switch     	0=Off
##                                 	1=On; Default
##
## Call it like this:
## sh FilesFoldersActions.rm.sh \
##		"/home/.backup/mysql" \
##		"$(date +%y%m%d*)" \
##		"0" \
##		"1" \
##		"1" \
##		"/var/log/bash/$file_name.log" \
##		"/tmp/bash/$file_name.log" \
##		"1"

function func_output_optimizer () {

    declare type

    if [ "$1" = "i" ]; then
        type="INFO"
    fi

    if [ "$1" = "w" ]; then
        type="WARNING"
    fi

    if [ "$1" = "e" ]; then
        type="ERROR"
    fi

    if [ "$1" = "c" ]; then
        type="CRITICAL"
    fi

    if [ ${#type} -gt '6' ]; then
        printf "%s  %s\t%s" \
            "$(date --rfc-3339=ns)" \
            "$type" \
            "$2"
    else
        printf "%s  %s\t\t%s" \
            "$(date --rfc-3339=ns)" \
            "$type" \
            "$2"
    fi
}

function func_output_styler () {
    
    #output_length=137
    if [ "$1" = "start" ]; then
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    fi
    
    if [ "$1" = "middle" ]; then
        echo "-----------------------------------------------------------------------------------------------------------------------------------------"
    fi

    if [ "$1" = "part" ]; then
        echo "........................................................................................................................................."
    fi
    
    if [ "$1" = "trouble" ]; then
        echo "?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????"
    fi
    
    if [ "$1" = "error" ]; then
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    fi
    
    if [ "$1" = "end" ]; then
        echo "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
    fi
}

## Clear console to debug that stuff better
#clear

## Enhanced debugging with set -x
#set -x

## Set Stuff
version="0.0.1-beta.1"
file_name_full="FilesFoldersActions.rm.sh"
file_name="${file_name_full%.*}"

run_as_user_name=$(whoami)
run_as_user_uid=$(id -u "$run_as_user_name")
run_as_group_name=$(id -gn "$run_as_user_name")
run_as_group_gid=$(getent group "$run_as_group_name" | cut -d: -f3)
run_on_hostname=$(hostname -f)

## Check this script is running as root !
#if [ "$(id -u)" != "0" ]; then
#	func_output_optimizer "i" "Aborting, this script needs to be run as root! EXIT"
#	exit 1
#fi

## Only one instance of this script should ever be running and as its use is normally called via cron, if it's then run manually
## for test purposes it may intermittently update the ports.tcp & ports.udp files unnecessarily. So here we check no other instance
## is running. If another instance is running we pause for 3 seconds and then delete the PID anyway. Normally this script will run
## in under 150ms and via cron runs every 60 seconds, so if the PID file still exists after 3 seconds then it's a orphan PID file.
#if [ -f "$FilesFoldersRmPID" ]; then
#        sleep 3 #if PID file exists wait 3 seconds and test again, if it still exists delete it and carry on
#        func_output_optimizer "i" "There appears to be another Process $file_name_full PID $FilesFoldersRmPID is already running, waiting for 3 seconds ..."
#        rm -f -- "$FilesFoldersRmPID"
#fi
#trap 'rm -f -- $FilesFoldersRmPID' EXIT
#echo $$ > "$FilesFoldersRmPID"

## Clear used stuff
declare    FOLDER_TARGET
declare    NAME_PART_RM
declare	   MODE_SWITCH
declare    FOLDER_DEEP
declare -i FOLDER_RECREATE_RM_SWITCH
declare -i CONFIG_SWITCH
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
NAME_PART_RM=$2
MODE_SWITCH=$3
FOLDER_DEEP=$4
FOLDER_RECREATE_RM_SWITCH=$5
SYS_LOG=$6
JOB_LOG=$7
CONFIG_SWITCH=$8
VERBOSE_SWITCH=$9

#if [ $CONFIG_SWITCH -eq '1' ]; then 
	## Set the job config FILE from parameter
	config_file_in="$HOME/bin/linux/bash/local/FilesFoldersActions/$file_name.conf.in"
	func_output_optimizer "i" "Using config file $config_file_in for $file_name_full"

	## Import stuff from config FILE
	set -o allexport
	# shellcheck source=$config_file_in disable=SC1091
	. "$config_file_in" 
	set +o allexport
#fi


# Check if log files are set
if [ "$SYS_LOG" = "" ]; then
	func_output_optimizer "c" "System Log parameter is empty. EXIT"
	exit 2
fi

if [ "$JOB_LOG" = "" ]; then
	func_output_optimizer "c" "Job Log parameter is empty. EXIT"
	exit 2
fi

if [ ! -d "${SYS_LOG%/*}" ]; then       
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		mkdir -pv "${SYS_LOG%/*}" &> "$JOB_LOG"
	else
		mkdir -p "${SYS_LOG%/*}" &> "$JOB_LOG"
	fi

	sys_log_folder_missing_switch=1
	sys_log_file_missing_switch=1
fi

# Check if user has write access to sys log file
if [ ! -w "${SYS_LOG%/*}" ]; then
	func_output_optimizer "c" "$run_as_user_name:$run_as_group_name don't have write access for sys log file $SYS_LOG. EXIT"
fi

if [ ! -d "${JOB_LOG%/*}" ]; then       
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		mkdir -pv "${JOB_LOG%/*}" &> "$JOB_LOG"
	else
		mkdir -p "${JOB_LOG%/*}" &> "$JOB_LOG"
	fi

	job_log_folder_missing_switch=1
	job_log_file_missing_switch=1
fi

# Check if user has write access to job log file
if [ ! -w "${JOB_LOG%/*}" ]; then
	func_output_optimizer "c" "$run_as_user_name:$run_as_group_name don't have write access for job log file $JOB_LOG."
fi

if [ ! -w "${SYS_LOG%/*}" ] || \
	[ ! -w "${JOB_LOG%/*}" ]; then
	func_output_optimizer "w" "Please check the job config file $config_file_in. EXIT"
	exit 2
fi

# Set log files
if [ ! -f "$SYS_LOG" ]; then
	sys_log_file_missing_switch=1
	touch "$SYS_LOG" &> "$JOB_LOG"
fi

if [ ! -f "$JOB_LOG" ]; then
	job_log_file_missing_switch=1
	touch "$JOB_LOG" #&> "$JOB_LOG"
fi

# Mod Output
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3 RETURN
exec 1>>"$SYS_LOG" 2>&1

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
if [ $VERBOSE_SWITCH -eq '1' ]; then
	func_output_optimizer "i" "$(func_output_styler "start")"
	func_output_optimizer "i" "$(func_output_styler "start")"
	func_output_optimizer "i" ">>> Sub Module $file_name_full v$version starting >>>"
	func_output_optimizer "i" ">>> Remove Config: Folder Target=$FOLDER_TARGET, Name Part=$NAME_PART_RM, Mode=$mode >>>"
	func_output_optimizer "i" "$(func_output_styler "start")"
	func_output_optimizer "i" "$(func_output_styler "middle")"
	func_output_optimizer "i" "!!! ATTENTION !!!						Parameter 3: Name Part				   !!! ATTENTION !!!"
    func_output_optimizer "i" "!!! ATTENTION !!!		ONLY wildcards at the beginning and at the end with other real content will work   !!! ATTENTION !!!"
    func_output_optimizer "i" "!!! ATTENTION !!!		ONLY wildcards with no other real content will NOT work				   !!! ATTENTION !!!"
	func_output_optimizer "i" "Filename: $file_name_full"
	func_output_optimizer "i" "Version: v$version"
	func_output_optimizer "i" "Run as user name: $run_as_user_name"
	func_output_optimizer "i" "Run as user uid: $run_as_user_uid"
	func_output_optimizer "i" "Run as group: $run_as_group_name"
	func_output_optimizer "i" "Run as group gid: $run_as_group_gid"
	func_output_optimizer "i" "Run on host: $run_on_hostname"
	func_output_optimizer "i" "Verbose is ON"
	func_output_optimizer "i" "Folder Target: $FOLDER_TARGET"
	func_output_optimizer "i" "$mode Name Part: $NAME_PART_RM"

	if [ "$MODE_SWITCH" -eq '2' ]; then
		func_output_optimizer "i" "Removing File(s) is OFF"
	else
		func_output_optimizer "i" "Removing File(s) is ON"
	fi

	if [ "$MODE_SWITCH" -gt '0' ]; then
		func_output_optimizer "i" "Removing Folder(s) is ON"
	else
		func_output_optimizer "i" "Removing Folder(s) is OFF"
	fi

	func_output_optimizer "i" "Removing $mode Folder(s) Deep $FOLDER_DEEP"

	if [ "$FOLDER_RECREATE_RM_SWITCH" -eq '1' ]; then 
		func_output_optimizer "i" "Recreating Folder(s) is ON"
	else
		func_output_optimizer "i" "Recreating Folder(s) is OFF"
	fi

	if [ $CONFIG_SWITCH -eq '0' ]; then
		func_output_optimizer "i" "Config Mode is on Parameters"
	else
		func_output_optimizer "i" "Config Mode is on Config file"
	fi
	
	if [ "$sys_log_folder_missing_switch" -eq '1' ]; then
		func_output_optimizer "i" "Sys log folder: ${SYS_LOG%/*} is missing"
		func_output_optimizer "i" "Creating it at ${SYS_LOG%/*}"
	fi

	if [ "$sys_log_file_missing_switch" -eq '1' ]; then
		func_output_optimizer "i" "Sys log file: $SYS_LOG is missing"
		func_output_optimizer "i" "Creating it at $SYS_LOG"
	fi

	if [ "$job_log_file_missing_switch" -eq '1' ]; then
		func_output_optimizer "i" "Job log file: $JOB_LOG is missing"
		func_output_optimizer "i" "Creating it at $JOB_LOG"
	fi

    if [ "$job_log_folder_missing_switch" -eq '1' ]; then
		func_output_optimizer "i" "Sys log folder: ${JOB_LOG%/*} is missing"
		func_output_optimizer "i" "Creating it at ${JOB_LOG%/*}"
	fi

	func_output_optimizer "i" "Output to console...As $run_as_user_name:$run_as_group_name can see ;)"
	func_output_optimizer "i" "Output to sys log file $SYS_LOG"
	func_output_optimizer "i" "Output to job log file $JOB_LOG"
fi

if [ "$FOLDER_TARGET" = "" ]; then
	func_output_optimizer "i" "Folder Target parameter is empty. EXIT"
	exit 1
fi

if [ ! -d "$FOLDER_TARGET" ]; then
	func_output_optimizer "i" "Folder Target parameter $FOLDER_TARGET is not a valid folder path. EXIT"
	exit 1
fi

if [ "$NAME_PART_RM" = "" ]; then
	func_output_optimizer "i" "$mode Name Part parameter is empty. EXIT"
	exit 1
fi

if [ "$MODE_SWITCH" -gt '2' ] || \
   [[ $MODE_SWITCH =~ [^[:digit:]] ]]; then
        func_output_optimizer "i" "Mode Switch parameter $MODE_SWITCH is not a valid. EXIT"
        exit 2
fi

if [ "$FOLDER_DEEP" = "" ] || \
   [ "$FOLDER_DEEP" -gt '2' ] || \
   [ "$FOLDER_DEEP" -eq '0' ]; then
		func_output_optimizer "i" "Remove Folder Deep Value $FOLDER_DEEP is too high, 0 or empty. Set to Default 1"
		FOLDER_DEEP=1
fi

if [ "$FOLDER_RECREATE_RM_SWITCH" -gt '1' ] || \
   [[ $FOLDER_RECREATE_RM_SWITCH =~ [^[:digit:]] ]]; then
        func_output_optimizer "i" "Config Switch parameter $FOLDER_RECREATE_RM_SWITCH is not a valid. EXIT"
        exit 2
fi

if [ "$CONFIG_SWITCH" -gt '1' ] || \
   [[ $CONFIG_SWITCH =~ [^[:digit:]] ]]; then
        func_output_optimizer "i" "Config Switch parameter $CONFIG_SWITCH is not a valid. EXIT"
        exit 2
fi

if [ "$VERBOSE_SWITCH" -gt '1' ] || \
   [[ $VERBOSE_SWITCH =~ [^[:digit:]] ]]; then
        func_output_optimizer "c" "Verbose Switch parameter $VERBOSE_SWITCH is not a valid. Set to Default 0"
        VERBOSE_SWITCH=0
fi

## Lets roll
## If NAME_PART_RM is no pure 10 digit as timestamp
if [ ${#NAME_PART_RM} -gt '7' ] || \
   [[ $NAME_PART_RM =~ [^[:digit:]] ]]; then
		operation_mode_switch=0

		readarray -t files < <( find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART_RM" ) &> "$JOB_LOG"
		readarray -t folders < <( find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART_RM" ) &> "$JOB_LOG"

else
		if [ "$(echo "$NAME_PART_RM" | rev | cut -b 1)" != "*" ]; then
			func_output_optimizer "c" "Something is wrong here..."
			func_output_optimizer "c" "I accept only one wildcard on the last position. That's * "
			func_output_optimizer "c" "Please check this. EXIT"
			exit 1
		fi

		date_year=$(echo "$NAME_PART_RM" | cut -b 1-2)
		date_month=$(echo "$NAME_PART_RM" | cut -b 3-4)
		date_day=$(echo "$NAME_PART_RM" | cut -b 5-6)

		if [ $VERBOSE_SWITCH -eq '1' ]; then
			func_output_optimizer "i" "date_year $date_year"
			func_output_optimizer "i" "date_month $date_month"
			func_output_optimizer "i" "date_day $date_day"
		fi

		if [ "$date_month" -eq '1' ];then
			## If months is January
			operation_mode_switch=1
			date_tmp_1="\"?${date_year}01[1-$date_day]*"\"
			date_tmp_2="\"?[0-$((date_year-1))?[1-12][1-31]*"\"

			readarray -t files < <( find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f \( -name "$date_tmp_1" -o -name "$date_tmp_2" \) ) &> "$JOB_LOG"
			readarray -t folders < <( find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d \( -name "$date_tmp_1" -o -name "$date_tmp_2" \) ) &> "$JOB_LOG"

		else
			## If months is not January
			operation_mode_switch=2

			#?[20-21]?[1-12][1-31]*
			#?[0-24]?[1-12][1-31]*
			date_tmp_1="$date_year?[1-$date_month][1-$date_day]*"
			date_tmp_2="$date_year?[1-$((date_month-1))][1-31]*"
			date_tmp_3="?[0-$((date_year-1))]?[1-12][1-31]*"

			if [ $VERBOSE_SWITCH -eq '1' ]; then
				func_output_optimizer "i" "date_tmp_1 $date_tmp_1"
				func_output_optimizer "i" "date_tmp_2 $date_tmp_2"
				func_output_optimizer "i" "date_tmp_3 $date_tmp_3"
			fi
	
			readarray -t files < <( find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f \( -name "$date_tmp_1" -o -name "$date_tmp_2" -o -name "$date_tmp_3" \) ) &> "$JOB_LOG"
			readarray -t folders < <( find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d \( -name "$date_tmp_1" -o -name "$date_tmp_2" -o -name "$date_tmp_3" \) ) &> "$JOB_LOG"
		fi
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
	func_output_optimizer "i" "Remove $mode in $FOLDER_TARGET with name like $NAME_PART_RM started"
fi

## Job containing file(s)
if [ "$MODE_SWITCH" -lt '2' ]; then
	## If job is file(s) only and no file(s) are present with current parameters
	if [ ${#files[@]} -eq '0' ]; then
		func_output_optimizer "i" "You selected $mode to remove...But there are NO $mode with your parameters"
		#exit 1
	fi

	if [ $VERBOSE_SWITCH -eq '1' ]; then
		func_output_optimizer "i" "This will effect the following ${#files[@]} x file(s)..."

		for file in "${!files[@]}"
		do
			func_output_optimizer "i" "Array files element $file: ${files[$file]}"
		done

		func_output_optimizer "i" "Starting removing file(s) now..."

		if [ $operation_mode_switch -eq '0' ]; then
			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART_RM" \
				-exec rm -f -v --interactive=never {} ";" &> "$JOB_LOG"
		fi

		if [ $operation_mode_switch -eq '1' ]; then
			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f \( -name "$date_tmp_1" -o -name "$date_tmp_2" \) \
				-exec rm -f -v --interactive=never {} ";" &> "$JOB_LOG"
		fi

		if [ $operation_mode_switch -eq '2' ]; then
			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f \( -name "$date_tmp_1" -o -name "$date_tmp_2" -o -name "$date_tmp_3" \) \
				-exec rm -f -v --interactive=never {} ";" &> "$JOB_LOG"
		fi

	else
		if [ $operation_mode_switch -eq '0' ]; then
			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART_RM" \
				-exec rm -f --interactive=never {} ";" &> "$JOB_LOG"
		fi

		if [ $operation_mode_switch -eq '1' ]; then
			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f \( -name "$date_tmp_1" -o -name "$date_tmp_2" \) \
				-exec rm -f --interactive=never {} ";" &> "$JOB_LOG"
		fi

		if [ $operation_mode_switch -eq '2' ]; then
			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f \( -name "$date_tmp_1" -o -name "$date_tmp_2" -o -name "$date_tmp_3" \) \
				-exec rm -f --interactive=never {} ";" &> "$JOB_LOG"
		fi
	fi
fi
## Check last task for error(s)
status=$?
if [ $status != 0 ]; then
		# bashcheck disable=SC2154
		func_output_optimizer "e" "Error removing file(s) at $FOLDER_TARGET with name like $NAME_PART_RM, code=$status, EXIT"
		if [ "$VERBOSE_SWITCH" -eq '1' ]; then
				func_output_optimizer "e" "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
		fi
		exit $status
else
		if [ "$VERBOSE_SWITCH" -eq '1' ]; then
			func_output_optimizer "i" "Removing file(s) at $FOLDER_TARGET with name like $NAME_PART_RM finished successfully"
		fi
fi

## Job containing folder(s)
if [ "$MODE_SWITCH" -gt '0' ]; then
	## If job is folder(s) only and no folder(s) are present with current parameters
	if [ ${#folders[@]} -eq '0' ]; then
		func_output_optimizer "w" "You selected $mode to remove...But there are NO $mode with your parameters. Please check this. EXIT"
		exit 1
	fi

	if [ $VERBOSE_SWITCH -eq '1' ]; then
		func_output_optimizer "i" "This will effect the following ${#folders[@]} folder(s)..."

		for folder in "${!folders[@]}"
		do
			func_output_optimizer "i" "Array folders element $folder: ${folders[$folder]}"
		done

		func_output_optimizer "i" "Starting removing folder(s) now..."

		if [ $operation_mode_switch -eq '0' ]; then
			if [ "$FOLDER_RECREATE_RM_SWITCH" -eq '1' ]; then

				find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART_RM" \
					-exec rmdir -v --ignore-fail-on-non-empty {} \; -exec mkdir -pv {} ";" &> "$JOB_LOG"

			else

				find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART_RM" \
					-exec rmdir -v --ignore-fail-on-non-empty {} ";" &> "$JOB_LOG"
			fi
		fi

		if [ $operation_mode_switch -eq '1' ]; then
			if [ "$FOLDER_RECREATE_RM_SWITCH" -eq '1' ]; then

				find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d \( -name "$date_tmp_1" -o -name "$date_tmp_2" \) \
					-exec rmdir -v --ignore-fail-on-non-empty {} \; -exec mkdir -pv {} ";" &> "$JOB_LOG"

			else
				find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d \( -name "$date_tmp_1" -o -name "$date_tmp_2" \) \
					-exec rmdir -v --ignore-fail-on-non-empty {} ";" &> "$JOB_LOG"
			fi
		fi

		if [ $operation_mode_switch -eq '2' ]; then
			if [ "$FOLDER_RECREATE_RM_SWITCH" -eq '1' ]; then

				find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d \( -name "$date_tmp_1" -o -name "$date_tmp_2" -o -name "$date_tmp_3" \) \
					-exec rmdir -v --ignore-fail-on-non-empty {} \; -exec mkdir -pv {} ";" &> "$JOB_LOG"

			else

				find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d \( -name "$date_tmp_1" -o -name "$date_tmp_2" -o -name "$date_tmp_3" \) \
					-exec rmdir -v --ignore-fail-on-non-empty {} ";" &> "$JOB_LOG"

			fi
		fi

	else

		if [ $operation_mode_switch -eq '0' ]; then
			if [ "$FOLDER_RECREATE_RM_SWITCH" -eq '1' ]; then

				find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART_RM" \
					-exec rmdir --ignore-fail-on-non-empty {} \; -exec mkdir -p {} ";" &> "$JOB_LOG"

			else

				find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART_RM" \
					-exec rmdir --ignore-fail-on-non-empty {} ";" &> "$JOB_LOG"

			fi
		fi

		if [ $operation_mode_switch -eq '1' ]; then
			if [ "$FOLDER_RECREATE_RM_SWITCH" -eq '1' ]; then

				find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d \( -name "$date_tmp_1" -o -name "$date_tmp_2" \) \
					-exec rmdir --ignore-fail-on-non-empty {} \; -exec mkdir -p {} ";" &> "$JOB_LOG"

			else

				find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d \( -name "$date_tmp_1" -o -name "$date_tmp_2" \) \
					-exec rmdir --ignore-fail-on-non-empty {} ";" &> "$JOB_LOG"
			fi
		fi

		if [ $operation_mode_switch -eq '2' ]; then
			if [ "$FOLDER_RECREATE_RM_SWITCH" -eq '1' ]; then

				find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d \( -name "$date_tmp_1" -o -name "$date_tmp_2" -o -name "$date_tmp_3" \) \
					-exec rmdir --ignore-fail-on-non-empty {} \; -exec mkdir -p {} ";" &> "$JOB_LOG"

			else

				find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d \( -name "$date_tmp_1" -o -name "$date_tmp_2" -o -name "$date_tmp_3" \) \
					-exec rmdir --ignore-fail-on-non-empty {} ";" &> "$JOB_LOG"

			fi
		fi	
	fi
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
	func_output_optimizer "i" "$(func_output_styler "middle")"
	func_output_optimizer "i" "$(func_output_styler "end")"
fi

## Check last task for errors
status=$?
if [ $status != 0 ]; then
	if [ $VERBOSE_SWITCH -eq '1' ]; then
        func_output_optimizer "e" "$(func_output_styler "error")"
		func_output_optimizer "e" "Remove $mode in $FOLDER_TARGET with name like $NAME_PART_RM stopped with error $status"
	fi

    func_output_optimizer "e" "!!! Error Sub Module $file_name_full from $FOLDER_SOURCE to $FOLDER_TARGET, code=$status"
    if [ $VERBOSE_SWITCH -eq '1' ]; then
        func_output_optimizer "e" "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
		func_output_optimizer "e" "$(func_output_styler "error")"
		func_output_optimizer "i" "$(func_output_styler "end")"
	    func_output_optimizer "i" "$(func_output_styler "end")"
    fi
	exit $status
else
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		func_output_optimizer "i" "Remove $mode in $FOLDER_TARGET with name like $NAME_PART_RM finished successfully"
		func_output_optimizer "i" "<<< Sub Module $file_name_full v$version finished successfully <<<"
		func_output_optimizer "i" "$(func_output_styler "end")"
		func_output_optimizer "i" "$(func_output_styler "end")"
	fi
	exit $status
fi
