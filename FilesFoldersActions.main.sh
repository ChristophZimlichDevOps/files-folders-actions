#!/bin/bash

## Creator: Christoph Zimlich
##
##
## Summary
## This script will rename, copy and remove files and folders like you want. Useful for backups for example.
##
## Parameter  1: Folder Source i.e.    "/home/backup/mysql/"
## Parameter  2: Folder Target i.e.    "/tmp/"
## Parameter  3: Name Part Old i.e.    "current*" ONLY wildcards at the beginning and at the end with other real content will work. ONLY wildcards with no other real content will NOT work
## Parameter  4: Name Part New i.e.    "$(date +%y%m%d%H%M%S)"
## Parameter  5: Name Part Delete i.e. "$(date +%y%m%d -d'1 year ago')*"
## Parameter  6: Script Path...Where the scripts are stored i.e. "/root/bin/"
## Parameter  8: Folder Deep "1" Set the folder deep where File(s) and Folder(s) get found
## Parameter  9: Mode Switch   0=Only files
##                             1=CFiles and Folders
##                             2=Only Folders
## Parameter 10: Sub Script for copying i.e. "FilesFoldersActions.cp.sh"
## Parameter 11: Sub Script for renaming i.e. "FilesFoldersActions.rename.sh"
## Parameter 12: Sub Script for removing i.e. "FilesFoldersActions.remove.sh"
## Parameter 13: Recreate Folder Switch 0=Off
##                                      1=On
## Parameter 14: Script Path...Where the scripts are stored i.e. "$HOME/bin/"
## Parameter 15: Sys log i.e. "/var/log/bash/$file_name.log"
## Parameter 16: Job log i.e. "/tmp/bash/$file_name.log"
## Parameter 17: Output Switch      0=Console
##                                  1=Logfile; Default
## Parameter 18: Verbose Switch     0=Off
##                                  1=On; Default
##
## Call it like this:
## sh FilesFoldersActions.main.sh \
##      "/backup/internal/mysql/" \
##      "/backup/external/mysql/" \
##      "current*" \
##      "$(date +%y%m%d%H%M%S)" \
##      "$(date +%y%m%d -d'1 year ago')" \
##      "1" \
##      "1" \
##      "FilesFoldersActions.cp.sh" \
##      "FilesFoldersActions.rename.sh" \
##      "FilesFoldersActions.rm.sh" \
##      "1" \
##      "$HOME/bin/linux/shell/FilesFoldersActions/" \
##      "/tmp/bash/FilesFoldersActions/${file_name}_sys.log" \
##      "/tmp/bash/FilesFoldersActions/${file_name}_job.log" \
##      "0" \
##      "1" 

## Clear console to debug that stuff better
#clear

## Enhanced debugging with set -x
#set -x

## Set Stuff
version="0.0.1-alpha.1"
file_name_full="FilesFoldersActions.main.sh"
file_name="${file_name_full%.*}"

run_as_user_name=$(whoami)
run_as_user_uid=$(id -u "$run_as_user_name")
run_as_group_name=$(id -gn "$run_as_user_name")
run_as_group_gid=$(getent group "$run_as_group_name" | cut -d: -f3)
run_on_hostname=$(hostname -f)

## Check this script is running as root !
if [ "$run_as_user_uid" != "0" ]; then
    echo "!!! ATTENTION !!!		    YOU MUST RUN THIS SCRIPT AS ROOT / SUPERUSER	        !!! ATTENTION !!!"
    echo "!!! ATTENTION !!!		           TO USE chown AND chmod IN rsync	                !!! ATTENTION !!!"
    echo "!!! ATTENTION !!!		     ABORT THIS SCRIPT IF YOU NEED THIS FEATURES		    !!! ATTENTION !!!"
fi

