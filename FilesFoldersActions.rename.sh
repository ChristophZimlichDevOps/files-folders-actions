#!/bin/bash

## Creator: Christoph Zimlich
##
##
## Summary
## This script will rename files and folders like you want. Useful for backups for example.
##
## Parameter  1: File Name Part Old i.e. "current*" ONLY wildcards at the beginning and at the end with other real content will work. ONLY wildcards with no other real content will NOT work
## Parameter  2: File Name Part New i.e. "$(date +%y%m%d%H%M%S)"
## Parameter  3: Folder Target i.e.		"/home/backup/mysql/"
## Parameter  4: Rename Mode Switch		0=Only files
##                             			1=Files and Folders
##                             			2=Only Folders
## Parameter  5: Folder Deep where File(s) and Folder(s) get found; Default 1
## Parameter  6: Recreate Folder Switch	0=Off
##                                     	1=On
## Parameter  7: Sys log i.e. 			"/var/log/bash/$file_name.log"
## Parameter  8: Job log i.e. 			"/tmp/bash/$file_name.log"
## Parameter  9: Config Switch          0=Parameters; Default
##                                      1=Config file
## Parameter 10: Verbose Switch     	0=Off; Default
##                                  	1=On
##
## Call it like this:
## sh FilesFoldersActions.rename.sh \
##		"current*" \
##		"$(date +%y%m%d%H%M%S)" \
##		"/home/backup/mysql/" \
##		"0" \
##		"1" \
##		"0" \
##		"/var/log/bash/$file_name.log" \
##		"/tmp/bash/$file_name.log" \
##		"0" \
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
    
    #output_length=136
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
file_name_full="FilesFoldersActions.rename.sh"
file_name="${file_name_full%.*}"

run_as_user_name=$(whoami)
run_as_user_uid=$(id -u "$run_as_user_name")
run_as_group_name=$(id -gn "$run_as_user_name")
run_as_group_gid=$(getent group "$run_as_group_name" | cut -d: -f3)
run_on_hostname=$(hostname -f)

## Check this script is running as root !
#if [ "$run_as_user_uid" != "0" ]; then
#    func_output_optimizer "w" "!!! ATTENTION !!!		    YOU MUST RUN THIS SCRIPT AS ROOT / SUPERUSER	        !!! ATTENTION !!!"
#fi

## Clear used stuff
declare	   NAME_PART_OLD
declare	   NAME_PART_NEW
declare	   FOLDER_TARGET
declare -i MODE_SWITCH
declare -i FOLDER_DEEP
declare -i FOLDER_RECREATE_RENAME_SWITCH
declare	   SYS_LOG
declare	   JOB_LOG
declare -i CONFIG_SWITCH
declare -i VERBOSE_SWITCH
## Needed for processing
declare    config_file_in
declare    mode
declare    name_part_old_clean
declare -a files
declare -a folders
declare -i sys_log_folder_missing_switch=0
declare -i sys_log_file_missing_switch=0
declare -i job_log_folder_missing_switch=0
declare -i job_log_file_missing_switch=0
declare -i status

## Set parameters
NAME_PART_OLD=$1 
NAME_PART_NEW=$2
FOLDER_TARGET=$3
MODE_SWITCH=$4
FOLDER_DEEP=$5
FOLDER_RECREATE_RENAME_SWITCH=$6
SYS_LOG=$7
JOB_LOG=$8
CONFIG_SWITCH=$9
VERBOSE_SWITCH=${10}

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
	func_output_optimizer "w" "Please check the job config FILE $config_file_in. EXIT"
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
		mode="File(s)"
fi

if [ "$MODE_SWITCH" -eq '1' ]; then
		mode="File(s) and Folder(s)"
fi

if [ "$MODE_SWITCH" -eq '2' ]; then
		mode="Folder(s)"
fi

