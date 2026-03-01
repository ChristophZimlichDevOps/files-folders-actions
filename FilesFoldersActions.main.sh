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
## Parameter  5: Name Part Delete i.e. "$(date +%y%m%d%*)"
## Parameter  6: Script Path...Where the scripts are stored i.e. "/root/bin/"
## Parameter  8: Folder Deep where File(s) and Folder(s) get found; Default 1
## Parameter  9: Mode Switch            0=Only files
##                                      1=CFiles and Folders
##                                      2=Only Folders
## Parameter 10: Sub Script for copying i.e. "FilesFoldersActions.cp.sh"
## Parameter 11: Sub Script for renaming i.e. "FilesFoldersActions.rename.sh"
## Parameter 12: Sub Script for removing i.e. "FilesFoldersActions.rm.sh"
## Parameter 13: Recreate Folder Rename Switch  0=Off
##                                              1=On
## Parameter 14: Recreate Folder Remove Switch  0=Off
##                                              1=On
## Parameter 15: Script Path...Where the scripts are stored i.e. "$HOME/bin/"
## Parameter 16: Sys log i.e.           "/var/log/bash/$file_name.log"
## Parameter 17: Job log i.e.           "/tmp/bash/$file_name.log"
## Parameter 18: Verbose Switch         0=Off; Default
##                                      1=On
##
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
##      "1" \
##      "$HOME/bin/linux/bash/FilesFoldersActions/" \
##      "/tmp/bash/FilesFoldersActions/${file_name}_sys.log" \
##      "/tmp/bash/FilesFoldersActions/${file_name}_job.log" \
##      "1" 

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
file_name_full="FilesFoldersActions.main.sh"
file_name="${file_name_full%.*}"

run_as_user_name=$(whoami)
run_as_user_uid=$(id -u "$run_as_user_name")
run_as_group_name=$(id -gn "$run_as_user_name")
run_as_group_gid=$(getent group "$run_as_group_name" | cut -d: -f3)
run_on_hostname=$(hostname -f)

## Clear used stuff
declare    PID_PATH_FULL
declare    FOLDER_SOURCE
declare    FOLDER_TARGET
declare    NAME_PART_OLD
declare    NAME_PART_NEW
declare    NAME_PART_RM
declare -i FOLDER_DEEP
declare -i MODE_SWITCH
declare    SCRIPT_SUB_FILE_CP
declare    SCRIPT_SUB_FILE_RENAME
declare    SCRIPT_SUB_FILE_RM
declare -i FOLDER_RECREATE_RENAME_SWITCH
declare -i FOLDER_RECREATE_RM_SWITCH
declare    SCRIPT_PATH
declare    SYS_LOG
declare    JOB_LOG
declare -i CONFIG_SWITCH
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
NAME_PART_RM=$6
FOLDER_DEEP=$7
MODE_SWITCH=$8
SCRIPT_SUB_FILE_CP=$9
SCRIPT_SUB_FILE_RENAME=${10}
SCRIPT_SUB_FILE_RM=${11}
FOLDER_RECREATE_RENAME_SWITCH=${12}
FOLDER_RECREATE_RM_SWITCH=${13}
SCRIPT_PATH=${14}
SYS_LOG=${15}
JOB_LOG=${16}
CONFIG_SWITCH=${17}
VERBOSE_SWITCH=${18}

#if [ "$2" = "" ]; then
        ## Set the job config FILE from parameter
        #config_file_in=$1
        config_file_in="$HOME/bin/linux/bash/local/FilesFoldersActions/FilesFoldersActions.main.conf.in"
        func_output_optimizer "i" "Using config file $config_file_in for $file_name_full"

        ## Import stuff from config FILE
        set -o allexport
        # shellcheck disable=SC1090
        . "$config_file_in"
        set +o allexport
#fi

## Check this script is running as root !
#if [ "$run_as_user_uid" != "0" ]; then
#    func_output_optimizer "w" "!!! ATTENTION !!!		    YOU MUST RUN THIS SCRIPT AS ROOT / SUPERUSER	        !!! ATTENTION !!!"
#    func_output_optimizer "w" "!!! ATTENTION !!!		           TO USE chown AND chmod IN rsync	                !!! ATTENTION !!!"
#    func_output_optimizer "w" "!!! ATTENTION !!!		     ABORT THIS SCRIPT IF YOU NEED THIS FEATURES		!!! ATTENTION !!!"
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