## Clear used stuff
declare    PID_PATH_FULL
declare    FOLDER_SOURCE
declare    FOLDER_TARGET
declare    NAME_PART_OLD
declare    NAME_PART_NEW
declare    NAME_PART_DELETE
declare -i FOLDER_DEEP
declare -i MODE_SWITCH
declare    SCRIPT_SUB_FILE_CP
declare    SCRIPT_SUB_FILE_RENAME
declare    SCRIPT_SUB_FILE_RM
declare -i RECREATE_FOLDER_SWITCH
declare    SCRIPT_PATH
declare    SYS_LOG
declare    JOB_LOG
declare -i OUTPUT_SWITCH
declare -i VERBOSE_SWITCH
## Needed for processing
declare    config_file_in
declare -i sys_log_folder_missing_switch=0
declare -i sys_log_file_missing_switch=0
declare -i job_log_folder_missing_switch=0
declare -i job_log_file_missing_switch=0
declare -i status

# Set parameters
PID_PATH_FULL=$1
FOLDER_SOURCE=$2
FOLDER_TARGET=$3
NAME_PART_OLD=$4 
NAME_PART_NEW=$5 
NAME_PART_DELETE=$6
FOLDER_DEEP=$7
MODE_SWITCH=$8
SCRIPT_SUB_FILE_CP=$9
SCRIPT_SUB_FILE_RENAME=${10}
SCRIPT_SUB_FILE_RM=${11}
RECREATE_FOLDER_SWITCH=${12}
SCRIPT_PATH=${13}
SYS_LOG=${14}
JOB_LOG=${15}
CONFIG_SWITCH=${16}
OUTPUT_SWITCH=${17}
VERBOSE_SWITCH=${18}

## Set the job config FILE from parameter
config_file_in="$HOME/bin/linux/shell/local/FilesFoldersActions/$file_name.conf.in"
echo "Using config file $config_file_in for $file_name_full"

## Import stuff from config FILE
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

if [ "$FOLDER_DEEP" = "" ] || \
   [ "$FOLDER_DEEP" -gt '2' ] || \
   [ "$FOLDER_DEEP" -eq '0' ]; then
        echo "Folder Deep Value $FOLDER_DEEP is too high, 0 or empty. Set to Default 1";FOLDER_DEEP=1
fi

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
	sh OutputStyler "middle"
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
        echo "Verbose is ON"
        echo "Files Folder Main PID: $PID_PATH_FULL"
        echo "Folder source: $FOLDER_SOURCE"
        echo "Folder target: $FOLDER_TARGET"
        echo "Name part old: $NAME_PART_OLD" 
        echo "Name part new: $NAME_PART_NEW"
        echo "Name part delete: $NAME_PART_DELETE"
        echo "Script path: $SCRIPT_PATH"
        echo "Folder deep: $FOLDER_DEEP"

        echo -n "Mode for file(s) is "
        if [ "$MODE_SWITCH" -eq '2' ]; then
                echo "OFF"
        else
                echo "ON"
        fi

        echo -n "Mode for folder(s) is "
        if [ "$MODE_SWITCH" -gt '0' ]; then
                echo "ON"
        else
                echo "OFF"
        fi

        echo -n "Recreating Folder(s) after removing is "
        if [ $RECREATE_FOLDER_SWITCH -eq '1' ]; then
                echo "ON"
        else
                echo "OFF"
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

## Check for input error(s)
if [ "$PID_PATH_FULL" = "" ]; then
        echo "PID File parameter is empty. EXIT"
        exit 2
fi

if [ ! -d "${PID_PATH_FULL%/*}" ]; then
        echo "PID File directory ${PID_PATH_FULL%/*} is not valid. EXIT"
        exit 2
fi

if [ "$FOLDER_SOURCE" = "" ]; then
        echo "Folder Source parameter is empty. EXIT"
        exit 2
fi

if [ ! -d "$FOLDER_SOURCE" ]; then
        echo "Folder Source parameter $FOLDER_SOURCE is not a valid folder path. EXIT"
        exit 2
fi

if [ "$FOLDER_TARGET" = "" ]; then
        echo "Folder Target parameter is empty. EXIT"
        exit 2
fi

if [ ! -d "$FOLDER_TARGET" ]; then
        echo "Folder Target parameter $FOLDER_TARGET is not a valid folder path. EXIT"
        exit 2
