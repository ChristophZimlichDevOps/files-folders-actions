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
declare -i OUTPUT_SWITCH
declare -i VERBOSE_SWITCH
## Clear stuff need for processing
declare    config_file_in
declare -a files
declare -a folders
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
OUTPUT_SWITCH=$7
VERBOSE_SWITCH=$8

## Set the job config FILE from parameter
config_file_in="$HOME/bin/linux/shell/FilesFoldersActions.loc/$file_name.conf.in"
echo "Using config file $config_file_in for $file_name_full"

## Import stuff from config FILE
#set -o allexport
# shellcheck source=$config_file_in disable=SC1091
#. "$config_file_in"
#set +o allexport

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

if [ "$FOLDER_DEEP" = "" ] || \
   [ "$FOLDER_DEEP" -gt '2' ] || \
   [ "$FOLDER_DEEP" -eq '0' ]; then
		echo "Remove Folder Deep Value $FOLDER_DEEP is too high, 0 or empty. Set to Default 1"
		FOLDER_DEEP=1
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

if [ "$FOLDER_DEEP" -gt '2' ] || \
   [ "$FOLDER_DEEP" -eq '0' ] || \
   [ "$FOLDER_DEEP" = "" ]; then
   		echo "Folder Deep Value $FOLDER_DEEP is too high, 0 or empty. EXIT"
		exit 1
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
	echo "Folder Target: $FOLDER_TARGET"
	echo "$mode Name Part: $NAME_PART"
fi

## Lets roll
readarray -t files < <( find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART")
readarray -t folders < <( find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART")

if [ $VERBOSE_SWITCH -eq '1' ]; then
	echo "Remove $mode in $FOLDER_TARGET with name like $NAME_PART started"
fi

## Job containing file(s)
if [ "$MODE_SWITCH" -lt '2' ]; then
	## If job is file(s) only and no file(s) are present with current parameters
	if [ ${#files[@]} -eq '0' ]; then
		echo "You selected $mode to remove...But there are NO $mode with your parameters. EXIT"
		exit 1
	fi

	if [ $VERBOSE_SWITCH -eq '1' ]; then
		echo "This will effect the following ${#files[@]} x file(s)..."

		for file in "${!files[@]}"
		do
			echo "Array files element $file: ${files[$file]}"
		done

		echo "Starting removing file(s) now..."
		find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART" \
			-exec rm -f -v --interactive=never {} ";"
	else
		find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART" \
			-exec rm -f --interactive=never {} ";"
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
		find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART" \
			-exec rmdir --ignore-fail-on-non-empty -v {} ";"
	else
		find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART" \
			-exec rmdir --ignore-fail-on-non-empty {} ";"	
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
