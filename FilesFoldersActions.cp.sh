#!/bin/bash

## Creator: Christoph Zimlich
##
##
## Summary
## This script will copy files and folders like you want. Useful for backups for example.
##
## Parameter  1: PID full path i.e. "/var/run/$file_name.pid"
## Parameter  2: Folder Source i.e. "/home/backup/mysql/"
## Parameter  3: Folder Target i.e. "/tmp/bash/test/"
## Parameter  4: Name Part i.e.     "current*" ONLY wildcards at the beginning and at the end with other real content will work. ONLY wildcards with no other real content will NOT work
## Parameter  5: Copy Mode Switch   0=Copy only files
##                                  1=Copy files and folders
##                                  2=Copy only folders
## Parameter  6: Script path i.e.   "$HOME/bin/linux/shell/FilesFoldersActions/"
## Parameter  7: Sub Script for creating PID i.e. "FilesFoldersActions.cp.pid.create.sh"
## Parameter  8: Sub Script for removing PID i.e. "FilesFoldersActions.cp.pid.rm.sh"
## Parameter  9: Sys log i.e.		"/var/log/bash/$file_name.log"
## Parameter 10: Job log i.e.		"/tmp/bash/$file_name.log"
## Parameter 11: Config Switch      0=Parameters; Default
##                                  1=Config file
## Parameter 12: Output Switch      0=Console
##                                  1=Logfile; Default
## Parameter 13: Verbose Switch     0=Off
##                                  1=On; Default
##
## Call it like this:
## sh FilesFoldersActions.cp.sh \
##		"/var/run/$file_name.pid" \
##		"/home/backup/mysql/" \
##		"/tmp/bash/" \
##		"current*" \
##		"1" \
##		"1" \
##		"$HOME/bin/linux/shell/FilesFoldersActions/" \
##		"FilesFoldersActions.cp.pid.create.sh" \
##		"FilesFoldersActions.cp.pid.rm.sh" \
##		"/var/log/bash/$file_name.log" \
##      "/tmp/bash/$file_name.log" \
##		"0" \
##		"0" \
##		"1"

## Clear console to debug that stuff better
##clear

## Enhanced debugging with set -x
#set -x

## Set Stuff
version="0.0.1-alpha.1"
file_name_full="FilesFoldersActions.cp.sh"
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
declare -i CONFIG_SWITCH
declare -i OUTPUT_SWITCH
declare -i VERBOSE_SWITCH
## Need for processing
declare -i sys_log_folder_missing_switch=0
declare -i sys_log_file_missing_switch=0
declare -i job_log_folder_missing_switch=0
declare -i job_log_file_missing_switch=0
declare -a files
declare -a folders
declare -i status

## Set variables
PID_PATH_FULL=$1
FOLDER_SOURCE=$2
FOLDER_TARGET=$3
NAME_PART=$4
MODE_SWITCH=$5
FOLDER_DEEP=$6
SCRIPT_PATH=$7
SCRIPT_SUB_FILE_PID_CREATE=$8
SCRIPT_SUB_FILE_PID_RM=$9
SYS_LOG=${10}
JOB_LOG=${11}
CONFIG_SWITCH=${12}
OUTPUT_SWITCH=${13}
VERBOSE_SWITCH=${14}

if [ $CONFIG_SWITCH -eq '1' ]; then
	## Set the job config FILE from parameter
	config_file_in="$HOME/bin/linux/shell/local/FilesFoldersActions/$file_name.conf.in"
	echo "Using config file $config_file_in for $file_name_full"
	#config_file_in=$1

	## Import stuff from config file
	set -o allexport
	# shellcheck source=$config_file_in disable=SC1091
	. "$config_file_in"
	set +o allexport
fi

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

if [ $MODE_SWITCH -eq '0' ]; then
	mode="File(s)"
fi

if [ $MODE_SWITCH -eq '1' ]; then
	mode="File(s) and Folder(s)"
fi

if [ $MODE_SWITCH -eq '2' ]; then
	mode="Folder(s)"
fi

## Print file name
if [ "$OUTPUT_SWITCH" -eq '1' ] && \
   [ "$VERBOSE_SWITCH" -eq '0' ]; then
        sh OutputStyler "start"
        sh OutputStyler "start"
        echo ">>> Sub Module $file_name_full v$version starting >>>"
        echo ">>> PID Create Config: PID Path=$PID_PATH_FULL, PID=$PID, Folder Source=$FOLDER_SOURCE, Folder Target=$FOLDER_TARGET >>>"
fi

## Talk to you if you want
if [ $VERBOSE_SWITCH -eq '1' ]; then
	sh OutputStyler "start"
	sh OutputStyler "middle"
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

if [ "$MODE_SWITCH" -gt '2' ] || \
   [[ $MODE_SWITCH =~ [^[:digit:]] ]]; then
        echo "Recreate Folder Switch parameter $MODE_SWITCH is not a valid. EXIT"
        exit 2
fi

if [ "$FOLDER_DEEP" = "" ] || \
   [ "$FOLDER_DEEP" -gt '2' ] || \
   [ "$FOLDER_DEEP" -eq '0' ]; then
   		echo "Folder Deep Value $FOLDER_DEEP is too high, 0 or empty. Set to Default 1"
		FOLDER_DEEP=1
fi

if [ "$SCRIPT_PATH" = "" ]; then
        echo "Script Path parameter is empty. EXIT"
        exit 2
fi

if [ "$SCRIPT_SUB_FILE_PID_CREATE" = "" ]; then
        echo "Script Sub file PID Create $SCRIPT_SUB_FILE_PID_CREATE parameter is empty. EXIT"
        exit 2
fi