## Print file name
if [ "$VERBOSE_SWITCH" -eq '1' ]; then
    func_output_optimizer "i" "$(func_output_styler "start")"
    func_output_optimizer "i" "$(func_output_styler "start")"
	func_output_optimizer "i" ">>> Sub Module $file_name_full v$version starting >>>"
	func_output_optimizer "i" ">>> Rename Config: Name Part Old=$NAME_PART_OLD, Name Part New=$NAME_PART_NEW, Folder Source=$FOLDER_TARGET, Mode=$mode >>>"
    func_output_optimizer "i" "$(func_output_styler "start")"
    func_output_optimizer "i" "$(func_output_styler "middle")"
    func_output_optimizer "i" "Filename: $file_name_full"
    func_output_optimizer "i" "Version: v$version"
    func_output_optimizer "i" "Run as user name: $run_as_user_name"
    func_output_optimizer "i" "Run as user uid: $run_as_user_uid"
    func_output_optimizer "i" "Run as group: $run_as_group_name"
    func_output_optimizer "i" "Run as group gid: $run_as_group_gid"
    func_output_optimizer "i" "Run on host: $run_on_hostname"
	func_output_optimizer "i" "Verbose is ON"
	func_output_optimizer "i" "$mode Name Part Old: $NAME_PART_OLD"
	func_output_optimizer "i" "$mode Name Part New: $NAME_PART_NEW"
	func_output_optimizer "i" "Folder Source: $FOLDER_TARGET"
    func_output_optimizer "i" "Search for $mode like: $FOLDER_TARGET$NAME_PART_OLD"
	
	if [ "$MODE_SWITCH" -gt '1' ]; then
		func_output_optimizer "i" "Renaming file(s) is OFF"
	else
		func_output_optimizer "i" "Renaming file(s) is ON"
	fi

	if [ "$MODE_SWITCH" -gt '0' ]; then 
		func_output_optimizer "i" "Renaming folder(s) is ON"
	else
		func_output_optimizer "i" "Renaming folder(s) is OFF"
	fi

	func_output_optimizer "i" "Renaming Folder(s) Deep $FOLDER_DEEP"
	
	if [ "$FOLDER_RECREATE_RENAME_SWITCH" -eq '1' ]; then 
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
		func_output_optimizer "w" "Sys log folder: ${SYS_LOG%/*} is missing"
		func_output_optimizer "i" "Creating it at ${SYS_LOG%/*}"
	fi

	if [ "$sys_log_file_missing_switch" -eq '1' ]; then
		func_output_optimizer "w" "Sys log file: $SYS_LOG is missing"
		func_output_optimizer "i" "Creating it at $SYS_LOG"
	fi

	if [ "$job_log_file_missing_switch" -eq '1' ]; then
		func_output_optimizer "i" "Job log file: $JOB_LOG is missing"
		func_output_optimizer "i" "Creating it at $JOB_LOG"
	fi

        if [ "$job_log_folder_missing_switch" -eq '1' ]; then
		func_output_optimizer "w" "Sys log folder: ${JOB_LOG%/*} is missing"
		func_output_optimizer "i" "Creating it at ${JOB_LOG%/*}"
	fi

	func_output_optimizer "i" "Output to console...As $run_as_user_name:$run_as_group_name can see ;)"
	func_output_optimizer "i" "Output to sys log file $SYS_LOG"
	func_output_optimizer "i" "Output to job log file $JOB_LOG"

	func_output_optimizer "w" "!!! ATTENTION !!!         	Parameter 1: Name Part Old i.e. current* 	    	                               !!! ATTENTION !!!"
	func_output_optimizer "w" "!!! ATTENTION !!!         	ONLY wildcards at the beginning and at the end with other real content will work   !!! ATTENTION !!!"
	func_output_optimizer "w" "!!! ATTENTION !!!         	ONLY wildcards with no other real content will NOT work                            !!! ATTENTION !!!"
fi

if [ "$NAME_PART_OLD" = "" ]; then
	func_output_optimizer "c" "File Name Part Old parameter is empty. EXIT"
	exit 1
fi

if [ "$NAME_PART_NEW" = "" ]; then
	func_output_optimizer "c" "File Name Part New parameter is empty. EXIT"
	exit 1
fi

if [ "$FOLDER_TARGET" = "" ]; then
	func_output_optimizer "c" "Folder Source parameter is empty. EXIT"
	exit 1
fi

if [ ! -d "$FOLDER_TARGET" ]; then
	func_output_optimizer "c" "Folder Source parameter $FOLDER_TARGET is not a valid. EXIT"
	exit 1
fi

if [ "$MODE_SWITCH" -gt '2' ] || \
   [[ $MODE_SWITCH =~ [^[:digit:]] ]]; then
        func_output_optimizer "c" "Config Switch parameter $MODE_SWITCH is not a valid. EXIT"
        exit 2
