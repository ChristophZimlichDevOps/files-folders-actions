#!/bin/bash

## Creator: Christoph Zimlich
##
##
## Summary
## This script will remove the entry of the PID file or completely delete it....if it's only 1 entry....and that's the current on. Useful for backups for example.
##
## Parameter  1: PID Full Path i.e. "/var/run/test.pid"
## Parameter  2: PID Process Number i.e. "54895"
## Parameter  3: Output Switch "--JOB_LOGfile"=On...Output to JOB_LOGfile
##               else=Off...Output to console
## Parameter  4: Verbose Switch "-v"=On, else=Off
##
## Call it like this:
## sh FilesFoldersRenameCpRm.sh "/var/run/FilesFoldersRenameCpRm.pid" "12345" "--console" "-v"

## Clear console to debug that stuff better
clear

## Enhanced debugging with set -x
#set -x

## Set Stuff
version="0.0.1-alpha.1"
file_name_full="files-folders-cp-pid-rm.sh"
file_name="${file_name_full##*/}"

run_as_user_name=$(whoami)
run_as_user_uid=$(id -u "$run_as_user_name")
run_as_group_name=$(id -gn "$run_as_user_name")
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

## Check this script is running as root !
if [ "$(id -u)" != "0" ]; then
        echo "Aborting, this script needs to be run as root! EXIT"
        exit 1
fi

## Only one instance of this script should ever be running and as its use is normally called via cron, if it's then run manually
## for test purposes it may intermittently update the ports.tcp & ports.udp files unnecessarily. So here we check no other instance
## is running. If another instance is running we pause for 5 seconds and then delete the PID anyway. Normally this script will run
## in under 150ms and via cron runs every 60 seconds, so if the PID file still exists after 5 seconds then it's a orphan PID file.
if [ -f "$FILES_FOLDERS_CP_PID_RM" ]; then
        sleep 5 #if PID file exists wait 3 seconds and test again, if it still exists delete it and carry on
        echo "There appears to be another Process $file_name PID $FILES_FOLDERS_CP_PID_RM is already running, waiting for 5 seconds ..."
        rm -f -- "$FILES_FOLDERS_CP_PID_RM"
fi
trap 'rm -f -- $FILES_FOLDERS_CP_PID_RM' EXIT #EXIT status=0/SUCCESS
echo $$ > "$FILES_FOLDERS_CP_PID_RM"

declare    PID_PATH_FULL
declare -i PID_PROCESS_ID
declare -i OUTPUT_SWITCH
declare -i VERBOSE_SWITCH

## Clear used stuff
declare -a pids
declare -a pids_tmp
declare -i config_file_in
declare -i status

## Check for arguments
PID_PATH_FULL=$1
PID_PROCESS_ID=$2
OUTPUT_SWITCH=$3
VERBOSE_SWITCH=$4

set -o allexport
# shellcheck source=$config_file_in disable=SC1091
. $config_file_in
set +o allexport

if [ -f "$PID_PATH_FULL" ]; then
        if [ $VERBOSE_SWITCH -eq '1' ]; then
                echo "PID file $PID_PATH_FULL found"
        fi
else
        echo "PID file $PID_PATH_FULL not found. EXIT"
        exit 2
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

if [ $OUTPUT_SWITCH -eq '1' ]; then
        exec 3>&1 4>&2
        trap 'exec 2>&4 1>&3' 0 1 2 3 RETURN
        exec 1>>"$JOB_LOG" 2>&1
fi

## Print file name
if [ $VERBOSE_SWITCH -eq '1' ]; then
        sh output-styler "start"
        echo ">>> Sub Module $file_name_full v$version starting >>>"
	echo ">>> PID Config: PID=$PID_PATH_FULL PID Process ID=$PID_PROCESS_ID >>>"
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
	echo "PID File: $PID_PATH_FULL"
	echo "PID Process ID: $PID_PROCESS_ID"

        if [ $OUTPUT_SWITCH -eq '1' ]; then
                echo "Output to SYS_LOGfile $SYS_LOG"
        else
                echo "Output to console...As you can see xD"
        fi

        if [ $job_log_file_missing_switch -eq '1' ]; then
                echo "JOB_LOGfile: $JOB_LOG is missing"
                echo "Creating it at $JOB_LOG"
        fi

        if [ $sys_log_file_missing_switch -eq '1' ]; then
                echo "SYS_LOGfile: $SYS_LOG is missing"
                echo "Creating it at $SYS_LOG"
        fi
