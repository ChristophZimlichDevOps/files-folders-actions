#!/bin/bash

## Creator: Christoph Zimlich
##
##
## Summary
## This script will copy files like you want. Useful for backups for example.
##
## Parameter  1: PID full path i.e. "/var/run/$file_name.pid"
## Parameter  2: Folder Source i.e. "/home/backup/mysql/"
## Parameter  3: Folder Target i.e. "/tmp/bash/test/"
## Parameter  4: Name Part i.e.     "current*" ONLY wildcards at the beginning and at the end with other real content will work. ONLY wildcards with no other real content will NOT work
## Parameter  5: Copy Mode Switch   0=Copy only files
##                                  1=Copy files and folders
##                                  2=Copy only folders
## Parameter  6: Script path i.e.   "/root/bin/linux/shell/files-folders-actions/"
## Parameter  7: Sub Script for creating PID i.e. "folders-folders-pid-create.sh"
## Parameter  8: Sub Script for removing PID i.e. "folders-folders-pid-rm.sh"
## Parameter  9: Sys log i.e.		"/var/log/bash/$file_name.log"
## Parameter 10: Job log i.e.		"/tmp/bash/$file_name.log"
## Parameter 11: Output Switch      0=Console
##                                  1=Logfile; Default
## Parameter 12: Verbose Switch     0=Off
##                                  1=On; Default
##
## Call it like this:
## sh files-folders-cp.sh "/var/run/$file_name.pid" "/home/backup/mysql/" "/tmp/" "current*" "1" "$HOME/bin/linux/shell/files-folders-actions/" "files-folders-pid-create.sh" "files-folders-pid-rm.sh" "/var/log/$file_name.log" "/tmp/$file_name.log" "0" "1"

## Clear console to debug that stuff better
##clear

## Enhanced debugging with set -x
#set -x

## Set Stuff
version="0.0.1-alpha.1"
file_name_full="files-folders-cp.sh"
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
declare	   FOLDER_SOURCE
declare	   FOLDER_TARGET
declare	   NAME_PART
declare -i MODE_SWITCH
declare -i FOLDER_DEEP
declare    PID_PATH_FULL
declare -i PID
declare	   SCRIPT_PATH
declare	   SCRIPT_SUB_FILE_PID_CREATE
declare	   SCRIPT_SUB_FILE_PID_RM
declare	   SYS_LOG
declare	   JOB_LOG
declare -i OUTPUT_SWITCH
declare -i VERBOSE_SWITCH
## Need for processing
declare -i sys_log_file_missing_switch
declare -i job_log_file_missing_switch
declare -a files
declare -a folders
declare -i status

## Set the job config FILE from parameter
config_file_in="$HOME/bin/linux/shell/files-folders-actions/$file_name.conf.in"
echo "Using config file $config_file_in for $file_name_full"
#config_file_in=$1

## Import stuff from config FILE
set -o allexport
# shellcheck source=$config_file_in disable=SC1091
. "$config_file_in"
set +o allexport

## Set variables
#PID_PATH_FULL="$1"
#FOLDER_SOURCE="$2"
#FOLDER_TARGET="$3"
#NAME_PART="$4"
#MODE_SWITCH=$5
#FOLDER_DEEP=$6
#SCRIPT_PATH="$7"
#SCRIPT_SUB_FILE_PID_CREATE="$8"
#SCRIPT_SUB_FILE_PID_RM="$9"
#SYS_LOG="${10}"
#JOB_LOG="${11}"
#OUTPUT_SWITCH=${12}
#VERBOSE_SWITCH=${13}

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
if [ $VERBOSE_SWITCH -eq '1' ]; then
	sh output-styler "start"
	sh output-styler "start"
    echo ">>> Sub Module $file_name_full v$version starting >>>"
fi

if [ $MODE_SWITCH -eq '0' ]; then
	mode="File(s)"
fi
if [ $MODE_SWITCH -eq '1' ]; then
	mode="File(s) and Folder(s)"
fi
if [ $MODE_SWITCH -eq '2' ]; then
	mode="Folder(s)"
fi

PID=$$
echo "PID: $PID"

## Print PID
if [ $VERBOSE_SWITCH -eq '1' ]; then
    echo "PID is $PID"
fi

## Check folder sources and targets in PID file
. "$SCRIPT_PATH""$SCRIPT_SUB_FILE_PID_CREATE" \
	"$PID_PATH_FULL" \
	"$$" \
	"$FOLDER_SOURCE" \
	"$FOLDER_TARGET" \
	"$OUTPUT_SWITCH" \
	"$VERBOSE_SWITCH"

## Check last task for error(s)
status=$?
if [ $status != 0 ]; then
	echo "Error with PID $PID_PATH_FULL and Check Copying from Folder Source $FOLDER_SOURCE \
	to Folder Target $FOLDER_TARGET, code="$status;
	if [ "$VERBOSE_SWITCH" -eq '1' ]; then
		echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
	fi
	exit $status
