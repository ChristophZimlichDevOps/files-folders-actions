#!/bin/bash

## Creator: Christoph Zimlich
##
##
## Summary
## This script will rename files and folders like you want. Useful for backups for example.
##
## Parameter 1: File Name Part Old i.e. "current*" ONLY wildcards at the beginning and at the end with other real content will work. ONLY wildcards with no other real content will NOT work
## Parameter 2: File Name Part New i.e. "$(date +%y%m%d%H%M%S)"
## Parameter 3: Folder Target i.e. "/home/backup/mysql/"
## Parameter 4: Mode Rename Switch "--rename-files-folders"=File(s) and Folder(s) will be renamed
##				"--rename-folders"=ONLY Folder(s) will be renamed
##              else i.e. "--rename-files"=ONLY File(s) will not be renamed
## Parameter 5: Rename Folder Deep Search "1"=Deep of the the folder(s) where file(s) and folder(s) can be find to rename. MAX VALUE IS 2 for security reason
## Parameter 6: Recreate Folders Switch "--recreate-folders"=On...Folders will be recreated too
##              else=Off...Folders will not be recreated
## Parameter 7: Output Switch "--logfile"=On...Output to logfile
##              else=Off...Output to console
## Parameter 8: Verbose Switch "-v"=On, else=Off
##
## Call it like this:
## sh FilesFoldersRename.sh "current*" "$(date +%y%m%d%H%M%S)" "/home/backup/mysql/" "--rename-files" "1" "--recreate-folders-not" "--console" "-v"

## Clear console to debug that stuff better
#clear

## Enhanced debugging with set -x
#set -x

## Set Stuff
version="0.0.1-alpha.1"
file_name_full="files-folders-rename.sh"
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
declare	   SCRIPT_SUB_FILE_FOLDERS_MV
declare	   SYS_LOG
declare	   JOB_LOG
declare -i OUTPUT_SWITCH
declare -i VERBOSE_SWITCH
## Needed for processing
declare    config_file_in
declare -i sys_log_file_missing_switch
declare -i job_log_file_missing_switch
declare    mode
declare    name_part_old_clean
declare -a files
declare -i status

## Set the job config FILE from parameter
config_file_in="$HOME/bin/linux/shell/files-folders-actions/$file_name.conf.in"
echo "Using config file $config_file_in for $file_name_full"

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

if [ $OUTPUT_SWITCH -eq '1' ]; then
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
	sh output-styler "start"
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
if [ "$VERBOSE_SWITCH" -eq '1' ]; then
    if [ "$OUTPUT_SWITCH" -eq '1' ]; then
        sh output-styler "start"
        sh output-styler "start"
        echo ">>> Sub Module $file_name_full v$version starting >>>"
    fi

    sh output-styler "start"
    sh output-styler "start"
    sh output-styler "middle"
    echo "Filename: $file_name_full"
    echo "Version: v$version"
    echo "Run as user name: $run_as_user_name"
    echo "Run as user uid: $run_as_user_uid"
    echo "Run as group: $run_as_group_name"
    echo "Run as group gid: $run_as_group_gid"
    echo "Run on host: $run_on_hostname"

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

	if [ $OUTPUT_SWITCH -eq '1' ]; then
		echo "Output to sys log file $SYS_LOG"
		echo "Output to job log file $JOB_LOG"
	fi

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
	fi

    echo "Verbose is ON"
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

## Start renaming all files in array
if [ $MODE_SWITCH -lt '2' ]; then

	readarray -t files < <(find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type f -name "$NAME_PART_OLD" -ls | awk '{print $NF}')
	
	if [ $VERBOSE_SWITCH -eq '1'  ]; then
		echo "This will effect the following ${#files[@]} x file(s)..."
		for file in "${!files[@]}"
		do
			echo "Array files element $file: ${files[$file]}"
		done
	fi

	if [ ${#files[@]} -eq '0' ]; then
		echo "No file(s) to rename at $FOLDER_TARGET$NAME_PART_OLD."
	else
		for file in "${!files[@]}"
		do
			if [ $VERBOSE_SWITCH -eq '1' ]; then
				echo "Working on file: ${files[$file]}"
			fi

			if [ ! -f "${files[$file]}" ]; then
				echo "File Path ${files[$file]} is not a valid. Go to next one. NEXT"
				break
			fi

			if [ $VERBOSE_SWITCH -eq '1' ]; then
				rename -v "$name_part_old_clean" "$NAME_PART_NEW" "${files[$file]}"
			else
				rename "$name_part_old_clean" "$NAME_PART_NEW" "${files[$file]}"
        	fi

        	## Check last task for errors
        	status=$?
        	if [ $status != 0 ]; then
				echo "Error renaming file ${files[$file]} to ${files[$file]/$name_part_old_clean/$NAME_PART_NEW}, code="$status;
				echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
				break
				exit $status
        	else
				if [ $VERBOSE_SWITCH -eq '1' ]; then
					echo "Renaming file ${files[$file]} to ${files[$file]/$name_part_old_clean/$NAME_PART_NEW} finished successfully"
				fi
        	fi
		done
	fi
fi

## Start renaming all folders in array
if [ $MODE_SWITCH -gt '0' ]; then
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		sh output-styler "part"
	fi

	## Call sub module for renaming...better moving folders
    # shellcheck disable=SC1090
    . "$SCRIPT_PATH""$SCRIPT_SUB_FILE_FOLDERS_MV" \
		"$FOLDER_TARGET" \
		"$NAME_PART_OLD" \
		"$NAME_PART_NEW" \
		"$FOLDER_DEEP" \
		"$RECREATE_FOLDER_SWITCH" \
		"$OUTPUT_SWITCH" \
		"$VERBOSE_SWITCH"

	if [ $VERBOSE_SWITCH -eq '1' ]; then
		sh output-styler "part"
	fi
	
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
	sh output-styler "middle"
	sh output-styler "end"
fi

status=$?
if [ $status != 0 ]; then
	sh output-styler "error"
	echo "!!! Error renaming $mode at $FOLDER_TARGET from $name_part_old_clean to $NAME_PART_NEW, code=$status !!!"
	echo "!!! Rename Config: $mode Name Part Old=$NAME_PART_OLD, $mode Name Part New=$NAME_PART_NEW, Folder Source=$FOLDER_TARGET, Mode=$mode !!!"
	echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
	sh output-styler "error"
    sh output-styler "end"
	exit $status
else
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		echo "<<< Renaming $mode at $FOLDER_TARGET from $name_part_old_clean to $NAME_PART_NEW finished <<<"
		echo "<<< Rename Config: $mode Name Part Old=$NAME_PART_OLD, $mode Name Part New=$NAME_PART_NEW, Folder Source=$FOLDER_TARGET, Mode=$mode <<<"
		echo "<<< Sub Module $file_name_full v$version finished successfully <<<"
		sh output-styler "end"
	fi
	exit $status
fi