## Print file name
## Talk to you if you want
if [ $VERBOSE_SWITCH -eq '1' ]; then
        func_output_optimizer "i" "$(func_output_styler "start")"
        func_output_optimizer "i" "$(func_output_styler "start")"
        func_output_optimizer "i" ">>> Master Module $file_name_full v$version starting >>>"
        func_output_optimizer "i" "$(func_output_styler "start")"
        func_output_optimizer "i" "$(func_output_styler "middle")"
	func_output_optimizer "w" "!!! ATTENTION !!!		Parameter 3: Name Part Old i.e. current*					   !!! ATTENTION !!!"
        func_output_optimizer "w" "!!! ATTENTION !!!		ONLY wildcards at the beginning and at the end with other real content will work   !!! ATTENTION !!!"
        func_output_optimizer "w" "!!! ATTENTION !!!		ONLY wildcards with no other real content will NOT work				   !!! ATTENTION !!!"
	func_output_optimizer "i" "Filename: $file_name_full"
        func_output_optimizer "i" "Version: v$version"
        func_output_optimizer "i" "Run as user name: $run_as_user_name"
        func_output_optimizer "i" "Run as user uid: $run_as_user_uid"
        func_output_optimizer "i" "Run as group: $run_as_group_name"
        func_output_optimizer "i" "Run as group gid: $run_as_group_gid"
        func_output_optimizer "i" "Run on host: $run_on_hostname"
        func_output_optimizer "i" "Verbose is ON"
        func_output_optimizer "i" "Files Folder Main PID: $PID_PATH_FULL"
        func_output_optimizer "i" "Folder source: $FOLDER_SOURCE"
        func_output_optimizer "i" "Folder target: $FOLDER_TARGET"
        func_output_optimizer "i" "Name part old: $NAME_PART_OLD" 
        func_output_optimizer "i" "Name part new: $NAME_PART_NEW"
        func_output_optimizer "i" "Name part delete: $NAME_PART_RM"
        func_output_optimizer "i" "Script path: $SCRIPT_PATH"
        func_output_optimizer "i" "Folder deep: $FOLDER_DEEP"

        if [ "$MODE_SWITCH" -eq '2' ]; then
                func_output_optimizer "i" "Mode for file(s) is OFF"
        else
                func_output_optimizer "i" "Mode for file(s) is ON"
        fi

        if [ "$MODE_SWITCH" -lt '1' ]; then
                func_output_optimizer "i" "Mode for folder(s) is OFF"
        else
                func_output_optimizer "i" "Mode for folder(s) is ON"
        fi

        if [ $FOLDER_RECREATE_RENAME_SWITCH -eq '1' ]; then
                func_output_optimizer "i" "Recreating Folder(s) after renaming is ON"
        else
                func_output_optimizer "i" "Recreating Folder(s) after renaming is OFF"
        fi

        if [ $FOLDER_RECREATE_RM_SWITCH -eq '1' ]; then
                func_output_optimizer "i" "Recreating Folder(s) after removing is ON"
        else
                func_output_optimizer "i" "Recreating Folder(s) after removing is OFF"
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
		func_output_optimizer "w" "Job log file: $JOB_LOG is missing"
		func_output_optimizer "i" "Creating it at $JOB_LOG"
	fi

        if [ "$job_log_folder_missing_switch" -eq '1' ]; then
		func_output_optimizer "w" "Sys log folder: ${JOB_LOG%/*} is missing"
		func_output_optimizer "i" "Creating it at ${JOB_LOG%/*}"
	fi

        func_output_optimizer "i" "Output to console...As $run_as_user_name:$run_as_group_name can see ;)"
        func_output_optimizer "i" "Output to sys log file $SYS_LOG"
        func_output_optimizer "i" "Output to job log file $JOB_LOG"

fi

## Check for input error(s)
if [ "$PID_PATH_FULL" = "" ]; then
        func_output_optimizer "c" "PID File parameter is empty. EXIT"
        exit 2
