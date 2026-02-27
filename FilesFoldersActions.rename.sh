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
## Parameter  5: Rename Folder Deep "1"=Deep of the the folder(s) where file(s) and folder(s) can be find to rename. MAX VALUE IS 2 for security reason
## Parameter  6: Recreate Folder Switch	0=Off
##                                     	1=On
## Parameter  7: Sys log i.e. 			"/var/log/bash/$file_name.log"
## Parameter  8: Job log i.e. 			"/tmp/bash/$file_name.log"
## Parameter  9: Sys log i.e.		    "/var/log/bash/$file_name.log"
## Parameter 10: Job log i.e.		    "/tmp/bash/$file_name.log"
## Parameter 11: Output Switch      	0=Console
##                                  	1=Logfile; Default
## Parameter 12: Verbose Switch     	0=Off
##                                  	1=On; Default
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

## Clear console to debug that stuff better
#clear

## Enhanced debugging with set -x
#set -x

## Set Stuff
version="0.0.1-alpha.1"
file_name_full="FilesFoldersActions.rename.sh"
file_name="${file_name_full%.*}"

run_as_user_name=$(whoami)
run_as_user_uid=$(id -u "$run_as_user_name")
run_as_group_name=$(id -gn "$run_as_user_name")
run_as_group_gid=$(getent group "$run_as_group_name" | cut -d: -f3)
run_on_hostname=$(hostname -f)

## Check this script is running as root !
#if [ "$run_as_user_uid" != "0" ]; then
#    echo "!!! ATTENTION !!!		    YOU MUST RUN THIS SCRIPT AS ROOT / SUPERUSER	        !!! ATTENTION !!!"
#fi

## Clear used stuff
declare	   NAME_PART_OLD
declare	   NAME_PART_NEW
declare	   FOLDER_TARGET
declare -i MODE_SWITCH
declare -i FOLDER_DEEP
declare -i RECREATE_FOLDER_SWITCH
declare	   SCRIPT_PATH
declare	   SYS_LOG
declare	   JOB_LOG
declare -i OUTPUT_SWITCH
declare -i VERBOSE_SWITCH
## Needed for processing
declare    config_file_in
declare    mode
declare    name_part_old_clean
declare -a files
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
RECREATE_FOLDER_SWITCH=$6
SYS_LOG=$7
JOB_LOG=$8
OUTPUT_SWITCH=$9
VERBOSE_SWITCH=${10}

## Set the job config FILE from parameter
config_file_in="$HOME/bin/linux/shell/FilesFoldersActions.loc/$file_name.conf.in"
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
if [ $VERBOSE_SWITCH -eq '1' ]; then
	sh OutputStyler "start"
    echo ">>> Sub Module $file_name_full v$version starting >>>"
	echo ">>> Rename Config: Name Part Old=$NAME_PART_OLD, Name Part New=$NAME_PART_NEW, Folder Source=$FOLDER_TARGET, Mode=$mode >>>"
fi

## Set parameters if not set correctly by config FILE
if [ "$FOLDER_DEEP" = "" ] || \
   [ "$FOLDER_DEEP" -gt '2' ] || \
   [ "$FOLDER_DEEP" -eq '0' ]; then
		echo "Folder Deep Value $FOLDER_DEEP is too high, 0 or empty. Set to Default 1"
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

if [ "$VERBOSE_SWITCH" -eq '1' ]; then
    sh OutputStyler "start"
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
	
	echo -n "Renaming file(s) is "
	if [ "$MODE_SWITCH" -gt '1' ]; then
		echo "OFF"
	else
		echo "ON"
	fi

	echo -n "Renaming folder(s) is "
	if [ "$MODE_SWITCH" -gt '0' ]; then 
		echo "ON"
	else
		echo "OFF"
	fi

	echo "Renaming Folder(s) Deep $FOLDER_DEEP"
	echo -n "Recreating Folder(s) is "
	if [ "$RECREATE_FOLDER_SWITCH" -eq '1' ]; then 
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

    
	echo "!!! ATTENTION !!!         	Parameter 1: Name Part Old i.e. current* 	    	                               !!! ATTENTION !!!"
	echo "!!! ATTENTION !!!         	ONLY wildcards at the beginning and at the end with other real content will work   !!! ATTENTION !!!"
	echo "!!! ATTENTION !!!         	ONLY wildcards with no other real content will NOT work                            !!! ATTENTION !!!"
fi

if [ "$NAME_PART_OLD" = "" ]; then
	echo "File Name Part Old parameter is empty. EXIT"
	exit 1
fi

if [ "$NAME_PART_NEW" = "" ]; then
	echo "File Name Part New parameter is empty. EXIT"
	exit 1
fi

if [ "$FOLDER_TARGET" = "" ]; then
	echo "Folder Source parameter is empty. EXIT"
	exit 1
fi

if [ ! -d "$FOLDER_TARGET" ]; then
	echo "Folder Source parameter $FOLDER_TARGET is not a valid folder path. EXIT"
	exit 1
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
	echo "$mode Name Part Old: $NAME_PART_OLD"
	echo "$mode Name Part New: $NAME_PART_NEW"
	echo "Folder Source: $FOLDER_TARGET"
    echo "Search for file(s) like: $FOLDER_TARGET$NAME_PART_OLD"
fi