if [ "$SCRIPT_SUB_FILE_PID_RM" = "" ]; then
        echo "Script Sub file PID Remove  parameter $SCRIPT_SUB_FILE_PID_RM is empty. EXIT"
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

## Check folder sources and targets in PID file
string_tmp="$SCRIPT_PATH$SCRIPT_SUB_FILE_PID_CREATE"
echo "string_tmp $string_tmp"
# shellcheck disable=SC1090
sh "$SCRIPT_PATH""$SCRIPT_SUB_FILE_PID_CREATE" \
	"$PID_PATH_FULL" \
	"$$" \
	"$FOLDER_SOURCE" \
	"$FOLDER_TARGET" \
	"$SYS_LOG" \
	"$JOB_LOG" \
	"$CONFIG_SWITCH" \
	"$OUTPUT_SWITCH" \
	"$VERBOSE_SWITCH"

## Check last task for error(s)
status=$?
if [ $status != 0 ]; then
	echo "Error with PID $PID_PATH_FULL and Check Copying from Folder Source $FOLDER_SOURCE \
	to Folder Target $FOLDER_TARGET, code="$status

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
string_tmp="$SCRIPT_PATH$SCRIPT_SUB_FILE_PID_RM"
echo "string_tmp $string_tmp"
#echo ". $string_tmp \
#	$PID_PATH_FULL \
#	$$ \
#	$CONFIG_SWITCH \
#	$OUTPUT_SWITCH \
#	$VERBOSE_SWITCH" \
#	> "$string_tmp"
#trap '. -- $string_tmp " \
#	'"$PID_PATH_FULL"' \
#	'$$' \
#	'"$CONFIG_SWITCH"' \
#	'"$OUTPUT_SWITCH"' \
#	'"$VERBOSE_SWITCH"' ' EXIT

sh "$SCRIPT_PATH""$SCRIPT_SUB_FILE_PID_RM" \
	"$PID_PATH_FULL" \
	"$$" \
	"$SYS_LOG" \
	"$JOB_LOG" \
	"$CONFIG_SWITCH" \
	"$OUTPUT_SWITCH" \
	"$VERBOSE_SWITCH"

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

## Lets roll
readarray -t files < <(find "$FOLDER_SOURCE" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART")
readarray -t folders < <(find "$FOLDER_SOURCE" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART")

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

if [ $MODE_SWITCH -lt '2' ]; then
	if [ ${#files[@]} -eq '0' ]; then
		echo "No $mode to copy. EXIT"
		exit 1
	fi

	if [ $VERBOSE_SWITCH -eq '1' ]; then
		echo "This will effect the following ${#files[@]} x file(s)..."
		for file in "${!files[@]}"
		do
			echo "Array folder(s) element $file: ${files[$file]}"
		done
		echo "Copying file(s) from $FOLDER_SOURCE to $FOLDER_TARGET with name like $NAME_PART started"
		find "$FOLDER_SOURCE" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART_OLD" \
			-exec cp -fv {} "$FOLDER_TARGET" ";"
	else
        find "$FOLDER_SOURCE" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART_OLD" \
			-exec cp -f {} "$FOLDER_TARGET" ";"
	fi

	## Check last task for error(s)
	status=$?
	if [ $status != 0 ]; then
		# shellcheck disable=SC2154
		echo "Error copying file(s) from $FOLDER_SOURCE to $FOLDER_TARGET with name like $NAME_PART, code=$status";
		if [ "$VERBOSE_SWITCH" -eq '1' ]; then
				echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
		fi
		exit $status
	else
		if [ "$VERBOSE_SWITCH" -eq '1' ]; then
				echo "Copying file(s) from $FOLDER_SOURCE to $FOLDER_TARGET with name like $NAME_PART finished successfully"
		fi
	fi

fi

if [ $MODE_SWITCH -gt '0' ]; then
	if [ ${#folders[@]} -eq '0' ]; then
		echo "No $mode to copy. EXIT"
		exit 1
	fi

	if [ $VERBOSE_SWITCH -eq '1' ]; then
		echo "This will effect the following ${#folders[@]} x folder(s)..."
		for folder in "${!folders[@]}"
		do
			echo "Array folder(s) element $folder: ${folders[$folder]}"
		done
		echo "Copying folder(s) from $FOLDER_SOURCE to $FOLDER_TARGET with name like $NAME_PART started"
		find "$FOLDER_SOURCE" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART_OLD" \
			-exec cp -rfv {} "$FOLDER_TARGET" ";"
	else
        find "$FOLDER_SOURCE" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART_OLD" \
			-exec cp -rf {} "$FOLDER_TARGET" ";"
	fi
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
	sh OutputStyler "middle"
	sh OutputStyler "end"
fi

## Check last task for errors
status=$?
if [ $status -gt 1 ]; then
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		sh OutputStyler "error"
	fi
        echo "!!! Error copying $mode from $FOLDER_SOURCE to $FOLDER_TARGET, code=$status !!!"
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		echo "!!! Copy Config: Folder Source=$FOLDER_SOURCE, Folder Target=$FOLDER_TARGET, Copy $mode Name Part=$NAME_PART, Mode=$mode !!!"
		echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
        sh OutputStyler "error"
		sh OutputStyler "end"
	fi
	exit $status
else
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		echo "<<< Copy $mode from $FOLDER_SOURCE to $FOLDER_TARGET with name like $NAME_PART finished <<<"
		echo "<<< Copy Config: Folder Source=$FOLDER_SOURCE, Folder Target=$FOLDER_TARGET, Copy $mode Name Part=$NAME_PART, Mode=$mode <<<"
		echo "<<< Sub Module $file_name_full v$version finished successfully <<<"
		sh OutputStyler "end"
	fi
	exit $status
fi