else
	if [ "$VERBOSE_SWITCH" -eq '1' ]; then
		echo "Checking PID $PID_PATH_FULL and Copying from Folder Source $FOLDER_SOURCE \
		to Folder Target $FOLDER_TARGET finished"
	fi
fi

## Remove PID from PID file when job is finished
echo "When job is done clean from PID $PID_PATH_FULL PID Process ID $$ entry"
echo ". $SCRIPT_PATH$SCRIPT_SUB_FILE_PID_RM \
	$PID_PATH_FULL \
	$$ \
	$OUTPUT_SWITCH $VERBOSE_SWITCH" \
	> "$SCRIPT_PATH""$SCRIPT_SUB_FILE_PID_RM"
trap '. -- $SCRIPT_PATH"$SCRIPT_SUB_FILE_PID_RM " \
	'"$PID_PATH_FULL"' \
	'$$' '"$OUTPUT_SWITCH"' \
	'"$VERBOSE_SWITCH"' ' EXIT
## Check last task for error(s)
status=$?
if [ $status != 0 ]; then
        echo "Error with PID $PID_PATH_FULL and finding PID Process ID $PID_PROCESS_ID, code=$status";
    	if [ "$VERBOSE_SWITCH" -eq '1' ]; then
			echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
		fi
		exit $status
else
    	if [ "$VERBOSE_SWITCH" -eq '1' ]; then
			echo "Removing entry in PID $PID_PATH_FULL with PID Process ID $PID_PROCESS_ID finished"
		fi
fi

if [ "$FOLDER_DEEP" = "" ] || \
   [ "$FOLDER_DEEP" -gt '2' ] || \
   [ "$FOLDER_DEEP" -eq '0' ]; then
   		echo "Folder Deep Value $FOLDER_DEEP is too high, 0 or empty. Set to Default 1"
		FOLDER_DEEP=1
fi

## Print file name
if [ $VERBOSE_SWITCH -eq '1' ]; then
        sh output-styler "start"
        echo ">>> Sub Module $file_name_full v$version starting >>>"
		echo ">>> Copy Config: Folder Source=$FOLDER_SOURCE, Folder Target=$FOLDER_TARGET, \
		Copy $mode Name Part=$NAME_PART, Mode=$mode >>>"
fi

## Talk to you if you want
if [ $VERBOSE_SWITCH -eq '1' ]; then
	if [ $OUTPUT_SWITCH -eq '1' ]; then
		sh output-styler "start"
		echo ">>> Sub Module $file_name_full v$version starting >>>"
		echo ">>> Copy Config: Folder Source=$FOLDER_SOURCE, Folder Target=$FOLDER_TARGET, \
		Copy $mode Name Part=$NAME_PART, Mode=$mode >>>"
	fi
	sh output-styler "start"
	sh output-styler "middle"
	echo "Filename: $file_name_full"
	echo "Version: v$version"
	echo "Run as user name: $run_as_user_name"
	echo "Run as user uid: $run_as_user_uid"
	echo "Run as group: $run_as_group_name"
	echo "Run as group gid: $run_as_group_gid"
	echo "Run on host: $run_on_hostname"
	echo "Verbose is ON"
	echo -n "Copying File(s) is "
	if [ $MODE_SWITCH -eq '2' ]; then
		echo "OFF"
	else
		echo "ON"
	fi
	echo -n "Copying Folder(s) is "
	if [ $MODE_SWITCH -gt '0' ]; then
		echo "ON"
	else
		echo "OFF"
	fi
	if [ $job_log_file_missing_switch -eq '1' ]; then
			echo "Log file: $JOB_LOG is missing"
			echo "Creating it at $JOB_LOG"
	fi
	if [ $sys_log_file_missing_switch -eq '1' ]; then
			echo "Log file: $SYS_LOG is missing"
			echo "Creating it at $SYS_LOG"
	fi
	if [ $OUTPUT_SWITCH -eq '1' ]; then
		echo "Output to job log file $JOB_LOG"
		echo "Output to sys log file $SYS_LOG"
	fi
else
        echo "Output to console...As you can see xD"
fi

if [ "$FOLDER_SOURCE" = "" ]; then
	echo "Folder Source parameter is empty. EXIT"
	exit 1
fi
if [ ! -d "$FOLDER_SOURCE" ]; then
	echo "Folder Source parameter $FOLDER_SOURCE is not a valid folder path. EXIT"
	exit 1
fi
if [ "$FOLDER_TARGET" = "" ]; then
	echo "Folder Target parameter is empty. EXIT"
	exit 1
