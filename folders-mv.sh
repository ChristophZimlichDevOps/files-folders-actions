#!/bin/bash

## Creator: Christoph Zimlich
##
##
## Summary
## This script will move folder(s) and maybe recreate it like you want. Useful for backups for example.
##
## Parameter  1: Folder Target i.e.    "/tmp/"
## Parameter  2: Name Part Old i.e.    "current*" ONLY wildcards at the beginning and at the end with other real content will work. ONLY wildcards with no other real content will NOT work
## Parameter  3: Name Part New i.e.    "$(date +%y%m%d%H%M%S)"
## Parameter  4: Recreate Folder Switch 0=Off
##                                      1=On
## Parameter  5: Script Path...Where the scripts are stored i.e. "/root/bin/"
## Parameter  6: Output Switch      0=Console
##                                  1=Logfile
##                                  1=Default
## Parameter  7: Verbose Switch     0=Off
##                                  1=On
##                                  1=Default
##
## Call it like this:
## sh FoldersMv.sh "/home/backup/mysql/" "current*" "$(date +%y%m%d%H%M%S)" "1" "/root/bin/linux/shell/files-folders-actions/" "0" "1"


## Clear console to debug that stuff better
#clear

## Enhanced debugging with set -x
#set -x

## Set Stuff
version="0.0.1-alpha.1"
file_name_full="folders-mv.sh"
# shellcheck disable=SC2034
file_name="${file_name_full%.*}"

run_as_user_name=$(whoami)
run_as_user_uid=$(id -u "$run_as_user_name")
run_as_group_name=$(id -gn "$run_as_user_name")
run_as_group_gid=$(getent group "$run_as_group_name" | cut -d: -f3)
run_on_hostname=$(hostname -f)

## Set the job config FILE from parameter
config_file_in="$HOME/bin/linux/shell/files-folders-actions/$file_name.conf.in"
echo "Using config file $config_file_in for $file_name_full"

## Check this script is running as root !
#if [ "$(id -u)" != "0" ]; then
#	echo "Aborting, this script needs to be run as root! EXIT"
#	exit 1
#fi

## Clear used stuff
declare    FOLDER_TARGET
declare    NAME_PART_OLD 
declare    NAME_PART_NEW
declare -i FOLDER_DEEP
declare -i RECREATE_FOLDERS_SWITCH
declare -i OUTPUT_SWITCH
declare -i VERBOSE_SWITCH
## Clear stuff need for processing
declare -i sys_log_file_missing_switch
declare -i job_log_file_missing_switch
declare -a folders
declare -i status

## Check for arguments
FOLDER_TARGET=$1
NAME_PART_OLD=$2
NAME_PART_NEW=$3
FOLDER_DEEP=$4
RECREATE_FOLDERS_SWITCH=$5
OUTPUT_SWITCH=$6
VERBOSE_SWITCH=$7

## Import stuff from config FILE
#set -o allexport
# shellcheck source=$config_file_in disable=SC1091
#. "$config_file_in"
#set +o allexport

## Print file name
if [ $VERBOSE_SWITCH -eq '1' ]; then
	sh output-styler "start"
	echo ">>> Module $file_name_full v$version starting >>>"
	echo ">>> Move Config: Folder(s) Target=$FOLDER_TARGET, Folder(s) Name Part Old=$NAME_PART_OLD, \
	Folder(s) Name Part New=$NAME_PART_NEW >>>"
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

if [ $OUTPUT_SWITCH -eq '1' ]; then
	exec 3>&1 4>&2
	trap 'exec 2>&4 1>&3' 0 1 2 3 RETURN
	exec 1>>"$SYS_LOG" 2>&1
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
	if [ $OUTPUT_SWITCH -eq '1' ]; then
		sh output-styler "start"
		echo ">>> Module $file_name_full v$version starting >>>"
		echo ">>> Move Config: Folder(s) Target=$FOLDER_TARGET, Folder(s) Name Part Old=$NAME_PART_OLD, \
		Folder(s) Name Part New=$NAME_PART_NEW >>>"
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
	echo -n "Recreating Folder is "

	if [ $RECREATE_FOLDERS_SWITCH -eq '1' ]; then
		echo "ON"
	else
		echo "OFF"
	fi

	if [ "$sys_log_file_missing_switch" -eq '1' ]; then
		echo "Log file: $SYS_LOG is missing"
		echo "Creating it at $SYS_LOG"
	fi

	if [ "$job_log_file_missing_switch" -eq '1' ]; then
		echo "Log file: $JOB_LOG is missing"
		echo "Creating it at $JOB_LOG"
	fi

	if [ $OUTPUT_SWITCH -eq '1' ]; then
		echo "Output to log file $JOB_LOG"

	else
	    echo "Output to console...As $run_as_user_name:$run_as_group_name can see ;)"
	fi
fi

if [ "$FOLDER_TARGET" = "" ]; then
	echo "Folder Target parameter is empty. EXIT"
	exit 2
fi

if [ ! -d "$FOLDER_TARGET" ]; then
	echo "Folder Target parameter $FOLDER_TARGET is not a valid folder path. EXIT"
	exit 2
fi

if [ "$NAME_PART_OLD" = "" ]; then
	echo "Folder Name Part Old parameter is empty. EXIT"
	exit 2
fi

if [ "$NAME_PART_NEW" = "" ]; then
	echo "Folder Name Part New parameter is empty. EXIT"
	exit 2
fi