fi

if [ ! -d "${PID_PATH_FULL%/*}" ]; then
        func_output_optimizer "c" "PID File directory ${PID_PATH_FULL%/*} is not valid. EXIT"
        exit 2
fi

if [ "$FOLDER_SOURCE" = "" ]; then
        func_output_optimizer "c" "Folder Source parameter is empty. EXIT"
        exit 2
fi

if [ ! -d "$FOLDER_SOURCE" ]; then
        func_output_optimizer "c" "Folder Source parameter $FOLDER_SOURCE is not a valid folder path. EXIT"
        exit 2
fi

if [ "$FOLDER_TARGET" = "" ]; then
        func_output_optimizer "c" "Folder Target parameter is empty. EXIT"
        exit 2
fi

if [ ! -d "$FOLDER_TARGET" ]; then
        func_output_optimizer "c" "Folder Target parameter $FOLDER_TARGET is not a valid folder path. EXIT"
        exit 2
fi

if [ "$FOLDER_SOURCE" = "$FOLDER_TARGET" ]; then
        func_output_optimizer "c" "Folder Source parameter $FOLDER_SOURCE is the same like Folder Target $FOLDER_TARGET. EXIT"
        exit 2
fi

if [ "$NAME_PART_OLD" = "" ]; then
        func_output_optimizer "c" "Name Part Old parameter is empty. EXIT"
        exit 2
fi

if [ "$NAME_PART_NEW" = "" ]; then
        func_output_optimizer "c" "Name Part New parameter is empty. EXIT"
        exit 2
fi

if [ "$NAME_PART_RM" = "" ]; then
        func_output_optimizer "c" "Name Part Delete parameter is empty. EXIT"
        exit 2
fi

if [ "$FOLDER_DEEP" = "" ] || \
   [ "$FOLDER_DEEP" -gt '2' ] || \
   [ "$FOLDER_DEEP" -eq '0' ]; then
        func_output_optimizer "w" "Folder Deep Value $FOLDER_DEEP is too high, 0 or empty. Set to Default 1"
        FOLDER_DEEP=1
fi

if [ "$MODE_SWITCH" -gt '2' ] || \
   [[ $MODE_SWITCH =~ [^[:digit:]] ]]; then
        func_output_optimizer "c" "Mode Switch parameter $MODE_SWITCH is not a valid. EXIT"
        exit 2
fi

if [ "$SCRIPT_SUB_FILE_CP" = "" ]; then
        func_output_optimizer "c" "Script Sub file copy parameter is empty. EXIT"
        exit 2
fi

if [ "$SCRIPT_SUB_FILE_RENAME" = "" ]; then
        func_output_optimizer "c" "Script Sub file rename parameter is empty. EXIT"
        exit 2
fi

if [ "$SCRIPT_SUB_FILE_RM" = "" ]; then
        func_output_optimizer "c" "Script Sub file remove parameter is empty. EXIT"
        exit 2
fi

if [ "$FOLDER_RECREATE_RENAME_SWITCH" -gt '1' ] || \
   [[ $FOLDER_RECREATE_RENAME_SWITCH =~ [^[:digit:]] ]]; then
        func_output_optimizer "c" "Recreate Folder Switch parameter $FOLDER_RECREATE_RENAME_SWITCH is not a valid. EXIT"
        exit 2
fi

if [ "$SCRIPT_PATH" = "" ]; then
        func_output_optimizer "c" "Script Path parameter is empty. EXIT"
        exit 2
fi

if [ ! -d "$SCRIPT_PATH" ]; then
        func_output_optimizer "c" "Script Path parameter $SCRIPT_PATH is not a valid folder path. EXIT"
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
## Copy file(s) and/or folder(s) from source to target folder
# bashcheck disable=SC1090
sh "$SCRIPT_PATH""$SCRIPT_SUB_FILE_CP" \
        "$PID_PATH_FULL" \
        "$FOLDER_SOURCE" \
        "$FOLDER_TARGET" \
        "$NAME_PART_OLD" \
        "$MODE_SWITCH" \
        "$FOLDER_DEEP" \
        "$SCRIPT_PATH" \
        "$SCRIPT_SUB_FILE_PID_CREATE" \
        "$SCRIPT_SUB_FILE_PID_RM" \
        "$SYS_LOG" \
        "$JOB_LOG" \
        "$CONFIG_SWITCH" \
        "$VERBOSE_SWITCH"