fi

## Lets roll
if [ -f "$PID_PATH_FULL" ]; then
        ## Get content of PID file
        readarray -t pids_tmp < <(cat "$PID_PATH_FULL")
        pids=$(echo "$pids_tmp" | grep "$PID_PROCESS_ID")
        if [ $VERBOSE_SWITCH -eq '1' ]; then
                echo "$pids"
                echo "PIDs String Full: $pids_tmp"
        fi
        ## PID not found in PID file
	if [ ${#pids_tmp[@]} -eq '0' ]; then
                echo "NO match found...in PID File $PID_PATH_FULL with PID $PID_PROCESS_ID"
        else
                ## PID found in PID file
                if [ $VERBOSE_SWITCH -eq '1' ]; then
                        echo "PID Process ID $PID_PROCESS_ID found in $PID_PATH_FULL"
                        echo "Removing entry in PID File $PID_PATH_FULL with PID $PID_PROCESS_ID started"
                fi
		## Removing PID entry in PID file
                #grep -v "$PID_PROCESS_ID" $PID_PATH_FULL > "/tmp/$file_name-$PID_PROCESS_ID.tmp" && mv -f "/tmp/$file_name-$PID_PROCESS_ID.tmp" $PID_PATH_FULL
                trap 'sed -i -- '/'$PID_PROCESS_ID'/d' $PID_PATH_FULL'  EXIT #EXIT status=0/SUCCESS
                ## Check last task for errors
                status=$?
                if [ $status != 0 ]; then
                        echo "Error removing entry in PID File $PID_PATH_FULL with PID $PID_PROCESS_ID, code="$status;
                        echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
                        exit $status
                else
                        if [ $VERBOSE_SWITCH -eq '1' ]; then
                                echo "Removing entry in PID File $PID_PATH_FULL with PID $PID_PROCESS_ID finished"
                        fi
			## Check if PID file has mor content
                        readarray -t pids_tmp < <(cat "$PID_PATH_FULL")
                	if [ ${#pids_tmp[@]} -eq '0' ]; then
                        	## If PID file is empty
				if [ $VERBOSE_SWITCH -eq '1' ]; then 
                                echo "$PID_PATH_FULL is now empty... Deleting it"
					trap 'rm -f -v -- $PID_PATH_FULL' EXIT #exit 0
				else
					trap 'rm -f -- $PID_PATH_FULL' EXIT #exit 0
				fi
                		## Check last task for errors
                		status=$?
                		if [ $status != 0 ]; then
                        		echo "Error removing empty PID File $PID_PATH_FULL, code=$status"
                        		echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
                                        exit $status
                		else
                    			if [ $VERBOSE_SWITCH -eq '1' ]; then
                                                echo "Removing empty PID File $PID_PATH_FULL finished"
                                        fi
                		fi
                	fi
		fi
	fi
## If no PID exists...
else
        echo "PID $PID_PATH_FULL NOT found"
        echo "Nothing to do. EXIT"
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
        fi
        echo "!!! Error Master Module $file_name_full from $FOLDER_SOURCE to $FOLDER_TARGET, code=$status !!!"
        if [ $VERBOSE_SWITCH -eq '1' ]; then
                echo "!!! Master Module $file_name_full v$version stopped with error(s) !!!"
                sh output-styler "error"
                sh output-styler "end"
                sh output-styler "end"
        fi
        exit $status
else
        if [ $VERBOSE_SWITCH -eq '1' ]; then
                echo "<<< Master Module $file_name_full v$version finished successfully <<<"
                sh output-styler "end"
                sh output-styler "end"
        fi
        exit $status
fi
