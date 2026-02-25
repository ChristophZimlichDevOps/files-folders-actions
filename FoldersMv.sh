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
## sh FoldersMv.sh "/home/backup/mysql/" "current*" "$(date +%y%m%d%H%M%S)" "1" "/root/bin/linux/shell/FilesFoldersActions/" "0" "1"


## Clear console to debug that stuff better
#clear

## Enhanced debugging with set -x
#set -x

## Set Stuff
version="0.0.1"
file_name_full="FoldersMv.sh"
file_name="${file_name_full%.*}"

run_as_user_name=$(whoami)
run_as_user_uid=$(id -u $run_as_user_name)
run_as_group_name=$(id -gn $run_as_user_name)
run_as_group_gid=$(getent group "$run_as_group_name" | cut -d: -f3)
run_on_hostname=$(hostname -f)

## Set the job config FILE from parameter
job_config_file="/root/bin/linux/shell/FilesFoldersActions/FoldersMv.conf.in"

## Check this script is running as root !
if [ "$(id -u)" != "0" ]; then
	echo "Aborting, this script needs to be run as root! EXIT"
	exit 1
fi

## Only one instance of this script should ever be running and as its use is normally called via cron, if it's then run manually
## for test purposes it may intermittently update the ports.tcp & ports.udp files unnecessarily. So here we check no other instance
## is running. If another instance is running we pause for 3 seconds and then delete the PID anyway. Normally this script will run
## in under 150ms and via cron runs every 60 seconds, so if the PID file still exists after 3 seconds then it's a orphan PID file.
#if [ -f "$FoldersMvPID" ]; then
#        sleep 3 #if PID file exists wait 3 seconds and test again, if it still exists delete it and carry on
#        echo "There appears to be another Process $file_name_full PID $FoldersMvPID is already running, waiting for 3 seconds ..."
#        rm -f -- "$FoldersMvPID"
#fi
#trap 'rm -f -- $FoldersMvPID' EXIT #EXIT status=0/SUCCESS
#echo $$ > "$FoldersMvPID"

## Clear used stuff
declare    FOLDER_TARGET
declare    NAME_PART_OLD 
declare    NAME_PART_NEW
declare -i FOLDER_DEEP
declare -i RECREATE_FOLDERS_SWITCH
declare -i OUTPUT_SWITCH
declare -i VERBOSE_SWITCH
## Clear stuff need for processing
declare -i job_log_file_missing_switch
declare -i sys_log_file_missing_switch
declare -a folders
declare -a folders_tmp
declare -i status

## Check for arguments
FOLDER_TARGET=$1
NAME_PART_OLD=$2
NAME_PART_NEW=$3
FOLDER_DEEP=$4

## Import stuff from config FILE
set -o allexport
. $job_config_file
set +o allexport

## Print file name
if [ $VERBOSE_SWITCH -eq '1' ]; then
	sh OutputStyler "start"
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
		sh OutputStyler "start"
		echo ">>> Module $file_name_full v$version starting >>>"
		echo ">>> Move Config: Folder(s) Target=$FOLDER_TARGET, Folder(s) Name Part Old=$NAME_PART_OLD, \
		Folder(s) Name Part New=$NAME_PART_NEW >>>"
	fi
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
#if [ "$NAME_PART_OLD" != "${NAME_PART_OLD//[\[\]|.? +*]/}" ]; then
#	echo "Folder Name Part Old parameter $NAME_PART_OLD has wildcards * or ?... NOT ALLOWED. EXIT"
#	exit 2
#fi
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
#find . -type d -name .git -execdir sh -c "pwd && git pull" \;
#find . -maxdepth $FOLDER_DEEP -type d -name "$NAME_PART_OLD" -execdir sh -c "mv -v $NAME_PART_OLD $NAME_PART_NEW" \;
folders_string_full="find $FOLDER_TARGET -maxdepth $FOLDER_DEEP -type d -name "$NAME_PART_OLD" -ls"
folders_tmp=$(${folders_string_full})
folders=$(echo "$folders_tmp" | awk '{print $NF}')

## Clean wildcard(s) at the beginning and at the end of $NAME_PART_OLD to match exact filename part for command rename
if [ "$NAME_PART_OLD" != "${NAME_PART_OLD//[\[\]|.? +*]/}" ]; then
	wildcard_switch=1
else
	wildcard_switch=0