fi

if [ "$FOLDER_DEEP" = "" ] || \
   [ "$FOLDER_DEEP" -gt '2' ] || \
   [ "$FOLDER_DEEP" -eq '0' ]; then
		func_output_optimizer "w" "Folder Deep Value $FOLDER_DEEP is too high, 0 or empty. Set to Default 1"
		FOLDER_DEEP=1
fi

if [ "$FOLDER_RECREATE_RENAME_SWITCH" -gt '1' ] || \
   [[ $FOLDER_RECREATE_RENAME_SWITCH =~ [^[:digit:]] ]]; then
        func_output_optimizer "c" "Folder recreate Switch parameter $FOLDER_RECREATE_RENAME_SWITCH is not a valid. EXIT"
        exit 2
fi

if [ "$CONFIG_SWITCH" -gt '1' ] || \
   [[ $CONFIG_SWITCH =~ [^[:digit:]] ]]; then
        func_output_optimizer "c" "Config Switch parameter $CONFIG_SWITCH is not a valid. EXIT"
        exit 2
fi

if [ "$VERBOSE_SWITCH" -gt '1' ] || \
   [[ $VERBOSE_SWITCH =~ [^[:digit:]] ]]; then
        func_output_optimizer "c" "Verbose Switch parameter $VERBOSE_SWITCH is not a valid. Set to Default 0"
        VERBOSE_SWITCH=0
fi