fi
if [ ! -d "$FOLDER_TARGET" ]; then
	echo "Folder Target parameter $FOLDER_TARGET is not a valid folder path. Creating it at $FOLDER_TARGET"
	if [ "$FOLDER_SOURCE" = "$FOLDER_TARGET" ]; then
		echo "Folder Source parameter $FOLDER_SOURCE is the same like Folder Target $FOLDER_TARGET. EXIT"
		exit 1
	fi
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		mkdir -pv "$FOLDER_TARGET"
	else
		mkdir -p "$FOLDER_TARGET"
	fi
fi
if [ "$NAME_PART" = "" ]; then
	echo "Copy $mode Name Part parameter is empty. EXIT"
	exit 1
fi

## Lets roll
readarray -t files < <(find "$FOLDER_SOURCE" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART" -ls | awk '{print $NF}')
readarray -t folders < <(find "$FOLDER_SOURCE" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART" -ls | awk '{print $NF}')

if [ $VERBOSE_SWITCH -eq '1' ]; then
	echo "Folder Path Source: $FOLDER_SOURCE"
	echo "Folder Path Target: $FOLDER_TARGET"
	echo "Copy $mode Name Part: $NAME_PART"
        if [ $MODE_SWITCH -lt '2' ] && [ "${#files[@]}" -gt '0' ]; then
			echo "This will effect the following ${#files[@]} file(s)..."
			for file in "${!files[@]}"
			do
				echo "Array files element $file: ${files[$file]}"
			done
		fi
        if [ $MODE_SWITCH -gt '0' ] && [ ${#folders[@]} -gt '0' ]; then
			echo "This will effect the following ${#folders[@]} folder(s)..."
			for folder in "${!folders[@]}"
			do
				echo "Array folders element $folder: ${folders[$folder]}"
			done
		fi
	echo "Copying $mode from $FOLDER_SOURCE to $FOLDER_TARGET with name like $NAME_PART started"
fi

if [ $MODE_SWITCH -eq '1' ]; then
	if [ ${#files[@]} -eq '0' ] && [ ${#folders[@]} -eq '0' ]; then
		echo "No $mode to copy. EXIT"
		exit 1
	fi
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		cp -r -f -v "$FOLDER_SOURCE"*"$NAME_PART"* "$FOLDER_TARGET"
	else
        cp -r -f "$FOLDER_SOURCE"*"$NAME_PART"* "$FOLDER_TARGET"
	fi
elif [ $MODE_SWITCH -eq '2' ]; then
	if [ ${#folders[@]} -eq '0' ]; then
		echo "No $mode to copy. EXIT"
		exit 1
	fi
	for folder in "${!folders[@]}"
	do
		if [ $VERBOSE_SWITCH -eq '1' ]; then
			echo "Working on folder in folders: $folder"
		fi

        if [ ! -d "${folders[$folder]}" ]; then
			echo "Folder Source parameter ${folders[$folder]} is not a valid folder path. EXIT"
			break
		fi

		if [ $VERBOSE_SWITCH -eq '1' ]; then
			echo "Copy on folder(s) with verbose command here..."
			cp -r -f -v "${folders[$folder]}" "$FOLDER_TARGET"
		else
            echo "Copy only folder(s) command here..."
			cp -r -f "${folders[$folder]}" "$FOLDER_TARGET"
		fi
	done
else
	if [ ${#files[@]} -eq '0' ]; then
		echo "No $mode to copy. EXIT"
		exit 1
	fi
	
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		#echo "ErrorCode Before: $?"
		cp -f -v "$FOLDER_SOURCE"*"$NAME_PART"* "$FOLDER_TARGET"
	else
    	cp -f "$FOLDER_SOURCE"*"$NAME_PART"* "$FOLDER_TARGET"
	fi
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
	sh output-styler "middle"
	sh output-styler "end"
fi

## Check last task for errors
status=$?
if [ $status -gt 1 ]; then
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		sh output-styler "error"
	fi
        echo "!!! Error copying $mode from $FOLDER_SOURCE to $FOLDER_TARGET, code=$status !!!"
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		echo "!!! Copy Config: Folder Source=$FOLDER_SOURCE, Folder Target=$FOLDER_TARGET, Copy $mode Name Part=$NAME_PART, Mode=$mode !!!"
		echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
        sh output-styler "error"
		sh output-styler "end"
	fi
	exit $status
else
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		echo "<<< Copy $mode from $FOLDER_SOURCE to $FOLDER_TARGET with name like $NAME_PART finished <<<"
		echo "<<< Copy Config: Folder Source=$FOLDER_SOURCE, Folder Target=$FOLDER_TARGET, Copy $mode Name Part=$NAME_PART, Mode=$mode <<<"
		echo "<<< Sub Module $file_name_full v$version finished successfully <<<"
		sh output-styler "end"
	fi
	exit $status
fi
