#!/bin/bash

## Creator: Christoph Zimlich
##
##
## Summary
## This script will rename, copy and remove files like you want. Useful for backups for example.
##
## Parameter  1: Folder Source i.e. "/home/backup/mysql/"
## Parameter  2: Folder Target i.e. "/tmp/"
## Parameter  3: Name Part Old i.e. "current*" ONLY wildcards at the beginning and at the end with other real content will work. ONLY wildcards with no other real content will NOT work
## Parameter  4: Name Part New i.e. "$(date +%y%m%d%H%M%S)"
## Parameter  5: Name Part Delete i.e. "$(date +%y%m%d%*)"
## Parameter  6: Script Path...Where the scripts are stored i.e. "/root/bin/"
## Parameter  7: Rename Mode Switch "--rename-files-folders"=File(s) and Folder(s) will be renamed
##               "--rename-folders"=ONLY Folder(s) will be renamed
##               else i.e. "--rename-files"=ONLY File(s) will be renamed
## Parameter  8: Rename Folder Deep Search "--rename-fd=1"=Set the folder deep where File(s) and Folder(s) get renamed
## Parameter  9: Copy Mode Switch "--cp-files-folders"=File(s) and Folder(s) will be copied
##		 "--cp-folders"=ONLY Folder(s) will be copied
##               else i.e. "--cp-files" =ONLY File(s) will be copied
## Parameter 10: Copy Folder Deep Search "--cp-fd=1"=Set the folder deep where File(s) and Folder(s) get copied
## Parameter 11: Remove Mode Switch "--rm-files-folders"=File(s) and Folder(s) will be removed
##               "--rm-folders"=ONLY Folder(s) will be removed
##               else i.e. "--rm-files"=ONLY File(s) will be removed
## Parameter 12: Remove Folder Deep Search "--rm-fd=1"=Set the folder deep where File(s) and Folder(s) get removed
## Parameter 13: Recreate Folders Switch "--recreate-folders"=On...Folders will be recreated too
##               else i.e. "--recreate-folders-not"=Off...Folders will not be recreated
## Parameter 14: Output Switch "--JOB_LOGfile"=On...OUTPUT to JOB_LOGfile
##		 else=Off...OUTPUT to console
## Parameter 15: Verbose Switch "-v"=On, else=Off
##
## Call it like this:
## sh FilesFoldersRenameCpRm.sh "/backup/internal/mysql/" "/backup/external/mysql/" "current*" "$(date +%y%m%d%H%M%S)" "$(date +%y%m%d%H*)" "/root/bin/linux/shell/files-folders-actions/" "--rename-files" "--rename-fd=1" "--cp-files" "--cp-fd=1" "--rm-files" "rm-fd=1" "--recreate-folders-not" "--console" "-v" 
## sh FilesFoldersRenameCpRm.sh "/home/backup/mysql/" "/tmp/" "current*" "$(date +%y%m%d%H%M%S)" "$(date +%y%m%d%H*)" "/root/bin/" "--rename-files-folders" "--rename-fd=2" "--cp-files-folders" "--cp-fd=2" "--rm-files-folders" "rm-fd=2" "--recreate-folders-not" "--console" "-v"

## Clear console to debug that stuff better
#clear

## Enhanced debugging with set -x
#set -x

## Set Stuff
version="0.0.1-alpha.1"
file_name_full="files-folders-aio.sh"
file_name="${file_name_full##*/}"

run_as_user_name=$(whoami)
run_as_user_uid=$(id -u $run_as_user_name)
run_as_group_name=$(id -gn $run_as_user_name)
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

## Clear used stuff
declare    FILES_FOLDER_RENAME_CP_RM_PID
declare    FOLDER_SOURCE
declare    FOLDER_TARGET
declare    NAME_PART_OLD
declare    NAME_PART_NEW
declare    NAME_PART_DELETE
# shellcheck disable=SC2034
declare -i FOLDER_DEEP
declare -i RENAME_MODE_SWITCH
declare -i CP_MODE_SWITCH
declare -i RM_MODE_SWITCH
declare -i RECREATE_FOLDER_SWITCH
declare    SCRIPT_PATH
declare -i OUTPUT_SWITCH
declare -i VERBOSE_SWITCH
declare    JOB_LOG
declare    SYS_LOG
## Needed for processing
declare -i sys_log_file_missing_switch
declare -i job_log_file_missing_switch
declare -i status