if [ "$FOLDER_DEEP" = "" ] || \
   [ "$FOLDER_DEEP" -gt '2' ] || \
   [ "$FOLDER_DEEP" -eq '0' ]; then
   		echo "Folder Deep Value $FOLDER_DEEP is too high, 0 or empty. Set to Default 1"
		FOLDER_DEEP=1
fi

## Lets roll
## Get all folders in $FOLDER_TARGET with max depth of $FOLDER_DEEP and name part $NAME_PART_OLD
readarray -t folders < <(find "$FOLDER_TARGET" -maxdepth "$FOLDER_DEEP" -type d -name "$NAME_PART_OLD")

## Clean wildcard(s) at the beginning and at the end of $NAME_PART_OLD to match exact filename part for command rename
if [ "$NAME_PART_OLD" != "${NAME_PART_OLD//[\[\]|.? +*]/}" ]; then
	name_part_old_clean=${NAME_PART_OLD//"?"/}
	name_part_old_clean=${name_part_old_clean//"*"/}
	if [ "$VERBOSE_SWITCH" -eq '1' ]; then
		echo "Folder Name Part Old: $NAME_PART_OLD has wildcard character(s)...  * or ?"
		echo "Cleaned Folder Name Part Old: $name_part_old_clean"
	fi
else
	name_part_old_clean=$NAME_PART_OLD
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		echo "Folder Name Part Old: $name_part_old_clean has NO wildcard character(s)...  * or ?"
	fi
fi

if [ "$name_part_old_clean" = "" ]; then
	echo "Name Part Old / Cleaned parameter is empty. EXIT"
	exit 1
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
    echo "Folder Target: $FOLDER_TARGET"
    echo "Folder Name Part Old: $NAME_PART_OLD"
	echo "Folder Name Part New: $NAME_PART_NEW"
	echo "This will effect the following ${#folders[@]} folder(s)..."
	for folder in "${!folders[@]}"
    do
		echo "${folders[$folder]}"
	done
fi

if [ ${#folders[@]} -eq '0' ]; then
	echo "No folder(s) to rename at $FOLDER_TARGET$NAME_PART_OLD. EXIT"
	exit 1
else
	for folder in "${!folders[@]}"
    do
        if [ "$VERBOSE_SWITCH" -eq '1' ]; then
			sh output-styler "part"
			echo "Working on folder in element $folder: ${folders[$folder]}"
		fi
		if [ ! -d "${folders[$folder]}" ]; then
			echo "Folder Target parameter ${folders[$folder]} is not a valid folder path. BREAK"
			break
		else
			name_new_full="${folders[$folder]/$name_part_old_clean/$NAME_PART_NEW}"
			#name_new_full="${!folder/$name_part_old_clean/$NAME_PART_NEW}"
			if [ "$VERBOSE_SWITCH" -eq '1' ]; then
				sh output-styler "part"
				echo "!!! New Folder Name: $name_new_full"
				sh output-styler "part"
				echo "Moving folder from ${folders[$folder]} to $name_new_full started"
				mv -v "${folders[$folder]}" "$name_new_full"
			else
				mv "${folders[$folder]}" "$name_new_full"
			fi
			## Check last task for errors
			status=$?
			if [ $status != 0 ]; then
				echo "Error moving folder from ${folders[$folder]} to $name_new_full, code="$status;
				echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
				break
				exit $status
			else
				if [ $VERBOSE_SWITCH -eq '1' ]; then
					echo "Moving folder from ${folders[$folder]} to $name_new_full finished successfully"
					sh output-styler "part"
				fi
				if [ "$RECREATE_FOLDERS_SWITCH" -eq '1' ]; then
					if [ -d "${folders[$folder]}" ]; then
						echo "Old Folder to recreate ${folders[$folder]} already exists"
					else
						if [ "$VERBOSE_SWITCH" -eq '1' ]; then
							echo "Starting recreate old folder at ${folders[$folder]}"
							mkdir -vp "${folders[$folder]}" #$NAME_PART_OLD
						else
							mkdir -p "${folders[$folder]}" #$NAME_PART_OLD
							## for testing
							#cp -R -f $FOLDER_TARGET"sub/" $FOLDER_TARGET$NAME_PART_OLD
						fi
						## Check last task for errors
						status=$?
						if [ $status != 0 ]; then
							echo "Error recreating old folder ${folders[$folder]}, code="$status
							sh output-styler "error"
							break
							exit $status

						else
							if [ "$VERBOSE_SWITCH" -eq '1' ]; then
								echo "Recreating old folder ${folders[$folder]} finished successfully"
								sh output-styler "part"
							fi
						fi
					fi
				fi
			fi
        fi
	done
fi

if [ "$VERBOSE_SWITCH" -eq '1' ]; then
	sh output-styler "middle"
	sh output-styler "end"
fi

## Check last task for errors
status=$?
if [ $status != 0 ]; then
	if [ "$VERBOSE_SWITCH" -eq '1' ]; then
        sh output-styler "error"
	fi
    echo "!!! Error Sub Module $file_name_full from $FOLDER_TARGET to $FOLDER_TARGET, code=$status !!!"
    if [ "$VERBOSE_SWITCH" -eq '1' ]; then
        echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
		sh output-styler "error"
		sh output-styler "end"
	    sh output-styler "end"
    fi
	exit $status
else
	if [ "$VERBOSE_SWITCH" -eq '1' ]; then
		echo "<<< Sub Module $file_name_full v$version finished successfully <<<"
		sh output-styler "end"
		sh output-styler "end"
	fi
	exit $status
fi