## Lets roll
## Clean wildcard(s) at the beginning and at the end of $NAME_PART_OLD to match exact filename part for command rename
if [ "$NAME_PART_OLD"  !=  "${NAME_PART_OLD//[\[\]|.? +*]/}" ]; then
	name_part_old_clean=${NAME_PART_OLD//"?"/}
	name_part_old_clean=${name_part_old_clean//"*"/}
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		func_output_optimizer "i" "$mode Name Part Old: $NAME_PART_OLD has wildcard character(s)...  * or ?"
		func_output_optimizer "i" "Cleaned $mode Name Part Old: $name_part_old_clean"
	fi
else
	name_part_old_clean=$NAME_PART_OLD
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		func_output_optimizer "i" "$mode Name Part Old: $name_part_old_clean has NO wildcard character(s)...  * or ?"
	fi
fi

if [ "$name_part_old_clean" = "" ]; then
	func_output_optimizer "c" "Name Part Old / Cleaned parameter is empty. EXIT"
	exit 1
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
	func_output_optimizer "i" "Renaming $mode in $FOLDER_TARGET with name like $NAME_PART_OLD to $NAME_PART_NEW started"
fi

## Start renaming all file(s) in array
if [ $MODE_SWITCH -lt '2' ]; then

	readarray -t files < <(find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART_OLD") &> "$JOB_LOG"
	
	if [ $VERBOSE_SWITCH -eq '1'  ]; then
		if [ ${#files[@]} -eq '0' ]; then
			func_output_optimizer "c" "No file(s) to rename at Folder Target $FOLDER_TARGET with $NAME_PART_OLD to $NAME_PART_NEW"
			exit 1
		else
			func_output_optimizer "i" "This will effect the following ${#files[@]} x file(s)..."
			for file in "${!files[@]}"
			do
				func_output_optimizer "i" "Array file(s) element $file: ${files[$file]}"
			done
		fi
	fi

	if [ $VERBOSE_SWITCH -eq '1'  ]; then
		func_output_optimizer "i" "Starting renaming file(s) at Folder Target $FOLDER_TARGET with $NAME_PART_OLD to $NAME_PART_NEW..."
		find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART_OLD" \
			-exec rename -v "$name_part_old_clean" "$NAME_PART_NEW" {} ";" &> "$JOB_LOG"
	else
		find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART_OLD" \
			-exec rename "$name_part_old_clean" "$NAME_PART_NEW" {} ";" &> "$JOB_LOG"
	fi

	## Check last task for errors
	status=$?
	if [ $status != 0 ]; then
		func_output_optimizer "e" "Error renaming file ${files[$file]} to ${files[$file]/$name_part_old_clean/$NAME_PART_NEW}, code="$status;
		func_output_optimizer "e" "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
		exit $status
	else
		if [ $VERBOSE_SWITCH -eq '1' ]; then
			func_output_optimizer "i" "Renaming file(s) at Folder Target $FOLDER_TARGET with $NAME_PART_OLD to $NAME_PART_NEW} finished successfully"
		fi
	fi
fi

## Start renaming all folder(s) in array
if [ $MODE_SWITCH -gt '0' ]; then

	readarray -t folders < <(find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART_OLD") &> "$JOB_LOG"
	
	if [ $VERBOSE_SWITCH -eq '1'  ]; then
		if [ ${#folders[@]} -eq '0' ]; then
			func_output_optimizer "c" "No folder(s) to rename at Folder Target $FOLDER_TARGET with $NAME_PART_OLD to $NAME_PART_NEW"
			exit 1
		else	
			func_output_optimizer "i" "This will effect the following ${#folders[@]} x folder(s)..."
			for folder in "${!folders[@]}"
			do
				func_output_optimizer "i" "Array folder(s) element $folder: ${folders[$folder]}"
			done
		fi
	fi

	if [ $VERBOSE_SWITCH -eq '1'  ]; then
		func_output_optimizer "i" "Starting renaming folder(s) at Folder Target $FOLDER_TARGET with $NAME_PART_OLD to $NAME_PART_NEW..."
		if [ $FOLDER_RECREATE_RENAME_SWITCH -eq '1'  ]; then

			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART_OLD" \
				-exec rename -v "$name_part_old_clean" "$NAME_PART_NEW" {} \; -exec mkdir -pv {} ";" &> "$JOB_LOG"

		else

			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART_OLD" \
				-exec rename -v "$name_part_old_clean" "$NAME_PART_NEW" {} ";" &> "$JOB_LOG"
		fi
	else
		if [ $FOLDER_RECREATE_RENAME_SWITCH -eq '1'  ]; then

			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART_OLD" \
				-exec rename "$name_part_old_clean" "$NAME_PART_NEW" {} \; -exec mkdir -p {} ";" &> "$JOB_LOG"

		else

			find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART_OLD" \
				-exec rename "$name_part_old_clean" "$NAME_PART_NEW" {} ";" &> "$JOB_LOG"
		fi
	fi

	## Check last task for errors
	status=$?
	if [ $status != 0 ]; then
		func_output_optimizer "e" "Error renaming folder(s) at Folder Target $FOLDER_TARGET with $NAME_PART_OLD to $NAME_PART_NEW, code="$status;
		func_output_optimizer "e" "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
		exit $status
	else
		if [ $VERBOSE_SWITCH -eq '1' ]; then
			func_output_optimizer "i" "Renaming folder(s) at Folder Target $FOLDER_TARGET with $NAME_PART_OLD to $NAME_PART_NEW finished successfully"
		fi
	fi
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
	func_output_optimizer "i" "$(func_output_styler "middle")"
	func_output_optimizer "i" "$(func_output_styler "end")"
fi

status=$?
if [ $status != 0 ]; then
	func_output_optimizer "e" "$(func_output_styler "error")"
	func_output_optimizer "e" "!!! Error renaming $mode at $FOLDER_TARGET from $name_part_old_clean to $NAME_PART_NEW, code=$status !!!"
	func_output_optimizer "e" "!!! Rename Config: $mode Name Part Old=$NAME_PART_OLD, $mode Name Part New=$NAME_PART_NEW, Folder Source=$FOLDER_TARGET, Mode=$mode !!!"
	func_output_optimizer "e" "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
	func_output_optimizer "i" "$(func_output_styler "error")"
    func_output_optimizer "i" "$(func_output_styler "end")"
	exit $status
else
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		func_output_optimizer "i" "<<< Renaming $mode at $FOLDER_TARGET from $name_part_old_clean to $NAME_PART_NEW finished <<<"
		func_output_optimizer "i" "<<< Rename Config: $mode Name Part Old=$NAME_PART_OLD, $mode Name Part New=$NAME_PART_NEW, Folder Source=$FOLDER_TARGET, Mode=$mode <<<"
		func_output_optimizer "i" "<<< Sub Module $file_name_full v$version finished successfully <<<"
		func_output_optimizer "i" "$(func_output_styler "end")"
	fi
	exit $status
fi