## Import stuff from config FILE
set -o allexport
# shellcheck source=$config_file_in disable=SC1091
. "$config_file_in"
set +o allexport

# Set log files
if [ ! -f "$SYS_LOG" ]; then
        sys_log_file_missing_switch=1
        touch "$SYS_LOG"
else
        sys_log_file_missing_switch=0
fi

if [ ! -f "$JOB_LOG" ]; then
        job_log_file_missing_switch=1
        touch "$JOB_LOG"
else
        job_log_file_missing_switch=0
fi

if [ "$OUTPUT_SWITCH" -eq '1' ]; then
        exec 3>&1 4>&2
        trap 'exec 2>&4 1>&3' 0 1 2 3 RETURN
        exec 1>>"$SYS_LOG" 2>&1
fi

## Print file name
if [ "$VERBOSE_SWITCH" -eq '1' ]; then
	sh OutputStyler "start"
	sh OutputStyler "start"
        echo ">>> Master Module $file_name_full v$version starting >>>"
fi

## Check folder sources and targets in PID file
sh "$SCRIPT_PATH""FilesFoldersCpPIDCreate.sh" "$FILES_FOLDER_RENAME_CP_RM_PID" $$ "$FOLDER_SOURCE" "$FOLDER_TARGET" "$OUTPUT" "$VERBOSE"
## Check last task for error(s)
status=$?
if [ $status != 0 ]; then
	echo "Error with PID $FILES_FOLDER_RENAME_CP_RM_PID and Check Copying from Folder Source $FOLDER_SOURCE to Folder Target $FOLDER_TARGET, code="$status;
        if [ "$VERBOSE_SWITCH" -eq '1' ]; then
                echo "!!! Master Module $file_name_full v$version stopped with error(s) !!!"
        fi
        exit $status
else
        if [ "$VERBOSE_SWITCH" -eq '1' ]; then
                echo "Checking PID $FILES_FOLDER_RENAME_CP_RM_PID and Copying from Folder Source $FOLDER_SOURCE to Folder Target $FOLDER_TARGET finished"
        fi
fi

## Remove PID entry from PID file or the hole PID file when job is finished
echo "When job is done clean from PID $FILES_FOLDER_RENAME_CP_RM_PID PID Process ID $$ entry"
# shellcheck disable=SC2154
echo "sh $SCRIPT_PATH$FilesFoldersCpPIDRm.sh $FILES_FOLDER_RENAME_CP_RM_PID $$ $OUTPUT $VERBOSE"
trap 'sh -- $SCRIPT_PATH$FilesFoldersCpPIDRm.sh '"$FILES_FOLDER_RENAME_CP_RM_PID"' '$$' '"$OUTPUT"' '"$VERBOSE"' ' EXIT

## Check last task for error(s)
status=$?
if [ $status != 0 ]; then
        # shellcheck disable=SC2154
        echo "Error with PID $FILES_FOLDER_RENAME_CP_RM_PID and finding PID Process ID $PID_process_id, code=$status";
        if [ "$VERBOSE_SWITCH" -eq '1' ]; then
                echo "!!! Master Module $file_name_full v$version stopped with error(s) !!!"
        fi
        exit $status
else
        if [ "$VERBOSE_SWITCH" -eq '1' ]; then
                echo "Removing entry in PID $FILES_FOLDER_RENAME_CP_RM_PID with PID Process ID $PID_process_id finished"
        fi
fi

