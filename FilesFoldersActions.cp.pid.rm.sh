#!/bin/bash

## Creator: Christoph Zimlich
##
##
## Summary
## This script will remove the entry of the PID file or completely delete it....if it's only 1 entry....and that's the current on. Useful for backups for example.
##
## Parameter  1: PID Full Path i.e.     "/var/run/test.pid"
## Parameter  2: PID i.e.               "54895"
## Parameter  3: Sys log i.e.           "/var/log/bash/$file_name.log"
## Parameter  4: Job log i.e.           "/tmp/bash/$file_name.log"
## Parameter  5: Config Switch          0=Parameters; Default
##                                      1=Config file
## Parameter  6: Output Switch          0=Console
##                                      1=Logfile; Default
## Parameter  7: Verbose Switch         0=Off
##                                      1=On; Default
##
## Call it like this:
## sh FilesFoldersActions.cp.pid.rm.sh \
##      "/var/run/FilesFoldersActions.cp.pid.rm.pid" \
##      "12345" "/var/log/bash/$file_name.log" \
##      "/tmp/bash/$file_name.log" \
##      "0" \
##      "0" \
##      "1"

## Clear console to debug that stuff better
#clear

## Enhanced debugging with set -x
#set -x

## Set Stuff
version="0.0.1-alpha.1"
file_name_full="FilesFoldersActions.cp.pid.rm.sh"
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

## Check this script is running as root !
#if [ "$(id -u)" != "0" ]; then
#        echo "Aborting, this script needs to be run as root! EXIT"
#        exit 1
#fi

## Clear used stuff
declare    PID_PATH_FULL
declare -i PID
declare    SYS_LOG
declare    JOB_LOG
declare -i CONFIG_SWITCH
declare -i OUTPUT_SWITCH
declare -i VERBOSE_SWITCH
## Clear used stuff
declare    config_file_in
declare -a pids
declare -a pids_tmp
declare -i sys_log_folder_missing_switch=0
declare -i sys_log_file_missing_switch=0
declare -i job_log_folder_missing_switch=0
declare -i job_log_file_missing_switch=0
declare -i status

## Set parameters
PID_PATH_FULL=$1
PID=$2
SYS_LOG=$3
JOB_LOG=$4
CONFIG_SWITCH=$5
OUTPUT_SWITCH=$6
VERBOSE_SWITCH=$7

if [ $CONFIG_SWITCH -eq '1' ]; then
        ## Set the job config FILE from parameter
        config_file_in="$HOME/bin/linux/shell/local/FilesFoldersActions/$file_name.conf.in"
        echo "Using config file $config_file_in for $file_name_full"

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

## Only one instance of this script should ever be running and as its use is normally called via cron, if it's then run manually
## for test purposes it may intermittently update the ports.tcp & ports.udp files unnecessarily. So here we check no other instance
## is running. If another instance is running we pause for 5 seconds and then delete the PID anyway. Normally this script will run
## in under 150ms and via cron runs every 60 seconds, so if the PID file still exists after 5 seconds then it's a orphan PID file.
#if [ -f "$PID_PATH_FULL" ]; then
        #sleep 5 #if PID file exists wait 5 seconds and test again, if it still exists delete it and carry on
        #echo "There appears to be another Process $file_name PID $PID_PATH_FULL is already running, waiting for 5 seconds ..."
        #rm -f -- "$PID_PATH_FULL"
#fi
#trap 'rm -f -- $PID_PATH_FULL' EXIT #EXIT status=0/SUCCESS
#echo "$PID" > "$PID_PATH_FULL"

if [ ! -f "$PID_PATH_FULL" ]; then
        echo "PID file $PID_PATH_FULL not found. EXIT"
        exit 2
 else       
        if [ $VERBOSE_SWITCH -eq '1' ]; then
                echo "PID file $PID_PATH_FULL found"
        fi
        
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
	echo ">>> PID Remove Config: PID Path=$PID_PATH_FULL, PID=$PID >>>"
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
	echo "PID File: $PID_PATH_FULL"
	echo "PID Process ID: $PID"

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