## Lets roll
## Clean wildcard(s) at the beginning and at the end of $NAME_PART_OLD to match exact filename part for command rename
if [ "$NAME_PART_OLD"  !=  "${NAME_PART_OLD//[\[\]|.? +*]/}" ]; then
	name_part_old_clean=${NAME_PART_OLD//"?"/}
	name_part_old_clean=${name_part_old_clean//"*"/}
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		echo "$mode Name Part Old: $NAME_PART_OLD has wildcard character(s)...  * or ?"
		echo "Cleaned $mode Name Part Old: $name_part_old_clean"
	fi
else
	name_part_old_clean=$NAME_PART_OLD
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		echo "$mode Name Part Old: $name_part_old_clean has NO wildcard character(s)...  * or ?"
	fi
fi

if [ "$name_part_old_clean" = "" ]; then
	echo "Name Part Old / Cleaned parameter is empty. EXIT"
	exit 1
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
	echo "Renaming $mode in $FOLDER_TARGET with name like $NAME_PART_OLD to $NAME_PART_NEW started"
fi

## Start renaming all file(s) in array
if [ $MODE_SWITCH -lt '2' ]; then

	readarray -t files < <(find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART_OLD")
	
	if [ $VERBOSE_SWITCH -eq '1'  ]; then
		echo "This will effect the following ${#files[@]} x file(s)..."
		for file in "${!files[@]}"
		do
			echo "Array file(s) element $file: ${files[$file]}"
		done
	fi

	if [ ${#files[@]} -eq '0' ]; then
		echo "No file(s) to rename at Folder Target $FOLDER_TARGET with $NAME_PART_OLD to $NAME_PART_NEW"
		exit 1
	fi

	if [ $VERBOSE_SWITCH -eq '1'  ]; then
		echo "Starting renaming file(s) at Folder Target $FOLDER_TARGET with $NAME_PART_OLD to $NAME_PART_NEW..."
		find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART_OLD" \
			-exec rename -v "$name_part_old_clean" "$NAME_PART_NEW" {} ";"
	else
		find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART_OLD" \
			-exec rename "$name_part_old_clean" "$NAME_PART_NEW" {} ";"
	fi

	## Check last task for errors
	status=$?
	if [ $status != 0 ]; then
		echo "Error renaming file ${files[$file]} to ${files[$file]/$name_part_old_clean/$NAME_PART_NEW}, code="$status;
		echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
		exit $status
	else
		if [ $VERBOSE_SWITCH -eq '1' ]; then
			echo "Renaming file(s) at Folder Target $FOLDER_TARGET with $NAME_PART_OLD to $NAME_PART_NEW} finished successfully"
		fi
	fi
fi

## Start renaming all folder(s) in array
if [ $MODE_SWITCH -lt '2' ]; then

	readarray -t folders < <(find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART_OLD")
	
	if [ $VERBOSE_SWITCH -eq '1'  ]; then
		echo "This will effect the following ${#folders[@]} x folder(s)..."
		for folder in "${!folders[@]}"
		do
			echo "Array folder(s) element $folder: ${folders[$folder]}"
		done
	fi

	if [ ${#folders[@]} -eq '0' ]; then
		echo "No folder(s) to rename at Folder Target $FOLDER_TARGET with $NAME_PART_OLD to $NAME_PART_NEW"
		exit 1
	fi

	if [ $VERBOSE_SWITCH -eq '1'  ]; then
		echo "Starting renaming folder(s) at Folder Target $FOLDER_TARGET with $NAME_PART_OLD to $NAME_PART_NEW..."
		find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART_OLD" \
			-exec rename -v "$name_part_old_clean" "$NAME_PART_NEW" {} ";"
	else
		find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART_OLD" \
			-exec rename "$name_part_old_clean" "$NAME_PART_NEW" {} ";"
	fi

	## Check last task for errors
	status=$?
	if [ $status != 0 ]; then
		echo "Error renaming folder(s) at Folder Target $FOLDER_TARGET with $NAME_PART_OLD to $NAME_PART_NEW, code="$status;
		echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
		exit $status
	else
		if [ $VERBOSE_SWITCH -eq '1' ]; then
			echo "Renaming folder(s) at Folder Target $FOLDER_TARGET with $NAME_PART_OLD to $NAME_PART_NEW finished successfully"
		fi
	fi
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
	sh OutputStyler "middle"
	sh OutputStyler "end"
fi

status=$?
if [ $status != 0 ]; then
	sh OutputStyler "error"
	echo "!!! Error renaming $mode at $FOLDER_TARGET from $name_part_old_clean to $NAME_PART_NEW, code=$status !!!"
	echo "!!! Rename Config: $mode Name Part Old=$NAME_PART_OLD, $mode Name Part New=$NAME_PART_NEW, Folder Source=$FOLDER_TARGET, Mode=$mode !!!"
	echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
	sh OutputStyler "error"
    sh OutputStyler "end"
	exit $status
else
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		echo "<<< Renaming $mode at $FOLDER_TARGET from $name_part_old_clean to $NAME_PART_NEW finished <<<"
		echo "<<< Rename Config: $mode Name Part Old=$NAME_PART_OLD, $mode Name Part New=$NAME_PART_NEW, Folder Source=$FOLDER_TARGET, Mode=$mode <<<"
		echo "<<< Sub Module $file_name_full v$version finished successfully <<<"
		sh OutputStyler "end"
	fi
	exit $status
fi