if [ "$FOLDER_DEEP" = "" ] || \
   [ "$FOLDER_DEEP" -gt '2' ] || \
   [ "$FOLDER_DEEP" -eq '0' ]; then
        echo "Folder Deep Value $FOLDER_DEEP is too high, 0 or empty. Set to Default 1";FOLDER_DEEP=1
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
        if [ $OUTPUT_SWITCH -eq '1' ]; then
	        sh OutputStyler "start"
        	sh OutputStyler "start"
                echo ">>> Master Module $file_name_full v$version starting >>>"
        fi

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

        echo -n "Renaming File(s) is "
        if [ "$RENAME_MODE_SWITCH" -eq '2' ]; then
                echo "OFF"
        else
                echo "ON"
        fi

        echo -n "Renaming Folder(s) is "
        if [ "$RENAME_MODE_SWITCH" -gt '0' ]; then
                echo "ON"
        else
                echo "OFF"
        fi

        echo "Folder(s) Deep $FOLDER_DEEP"

	echo -n "Copying File(s) is "
        if [ "$CP_MODE_SWITCH" -eq '2' ]; then
                echo "OFF"
        else
                echo "ON"
        fi

        echo -n "Copying Folder(s) is "
        if [ "$CP_MODE_SWITCH" -gt '0' ]; then
                echo "ON"
        else
                echo "OFF"
        fi

	echo -n "Removing File(s) is "
        if [ "$RM_MODE_SWITCH" -eq '2' ]; then
                echo "OFF"
        else
                echo "ON"
        fi

        echo -n "Removing Folder(s) is "
        if [ "$RM_MODE_SWITCH" -gt '0' ]; then
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

        if [ $OUTPUT_SWITCH -eq '1' ]; then
                echo "OUTPUT to JOB_LOGfile $JOB_LOG"
        else
                echo "OUTPUT to console...As you can see xD"
        fi

        if [ $job_log_file_missing_switch -eq '1' ]; then
                echo "Job log file: $JOB_LOG is missing"
                echo "Creating it at $JOB_LOG"
        fi

        if [ $sys_log_file_missing_switch -eq '1' ]; then
                echo "Sys log file: $SYS_LOG is missing"
                echo "Creating it at $SYS_LOG"
        fi
fi

## Check for input error(s)
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

if [ "$SCRIPT_PATH" = "" ]; then
        echo "Script Path parameter is empty. EXIT"
        exit 2
fi

if [ ! -d "$SCRIPT_PATH" ]; then
        echo "Script Path parameter $SCRIPT_PATH is not a valid folder path. EXIT"
        exit 2
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
        echo "Files Folder Rename Copy Remove PID: $FILES_FOLDER_RENAME_CP_RM_PID"
        echo "Folder source: $FOLDER_SOURCE"
        echo "Folder target: $FOLDER_TARGET"
        echo "Name part old: $NAME_PART_OLD" 
        echo "Name part new: $NAME_PART_NEW"
        echo "Name part delete: $NAME_PART_DELETE"
        echo "Script path: $SCRIPT_PATH"
        echo "Folder deep: $FOLDER_DEEP"
        echo "Rename mode switch: $RENAME_MODE_SWITCH"
        echo "Copy mode switch: $CP_MODE_SWITCH"
        echo "Remove mode switch: $RM_MODE_SWITCH"
        echo "Recreate folder switch: $RECREATE_FOLDER_SWITCH"
        echo "Sys log: $SYS_LOG"
        echo "Job log: $JOB_LOG"
        echo "Output switch: $OUTPUT_SWITCH"
        echo "Verbose switch: $VERBOSE_SWITCH"
fi

## Lets roll
## Copy file(s) and/or folder(s) from source to target folder
sh "$SCRIPT_PATH""$SCRIPT_SUB_FILE_FOLDERS_CP" \
        "$FOLDER_SOURCE" \
        "$FOLDER_TARGET" \
        "$NAME_PART_NEW" \
        "$CP_MODE" \
        "$FOLDER_DEEP" \
        "$OUTPUT_SWITCH" \
        "$VERBOSE_SWITCH"

## Rename file(s) and/or folder(s) at source folder
sh "$SCRIPT_PATH""$SCRIPT_SUB_FILE_FOLDERS_RENAME" \
        "$NAME_PART_OLD" \
        "$NAME_PART_NEW" \
        "$FOLDER_SOURCE" \
        "$RENAME_MODE" \
        "$FOLDER_DEEP" \
        "$RECREATE_FOLDER_SWITCH" \
        "$OUTPUT_SWITCH" \
        "$VERBOSE_SWITCH"

## Remove file(s) and/or folder(s) at source folder
sh "$SCRIPT_PATH""$SCRIPT_SUB_FILE_FOLDERS_RM" \
        "$FOLDER_SOURCE" \
        "$NAME_PART_DELETE" \
        "$RM_MODE" \
        "$FOLDER_DEEP" \
        "$OUTPUT_SWITCH" \
        "$VERBOSE_SWITCH"

## For testing: Copy back testing file(s) and/or folder(s)
sh "$SCRIPT_PATH""$SCRIPT_SUB_FILE_FOLDERS_CP" \
        "/home/backup/mysql/full/" \
        "/backup/internal/mysql/" \
        "*" \
        "2" \
        "1" \
        "0"

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