fi
if [ "$wildcard_switch" -eq '1' ]; then
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
	echo "Folders Array Full String: $folders_string_full"
	echo "This will effect the following ${#folders[@]} folder(s)..."
	for folder in "${!folders[@]}"
    do
		#echo "$folder"
		echo "${folders[$folder]}"
	done
fi

if [ ${#folders[@]} -eq '0' ]; then
	echo "No folder(s) to rename at $FOLDER_TARGET$NAME_PART_OLD."
else
	for folder in "${folders[@]}"
    do
        if [ "$VERBOSE_SWITCH" -eq '1' ]; then
			echo "Working on folder in folders: $folder"
		fi
		#if [ ! -d $folder ]; then
		if [ ! -d "$folder" ]; then

			#echo "Folder Target parameter $folder is not a valid folder path. BREAK"
			echo "Folder Target parameter $folder is not a valid folder path. BREAK"
			#break
		else
			name_old_full=$folder
		    #name_new_full="${name_old_full/$name_part_old_clean/$NAME_PART_NEW}" 
			name_new_full="${folder/$name_part_old_clean/$NAME_PART_NEW}"
			#name_new_full="${!folder/$name_part_old_clean/$NAME_PART_NEW}"
	
			if [ "$VERBOSE_SWITCH" -eq '1' ]; then
				sh OutputStyler "part"
				echo "!!! Old Folder Name: $folder"
				echo "!!! New Folder Name: $name_new_full"
				sh OutputStyler "part"
				echo "Moving folder from $folder to $name_new_full started"

## !!!!!!!!!!!!!!!!!!!!!!!!  HERE IS THE BUG !!!!!!!!!!!!!!!!!!!!!!!!
				#mv -v $folder $name_new_full
				mv -v "$name_old_full" "$name_new_full"
			else
				#mv $folder $name_new_full
				mv "$folder" "$name_new_full"
			fi
			## Check last task for errors
			status=$?
			if [ $status != 0 ]; then
				echo "Error moving folder from $folder to $name_new_full, code="$status;
				echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
				#break
				#exit $status
			else
				if [ $VERBOSE_SWITCH -eq '1' ]; then
					sh OutputStyler "part"
					echo "Moving folder from $folder to $name_new_full finished"
				fi
				if [ "$RECREATE_FOLDERS_SWITCH" -eq '1' ]; then

					if [ ! -d "${folders[$folder]}" ]; then
						if [ "$VERBOSE_SWITCH" -eq '1' ]; then
							echo "Starting recreate old folder at $folder"
							mkdir -vp "${folders[$folder]}" #$NAME_PART_OLD
							#mkdir -vp "$folder" #$NAME_PART_OLD
							## for testing
							#cp -R -f -v $FOLDER_TARGET"sub/" $FOLDER_TARGET$NAME_PART_OLD
						else
							mkdir -p "${folders[$folder]}" #$NAME_PART_OLD
							## for testing
							#cp -R -f $FOLDER_TARGET"sub/" $FOLDER_TARGET$NAME_PART_OLD
						fi
						## Check last task for errors
						status=$?
						if [ $status != 0 ]; then
							echo "Error recreating old folder ${folders[$folder]}, code="$status
							break
							exit $status
						else
							if [ "$VERBOSE_SWITCH" -eq '1' ]; then
								echo "Finished recreating old folder ${folders[$folder]}"
							fi
						fi
					else
						echo "Old Folder to recreate ${folders[$folder]} already exists"
					fi
				fi
			fi
        fi
	done
fi

if [ "$VERBOSE_SWITCH" -eq '1' ]; then
	echo "Finished recreate old folder at $folder"
	sh OutputStyler "middle"
	sh OutputStyler "end"
fi

## Check last task for errors
status=$?
if [ $status != 0 ]; then
	if [ "$VERBOSE_SWITCH" -eq '1' ]; then
        sh OutputStyler "error"
	fi
    echo "!!! Error Sub Module $file_name_full from $FOLDER_TARGET to $FOLDER_TARGET, code=$status !!!"
    if [ "$VERBOSE_SWITCH" -eq '1' ]; then
        echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
		sh OutputStyler "error"
		sh OutputStyler "end"
	    sh OutputStyler "end"
    fi
	exit $status
else
	if [ "$VERBOSE_SWITCH" -eq '1' ]; then
		echo "<<< Sub Module $file_name_full v$version finished successfully <<<"
		sh OutputStyler "end"
		sh OutputStyler "end"
	fi
	exit $status
fi