## Rename file(s) and/or folder(s) at source folder
# bashcheck disable=SC1090
sh "$SCRIPT_PATH""$SCRIPT_SUB_FILE_RENAME" \
        "$NAME_PART_OLD" \
        "$NAME_PART_NEW" \
        "$FOLDER_SOURCE" \
        "$MODE_SWITCH" \
        "$FOLDER_DEEP" \
        "$FOLDER_RECREATE_RENAME_SWITCH" \
        "$SYS_LOG" \
        "$JOB_LOG" \
        "$CONFIG_SWITCH" \
        "$VERBOSE_SWITCH"

## Rename file(s) and/or folder(s) at target folder
# bashcheck disable=SC1090
sh "$SCRIPT_PATH""$SCRIPT_SUB_FILE_RENAME" \
        "$NAME_PART_OLD" \
        "$NAME_PART_NEW" \
        "$FOLDER_TARGET" \
        "$MODE_SWITCH" \
        "$FOLDER_DEEP" \
        "$FOLDER_RECREATE_RENAME_SWITCH" \
        "$SYS_LOG" \
        "$JOB_LOG" \
        "$CONFIG_SWITCH" \
        "$VERBOSE_SWITCH"

## Remove file(s) and/or folder(s) at source folder
# bashcheck disable=SC1090
sh "$SCRIPT_PATH""$SCRIPT_SUB_FILE_RM" \
        "$FOLDER_SOURCE" \
        "$NAME_PART_RM" \
        "$MODE_SWITCH" \
        "$FOLDER_DEEP" \
        "$FOLDER_RECREATE_RM_SWITCH" \
        "$SYS_LOG" \
        "$JOB_LOG" \
        "$CONFIG_SWITCH" \
        "$VERBOSE_SWITCH"

## Remove file(s) and/or folder(s) at target folder
# bashcheck disable=SC1090
sh "$SCRIPT_PATH""$SCRIPT_SUB_FILE_RM" \
        "$FOLDER_TARGET" \
        "$NAME_PART_RM" \
        "$MODE_SWITCH" \
        "$FOLDER_DEEP" \
        "$FOLDER_RECREATE_RM_SWITCH" \
        "$SYS_LOG" \
        "$JOB_LOG" \
        "$CONFIG_SWITCH" \
        "$VERBOSE_SWITCH"

## For testing: Copy back testing file(s) and/or folder(s)
# bashcheck disable=SC1090
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
        "$VERBOSE_SWITCH"

if [ "$VERBOSE_SWITCH" -eq '1' ]; then
        func_output_optimizer "i" "$(func_output_styler "middle")"
        func_output_optimizer "i" "$(func_output_styler "end")"
        func_output_optimizer "i" "$(func_output_styler "end")"
fi

## Check last task for errors
status=$?
if [ $status != 0 ]; then
	if [ "$VERBOSE_SWITCH" -eq '1' ]; then
                func_output_optimizer "e" "$(func_output_styler "error")"
        fi
        func_output_optimizer "e" "!!! Error Master Module $file_name_full from $FOLDER_SOURCE to $FOLDER_TARGET, code=$status !!!"
        if [ "$VERBOSE_SWITCH" -eq '1' ]; then
                func_output_optimizer "e" "!!! Master Module $file_name_full v$version stopped with error(s) !!!"
                func_output_optimizer "e" "$(func_output_styler "error")"
                func_output_optimizer "i" "$(func_output_styler "end")"
                func_output_optimizer "i" "$(func_output_styler "end")\n"
        fi
        exit $status
else
        if [ "$VERBOSE_SWITCH" -eq '1' ]; then
                func_output_optimizer "i" "<<< Master Module $file_name_full v$version finished successfully <<<"
                func_output_optimizer "i" "$(func_output_styler "end")"
                func_output_optimizer "i" "$(func_output_styler "end")\n"
        fi
        exit $status
fi
