#!/bin/bash

## Creator: Christoph Zimlich
##
##
## Summary
## This script will remove files like you want. Useful for backups for example.
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
## sh files-folders-rm.sh "/home/.backup/mysql/sub1" "$(date +%y%m%d*)" "0" "1" "/var/log/bash/$file_name.log" "/tmp/bash/$file_name.log" "1"

## Clear console to debug that stuff better
#clear

## Enhanced debugging with set -x
#set -x

## Set Stuff
version="0.0.1-alpha.1"
file_name_full="files-folders-rm.sh"
file_name="${file_name_full%.*}"

run_as_user_name=$(whoami)
run_as_user_uid=$(id -u "$run_as_user_name")
run_as_group_name=$(id -gn "$run_as_user_name")
run_as_group_gid=$(getent group "$run_as_group_name" | cut -d: -f3)
run_on_hostname=$(hostname -f)

config_file_in="$HOME/bin/linux/shell/files-folders-actions.loc/$file_name.conf.in"
echo "Using config file $config_file_in for $file_name_full"

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
declare -i job_log_file_missing_switch
declare -i sys_log_file_missing_switch
declare -a files
declare -a folders
declare -i status

## Import stuff from config FILE
set -o allexport
# shellcheck source=$config_file_in disable=SC1091
. "$config_file_in"
set +o allexport

## Check for arguments
#FOLDER_TARGET=$1
#NAME_PART=$2
#MODE_SWITCH=$3
#FOLDER_DEEP=$4
#OUTPUT_SWITCH=$5
#VERBOSE_SWITCH=$6

if [ "$MODE_SWITCH" -eq '1' ]; then
	mode="file(s) and folder(s)"
elif [ "$MODE_SWITCH" -eq '2' ]; then
	mode="folder(s)"
else
	mode="file(s)"
fi

if [ "$FOLDER_DEEP" = "" ] || \
   [ "$FOLDER_DEEP" -gt '2' ] || \
   [ "$FOLDER_DEEP" -eq '0' ]; then
		echo "Remove Folder Deep Value $FOLDER_DEEP is too high, 0 or empty. Set to Default 1"
		FOLDER_DEEP=1
fi

## Print file name
if [ $VERBOSE_SWITCH -eq '1' ]; then
    sh output-styler "start"
    echo ">>> Sub Module $file_name_full v$version starting >>>"
	echo ">>> Remove Config: Folder Target=$FOLDER_TARGET, Name Part=$NAME_PART, Mode=$mode >>>"
fi

# Check if $run_as_user_name:$run_as_group_name have write access to log files
if [ "$OUTPUT_SWITCH" -eq '0' ]; then

	if [ ! -w "${SYS_LOG%/*}" ]; then
		echo "$run_as_user_name:$run_as_group_name don't have write access for syslog FILE $SYS_LOG."
	fi

	if [ ! -w "${JOB_LOG%/*}" ]; then
		echo "$run_as_user_name:$run_as_group_name don't have write access for job log FILE $JOB_LOG."
	fi

	if [ ! -w "${SYS_LOG%/*}" ] || \
	   [ ! -w "${JOB_LOG%/*}" ]; then
		echo "Please check the config file $config_file_in. EXIT"
		exit 2
	fi
fi

## Set log files
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

## If output is to logfile
if [ $OUTPUT_SWITCH -eq '1' ]; then
	exec 3>&1 4>&2
	trap 'exec 2>&4 1>&3' 0 1 2 3 RETURN
	exec 1>>"$SYS_LOG" 2>&1
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
	if [ $OUTPUT_SWITCH -eq '1' ]; then
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
	if [ $sys_log_file_missing_switch -eq '1' ]; then
		echo "Sys log file: $SYS_LOG is missing"
		echo "Creating it at $SYS_LOG"
    fi

	if [ $job_log_file_missing_switch -eq '1' ]; then
		echo "Job log file: $JOB_LOG is missing"
		echo "Creating it at $JOB_LOG"
    fi

    if [ $OUTPUT_SWITCH -eq '0' ]; then
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
readarray -t files < <( find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART" -ls | cut -b 91- )
readarray -t folders < <( find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART" -ls | cut -b 91- )

if [ $VERBOSE_SWITCH -eq '1' ]; then
	echo "Remove $mode in $FOLDER_TARGET with name like $NAME_PART started"
fi

## Job containing file(s)
if [ "$MODE_SWITCH" -lt '2' ]; then
	## If job is file(s) only and no file(s) are present with current parameters
	if [ "$MODE_SWITCH" -eq '0' ] && \
	   [ ${#files[@]} -eq '0' ]; then
		echo "You selected $mode to remove...But there are NO $mode with your parameters. EXIT"
		exit 1
	fi

	if [ $VERBOSE_SWITCH -eq '1' ]; then
		echo "This will effect the following ${#files[@]} x file(s)..."
	fi
	for file in "${!files[@]}"
	do
		if [ $VERBOSE_SWITCH -eq '1' ]; then
			echo "Array files element $file: ${files[$file]}"
			echo "Working on file: ${files[$file]}"
			rm -f -R -v --interactive=never '${files[$file]}'
		else
			rm -f -R --interactive=never '${files[$file]}'
		fi
	done
fi

## Job containing folder(s)
if [ "$MODE_SWITCH" -gt '0' ]; then

	## If job is folder(s) only and no folder(s) are present with current parameters
	if [ "$MODE_SWITCH" -eq '2' ] && \
	[ ${#folders[@]} -eq '0' ]; then
		echo "You selected $mode to remove...But there are NO $mode with your parameters. Please check this. EXIT"
		exit 1
	fi

	if [ $VERBOSE_SWITCH -eq '1' ]; then
		echo "This will effect the following ${#folders[@]} folder(s)..."
	fi

	for folder in "${!folders[@]}"
	do

		if [ ! -d "${folders[$folder]}" ]; then
			echo "Folder Source parameter ${folders[$folder]} is not a valid folder path. EXIT"
			break
		fi

		if [ $VERBOSE_SWITCH -eq '1' ]; then
			echo "Array folders element $folder: ${folders[$folder]}"
			echo "Working on folder: ${folders[$folder]}"
			rm -f -R -v --interactive=never "'${folders[$folder]}'"
		else
			rm -f -R --interactive=never "'${folders[$folder]}'"
		fi

	done
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
		echo "Remove $mode in $FOLDER_TARGET with name like $NAME_PART stopped with error $status"
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
		echo "Remove $mode in $FOLDER_TARGET with name like $NAME_PART finished successfully"
		echo "<<< Sub Module $file_name_full v$version finished successfully <<<"
		sh output-styler "end"
		sh output-styler "end"
	fi
	exit $status
fi