## Lets roll
## If no PID exists...
if [ ! -f "$PID_PATH_FULL" ]; then
        echo "PID file $PID_PATH_FULL NOT found"
        echo "Nothing to do. EXIT"
        exit 1
else
        ## If PID exists...
        ## Get content of PID file
        readarray -t pids < <(cat "$PID_PATH_FULL" | grep $PID)
        if [ $VERBOSE_SWITCH -eq '1' ]; then

                for pid in "${!pids[@]}"
                do
                        echo "Array pids element $pid: ${pids[$pid]}"
                done
        fi
        ## PID not found in PID file
	if [ ${#pids[@]} -eq '0' ]; then
                echo "NO match found...in PID File $PID_PATH_FULL with PID $PID"
        elif [ ${#pids[@]} -gt '1' ]; then
                echo "Something is wrong here..."
                echo "I found more then 1 entry in PID file $PID_PATH_FULL with PID $PID"
                echo "PLEASE check this. THANKS"
                echo "I will now quit"
                exit 1
        else
                ## PID found in PID file
                if [ $VERBOSE_SWITCH -eq '1' ]; then
                        echo "PID Process ID $PID found in $PID_PATH_FULL"
                        echo "Removing entry in PID File $PID_PATH_FULL with PID $PID started"
                fi
		## Removing PID entry in PID file

#>>>>>>>>>>>>>>>>>>>>>>>>>>     HERE IS THE BUG     <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                #trap 'sed -i -- '/'$PID'/d' $PID_PATH_FULL'  exit
                sed -i -- '/'$PID'/d' "$PID_PATH_FULL"
                ## Check last task for errors
                status=$?
                if [ $status != 0 ]; then
                        echo "Error removing entry in PID File $PID_PATH_FULL with PID $PID, code="$status;
                        echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
                        exit $status
                else
                        ## Check if the job has worked correctly
                        readarray -t pids_tmp < <(cat "$PID_PATH_FULL" | grep $PID)
                        if [ ${#pids_tmp[@]} -eq '0' ]; then
                                if [ $VERBOSE_SWITCH -eq '1' ]; then
                                        echo "Removing entry in PID File $PID_PATH_FULL with PID $PID finished successfully"
                                fi
                        fi
			## Check if PID file has more content
                        readarray -t pids_tmp < <(cat "$PID_PATH_FULL")
                	if [ ${#pids_tmp[@]} -eq '0' ]; then
                        	## If PID file is empty
				if [ $VERBOSE_SWITCH -eq '1' ]; then 
                                        echo "$PID_PATH_FULL is now empty... Deleting it"
					#trap 'rm -f -v -- $PID_PATH_FULL' EXIT #exit 0
                                        rm -f -v "$PID_PATH_FULL"
				else
					#trap 'rm -f -- $PID_PATH_FULL' EXIT #exit 0
                                        rm -f "$PID_PATH_FULL"
				fi
                		## Check last task for errors
                		status=$?
                		if [ $status != 0 ]; then
                        		echo "Error removing empty PID File $PID_PATH_FULL, code=$status"
                        		echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
                                        exit $status
                		else
                    			if [ $VERBOSE_SWITCH -eq '1' ]; then
                                                echo "Removing empty PID File $PID_PATH_FULL finished successfully"
                                        fi
                		fi
                	fi
		fi
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
        fi
        echo "!!! Error Sub Module $file_name_full from $FOLDER_SOURCE to $FOLDER_TARGET, code=$status !!!"
        if [ $VERBOSE_SWITCH -eq '1' ]; then
                echo "!!! PID Remove Config: PID Path=$PID_PATH_FULL, PID=$PID !!!"
                echo "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
                sh OutputStyler "error"
                sh OutputStyler "end"
                sh OutputStyler "end"
        fi
        exit $status
else
        if [ $VERBOSE_SWITCH -eq '1' ]; then
                echo "<<< PID Remove Config: PID Path=$PID_PATH_FULL, PID=$PID <<<"
                echo "<<< Sub Module $file_name_full v$version finished successfully <<<"
                sh OutputStyler "end"
                sh OutputStyler "end"
        fi
        exit $status
fi