fi

if [ "$FOLDER_SOURCE" = "$FOLDER_TARGET" ]; then
        echo "Folder Source parameter $FOLDER_SOURCE is the same like Folder Target $FOLDER_TARGET. EXIT"
        exit 2
fi

if [ "$NAME_PART_OLD" = "" ]; then
        echo "Name Part Old parameter is empty. EXIT"
        exit 2
fi

if [ "$NAME_PART_NEW" = "" ]; then
        echo "Name Part New parameter is empty. EXIT"
        exit 2
fi

if [ "$NAME_PART_DELETE" = "" ]; then
        echo "Name Part Delete parameter is empty. EXIT"
        exit 2
fi

if [ "$FOLDER_DEEP" = "" ]; then
        echo "Script Path parameter is empty. EXIT"
        exit 2
fi

if [ "$MODE_SWITCH" -gt '2' ] || \
   [[ $MODE_SWITCH =~ [^[:digit:]] ]]; then
        echo "Mode Switch parameter $MODE_SWITCH is not a valid. EXIT"
        exit 2
fi

if [ "$SCRIPT_SUB_FILE_CP" = "" ]; then
        echo "Script Sub file copy parameter is empty. EXIT"
        exit 2
fi

if [ "$SCRIPT_SUB_FILE_RENAME" = "" ]; then
        echo "Script Sub file rename parameter is empty. EXIT"
        exit 2
fi

if [ "$SCRIPT_SUB_FILE_RM" = "" ]; then
        echo "Script Sub file remove parameter is empty. EXIT"
        exit 2
fi

if [ "$RECREATE_FOLDER_SWITCH" -gt '1' ] || \
   [[ $RECREATE_FOLDER_SWITCH =~ [^[:digit:]] ]]; then
        echo "Recreate Folder Switch parameter $RECREATE_FOLDER_SWITCH is not a valid. EXIT"
        exit 2
fi

if [ "$SCRIPT_PATH" = "" ]; then
        echo "Script Path parameter is empty. EXIT"
        exit 2
fi

if [ ! -d "$SCRIPT_PATH" ]; then
        echo "Script Path parameter $SCRIPT_PATH is not a valid folder path. EXIT"
        exit 2
fi

if [ "$CONFIG_SWITCH" -gt '1' ] || \
   [[ $CONFIG_SWITCH =~ [^[:digit:]] ]]; then
        echo "Config Switch parameter $CONFIG_SWITCH is not a valid. EXIT"
        exit 2
fi

if [ "$OUTPUT_SWITCH" -gt '1' ] || \
   [[ $OUTPUT_SWITCH =~ [^[:digit:]] ]]; then
        echo "Output Switch parameter $OUTPUT_SWITCH is not a valid. EXIT"
        exit 2
fi

if [ "$VERBOSE_SWITCH" -gt '1' ] || \
   [[ $VERBOSE_SWITCH =~ [^[:digit:]] ]]; then
        echo "Verbose Switch parameter $VERBOSE_SWITCH is not a valid. EXIT"
        exit 2
fi

## Lets roll
## Copy file(s) and/or folder(s) from source to target folder
# shellcheck disable=SC1090
sh "$SCRIPT_PATH""$SCRIPT_SUB_FILE_CP" \
        "$PID_PATH_FULL" \
        "$FOLDER_SOURCE" \
        "$FOLDER_TARGET" \
        "$NAME_PART_NEW" \
        "$MODE_SWITCH" \
        "$FOLDER_DEEP" \
        "$SCRIPT_PATH" \
        "$SCRIPT_SUB_FILE_PID_CREATE" \
        "$SCRIPT_SUB_FILE_PID_RM" \
        "$SYS_LOG" \
        "$JOB_LOG" \
        "$CONFIG_SWITCH" \
        "$OUTPUT_SWITCH" \
        "$VERBOSE_SWITCH"

## Rename file(s) and/or folder(s) at source folder
# shellcheck disable=SC1090
sh "$SCRIPT_PATH""$SCRIPT_SUB_FILE_RENAME" \
        "$NAME_PART_OLD" \
        "$NAME_PART_NEW" \
        "$FOLDER_SOURCE" \
        "$MODE_SWITCH" \
        "$FOLDER_DEEP" \
        "$RECREATE_FOLDER_SWITCH" \
        "$SYS_LOG" \
        "$JOB_LOG" \
        "$CONFIG_SWITCH" \
        "$OUTPUT_SWITCH" \
        "$VERBOSE_SWITCH"

## Rename file(s) and/or folder(s) at target folder
# shellcheck disable=SC1090
sh "$SCRIPT_PATH""$SCRIPT_SUB_FILE_RENAME" \
        "$NAME_PART_OLD" \
        "$NAME_PART_NEW" \
        "$FOLDER_TARGET" \
        "$MODE_SWITCH" \
        "$FOLDER_DEEP" \
        "$RECREATE_FOLDER_SWITCH" \
        "$SYS_LOG" \
        "$JOB_LOG" \
        "$CONFIG_SWITCH" \
        "$OUTPUT_SWITCH" \
        "$VERBOSE_SWITCH"

## Remove file(s) and/or folder(s) at source folder
# shellcheck disable=SC1090
sh "$SCRIPT_PATH""$SCRIPT_SUB_FILE_RM" \
        "$FOLDER_SOURCE" \
        "$NAME_PART_DELETE" \
        "$MODE_SWITCH" \
        "$FOLDER_DEEP" \
        "$SYS_LOG" \
        "$JOB_LOG" \
        "$CONFIG_SWITCH" \
        "$OUTPUT_SWITCH" \
        "$VERBOSE_SWITCH"

## Remove file(s) and/or folder(s) at target folder
# shellcheck disable=SC1090
sh "$SCRIPT_PATH""$SCRIPT_SUB_FILE_RM" \
        "$FOLDER_TARGET" \
        "$NAME_PART_DELETE" \
        "$MODE_SWITCH" \
        "$FOLDER_DEEP" \
        "$SYS_LOG" \
        "$JOB_LOG" \
        "$CONFIG_SWITCH" \
        "$OUTPUT_SWITCH" \
        "$VERBOSE_SWITCH"

## For testing: Copy back testing file(s) and/or folder(s)
# shellcheck disable=SC1090
sh "$SCRIPT_PATH""$SCRIPT_SUB_FILE_CP" \
       "$PID_PATH_FULL" \
        "/home/.backup/mysql/root/" \
        "/home/.backup/mysql/" \
        "*" \
        "2" \
        "1" \
        "$SCRIPT_PATH" \
        "$SCRIPT_SUB_FILE_PID_CREATE" \
        "$SCRIPT_SUB_FILE_PID_RM" \
        "$SYS_LOG" \
        "$JOB_LOG" \
        "$CONFIG_SWITCH" \
        "$OUTPUT_SWITCH" \
        "$VERBOSE_SWITCH"

if [ "$VERBOSE_SWITCH" -eq '1' ]; then
        sh OutputStyler "middle"
        sh OutputStyler "end"
        sh OutputStyler "end"
fi

## Check last task for errors
status=$?
if [ $status != 0 ]; then
	if [ "$VERBOSE_SWITCH" -eq '1' ]; then
                sh OutputStyler "error"
        fi
        echo "!!! Error Master Module $file_name_full from $FOLDER_SOURCE to $FOLDER_TARGET, code=$status !!!"
        if [ "$VERBOSE_SWITCH" -eq '1' ]; then
                echo "!!! Master Module $file_name_full v$version stopped with error(s) !!!"
		sh OutputStyler "error"
		sh OutputStyler "end"
	        sh OutputStyler "end"
        fi
        exit $status
else
        if [ "$VERBOSE_SWITCH" -eq '1' ]; then
                echo "<<< Master Module $file_name_full v$version finished successfully <<<"
                sh OutputStyler "end"
                sh OutputStyler "end"
        fi
        exit $status
fi
