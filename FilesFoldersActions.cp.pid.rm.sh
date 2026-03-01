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
## Parameter  6: Verbose Switch         0=Off; Default
##                                      1=On
##
## Call it like this:
## sh FilesFoldersActions.cp.pid.rm.sh \
##      "/var/run/FilesFoldersActions.cp.pid.rm.pid" \
##      "12345" \
##      "/var/log/bash/$file_name.log" \
##      "/tmp/bash/$file_name.log" \
##      "0" \
##      "1"

function func_output_optimizer () {

    declare type

    if [ "$1" = "i" ]; then
        type="INFO"
    fi

    if [ "$1" = "w" ]; then
        type="WARNING"
    fi

    if [ "$1" = "e" ]; then
        type="ERROR"
    fi

    if [ "$1" = "c" ]; then
        type="CRITICAL"
    fi

    if [ ${#type} -gt '6' ]; then
        printf "%s  %s\t%s" \
            "$(date --rfc-3339=ns)" \
            "$type" \
            "$2"
    else
        printf "%s  %s\t\t%s" \
            "$(date --rfc-3339=ns)" \
            "$type" \
            "$2"
    fi
}

function func_output_styler () {
    
    #output_length=136
    if [ "$1" = "start" ]; then
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    fi
    
    if [ "$1" = "middle" ]; then
        echo "-----------------------------------------------------------------------------------------------------------------------------------------"
    fi

    if [ "$1" = "part" ]; then
        echo "........................................................................................................................................."
    fi
    
    if [ "$1" = "trouble" ]; then
        echo "?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????"
    fi
    
    if [ "$1" = "error" ]; then
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    fi
    
    if [ "$1" = "end" ]; then
        echo "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
    fi
}

## Clear console to debug that stuff better
#clear

## Enhanced debugging with set -x
#set -x

## Set Stuff
version="0.0.1-beta.1"
file_name_full="FilesFoldersActions.cp.pid.rm.sh"
file_name="${file_name_full%.*}"

run_as_user_name=$(whoami)
run_as_user_uid=$(id -u "$run_as_user_name")
run_as_group_name=$(id -gn "$run_as_user_name")
run_as_group_gid=$(getent group "$run_as_group_name" | cut -d: -f3)
run_on_hostname=$(hostname -f)

## Check this script is running as root !
if [ "$run_as_user_uid" != "0" ]; then
    func_output_optimizer "i" "!!! ATTENTION !!!		    YOU MUST RUN THIS SCRIPT AS ROOT / SUPERUSER	        !!! ATTENTION !!!"
    func_output_optimizer "i" "!!! ATTENTION !!!		           TO USE chown AND chmod IN rsync	                !!! ATTENTION !!!"
    func_output_optimizer "i" "!!! ATTENTION !!!		     ABORT THIS SCRIPT IF YOU NEED THIS FEATURES		    !!! ATTENTION !!!"
fi

## Check this script is running as root !
#if [ "$(id -u)" != "0" ]; then
#        func_output_optimizer "i" "Aborting, this script needs to be run as root! EXIT"
#        exit 1
#fi

## Clear used stuff
declare    PID_PATH_FULL
declare -i PID
declare    SYS_LOG
declare    JOB_LOG
declare -i CONFIG_SWITCH
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
VERBOSE_SWITCH=$6

if [ $CONFIG_SWITCH -eq '1' ]; then
        ## Set the job config FILE from parameter
        config_file_in="$HOME/bin/linux/bash/local/FilesFoldersActions/$file_name.conf.in"
        func_output_optimizer "i" "Using config file $config_file_in for $file_name_full"

        ## Import stuff from config file
        set -o allexport
        # shellcheck source=$config_file_in disable=SC1091
        . "$config_file_in" 
        set +o allexport
fi

# Check if log files are set
if [ "$SYS_LOG" = "" ]; then
        func_output_optimizer "c" "System Log parameter is empty. EXIT"
        exit 2
fi

if [ "$JOB_LOG" = "" ]; then
        func_output_optimizer "c" "Job Log parameter is empty. EXIT"
        exit 2
fi

if [ ! -d "${SYS_LOG%/*}" ]; then       
        if [ $VERBOSE_SWITCH -eq '1' ]; then
                mkdir -pv "${SYS_LOG%/*}" &> "$JOB_LOG"
        else
                mkdir -p "${SYS_LOG%/*}" &> "$JOB_LOG"
        fi

        sys_log_folder_missing_switch=1
        sys_log_file_missing_switch=1
fi

# Check if user has write access to sys log file
if [ ! -w "${SYS_LOG%/*}" ]; then
        func_output_optimizer "c" "$run_as_user_name:$run_as_group_name don't have write access for sys log file $SYS_LOG. EXIT"
fi

if [ ! -d "${JOB_LOG%/*}" ]; then       
        if [ $VERBOSE_SWITCH -eq '1' ]; then
                mkdir -pv "${JOB_LOG%/*}" &> "$JOB_LOG"
        else
                mkdir -p "${JOB_LOG%/*}" &> "$JOB_LOG"
        fi

        job_log_folder_missing_switch=1
        job_log_file_missing_switch=1
fi

# Check if user has write access to job log file
if [ ! -w "${JOB_LOG%/*}" ]; then
        func_output_optimizer "c" "$run_as_user_name:$run_as_group_name don't have write access for job log file $JOB_LOG."
fi

if [ ! -w "${SYS_LOG%/*}" ] || \
        [ ! -w "${JOB_LOG%/*}" ]; then
        func_output_optimizer "w" "Please check the job config file $config_file_in. EXIT"
        exit 2
fi

# Set log files
if [ ! -f "$SYS_LOG" ]; then
        sys_log_file_missing_switch=1
        touch "$SYS_LOG" &> "$JOB_LOG"
fi

if [ ! -f "$JOB_LOG" ]; then
        job_log_file_missing_switch=1
        touch "$JOB_LOG" #&> "$JOB_LOG"
fi

# Mod Output
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3 RETURN
exec 1>>"$SYS_LOG" 2>&1


## Print file name
if [ $VERBOSE_SWITCH -eq '1' ]; then
	func_output_optimizer "i" "$(func_output_styler "start")"
	func_output_optimizer "i" "$(func_output_styler "start")"
        func_output_optimizer "i" ">>> Sub Module $file_name_full v$version starting >>>"
	func_output_optimizer "i" ">>> PID Remove Config: PID Path=$PID_PATH_FULL, PID=$PID >>>"
	func_output_optimizer "i" "$(func_output_styler "start")"
	func_output_optimizer "i" "$(func_output_styler "middle")"
        func_output_optimizer "i" "Filename: $file_name_full"
        func_output_optimizer "i" "Version: v$version"
        func_output_optimizer "i" "Run as user name: $run_as_user_name"
        func_output_optimizer "i" "Run as user uid: $run_as_user_uid"
        func_output_optimizer "i" "Run as group: $run_as_group_name"
        func_output_optimizer "i" "Run as group gid: $run_as_group_gid"
        func_output_optimizer "i" "Run on host: $run_on_hostname"
        func_output_optimizer "i" "Verbose is ON"
	func_output_optimizer "i" "PID File: $PID_PATH_FULL"
	func_output_optimizer "i" "PID Process ID: $PID"

	if [ $CONFIG_SWITCH -eq '0' ]; then
		func_output_optimizer "i" "Config Mode is on Parameters"
	else
		func_output_optimizer "i" "Config Mode is on Config file"
	fi

	if [ "$sys_log_folder_missing_switch" -eq '1' ]; then
		func_output_optimizer "w" "Sys log folder: ${SYS_LOG%/*} is missing"
		func_output_optimizer "i" "Creating it at ${SYS_LOG%/*}"
	fi

	if [ "$sys_log_file_missing_switch" -eq '1' ]; then
		func_output_optimizer "w" "Sys log file: $SYS_LOG is missing"
		func_output_optimizer "i" "Creating it at $SYS_LOG"
	fi

	if [ "$job_log_file_missing_switch" -eq '1' ]; then
		func_output_optimizer "w" "Job log file: $JOB_LOG is missing"
		func_output_optimizer "i" "Creating it at $JOB_LOG"
	fi

        if [ "$job_log_folder_missing_switch" -eq '1' ]; then
		func_output_optimizer "w" "Sys log folder: ${JOB_LOG%/*} is missing"
		func_output_optimizer "i" "Creating it at ${JOB_LOG%/*}"
	fi

        func_output_optimizer "i" "Output to console...As $run_as_user_name:$run_as_group_name can see ;)"
	func_output_optimizer "i" "Output to sys log file $SYS_LOG"
	func_output_optimizer "i" "Output to job log file $JOB_LOG"
fi

## Only one instance of this script should ever be running and as its use is normally called via cron, if it's then run manually
## for test purposes it may intermittently update the ports.tcp & ports.udp files unnecessarily. So here we check no other instance
## is running. If another instance is running we pause for 5 seconds and then delete the PID anyway. Normally this script will run
## in under 150ms and via cron runs every 60 seconds, so if the PID file still exists after 5 seconds then it's a orphan PID file.
#if [ -f "$PID_PATH_FULL" ]; then
        #sleep 5 #if PID file exists wait 5 seconds and test again, if it still exists delete it and carry on
        #func_output_optimizer "i" "There appears to be another Process $file_name PID $PID_PATH_FULL is already running, waiting for 5 seconds ..."
        #rm -f -- "$PID_PATH_FULL"
#fi
#trap 'rm -f -- $PID_PATH_FULL' EXIT #EXIT status=0/SUCCESS
#echo "$PID" > "$PID_PATH_FULL"


## Check for input error(s)
if [ "$PID_PATH_FULL" = "" ]; then
        func_output_optimizer "c" "PID File parameter is empty. EXIT"
        exit 2
fi

if [ ! -d "${PID_PATH_FULL%/*}" ]; then
        func_output_optimizer "c" "PID File directory ${PID_PATH_FULL%/*} is not valid. EXIT"
        exit 2
fi

if [ "$PID" = "" ]; then
        func_output_optimizer "c" "PID Process ID is empty"
        exit 2
fi

if [[ $PID =~ [^[:digit:]] ]]; then
        func_output_optimizer "c" "PID parameter $PID is not a valid. EXIT"
        exit 2
fi

if [ "$CONFIG_SWITCH" -gt '1' ] || \
   [[ $CONFIG_SWITCH =~ [^[:digit:]] ]]; then
        func_output_optimizer "c" "Config Switch parameter $CONFIG_SWITCH is not a valid. EXIT"
        exit 2
fi

if [ "$VERBOSE_SWITCH" -gt '1' ] || \
   [[ $VERBOSE_SWITCH =~ [^[:digit:]] ]]; then
        func_output_optimizer "c" "Verbose Switch parameter $VERBOSE_SWITCH is not a valid. Set to Default 0"
        VERBOSE_SWITCH=0
fi

if [ ! -f "$PID_PATH_FULL" ]; then
        func_output_optimizer "c" "PID file $PID_PATH_FULL not found. EXIT"
        exit 2
 else       
        if [ $VERBOSE_SWITCH -eq '1' ]; then
                func_output_optimizer "c" "PID file $PID_PATH_FULL found"
        fi
        
fi

## Lets roll
## If no PID exists...
if [ ! -f "$PID_PATH_FULL" ]; then
        func_output_optimizer "c" "PID file $PID_PATH_FULL NOT found"
        func_output_optimizer "c" "Nothing to do. EXIT"
        exit 1
else
        ## If PID exists...
        ## Get content of PID file
        readarray -t pids < <(cat "$PID_PATH_FULL" | grep $PID)
        if [ $VERBOSE_SWITCH -eq '1' ]; then

                for pid in "${!pids[@]}"
                do
                        func_output_optimizer "i" "Array pids element $pid: ${pids[$pid]}"
                done
        fi
        ## PID not found in PID file
	if [ ${#pids[@]} -eq '0' ]; then
                func_output_optimizer "c" "NO match found...in PID File $PID_PATH_FULL with PID $PID"
        elif [ ${#pids[@]} -gt '1' ]; then
                func_output_optimizer "e" "Something is wrong here..."
                func_output_optimizer "c" "I found more then 1 entry in PID file $PID_PATH_FULL with PID $PID"
                func_output_optimizer "e" "PLEASE check this. THANKS"
                func_output_optimizer "i" "I will now quit"
                exit 1
        else
                ## PID found in PID file
                if [ $VERBOSE_SWITCH -eq '1' ]; then
                        func_output_optimizer "i" "PID Process ID $PID found in $PID_PATH_FULL"
                        func_output_optimizer "i" "Removing entry in PID File $PID_PATH_FULL with PID $PID started"
                fi
		## Removing PID entry in PID file

                #trap 'sed -i -- '/'$PID'/d' $PID_PATH_FULL'  exit
                sed -i -- '/'$PID'/d' "$PID_PATH_FULL" &> "$JOB_LOG"
                ## Check last task for errors
                status=$?
                if [ $status != 0 ]; then
                        func_output_optimizer "e" "Error removing entry in PID File $PID_PATH_FULL with PID $PID, code="$status;
                        func_output_optimizer "e" "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
                        exit $status
                else
                        ## Check if the job has worked correctly
                        readarray -t pids_tmp < <(cat "$PID_PATH_FULL" | grep $PID) &> "$JOB_LOG"
                        if [ ${#pids_tmp[@]} -eq '0' ]; then
                                if [ $VERBOSE_SWITCH -eq '1' ]; then
                                        func_output_optimizer "i" "Removing entry in PID File $PID_PATH_FULL with PID $PID finished successfully"
                                fi
                        fi
			## Check if PID file has more content
                        readarray -t pids_tmp < <(cat "$PID_PATH_FULL") &> "$JOB_LOG"
                	if [ ${#pids_tmp[@]} -eq '0' ]; then
                        	## If PID file is empty
				if [ $VERBOSE_SWITCH -eq '1' ]; then 
                                        func_output_optimizer "i" "$PID_PATH_FULL is now empty... Deleting it"
					#trap 'rm -f -v -- $PID_PATH_FULL' EXIT #exit 0
                                        rm -f -v "$PID_PATH_FULL" &> "$JOB_LOG"
				else
					#trap 'rm -f -- $PID_PATH_FULL' EXIT #exit 0
                                        rm -f "$PID_PATH_FULL" &> "$JOB_LOG"
				fi
                		## Check last task for errors
                		status=$?
                		if [ $status != 0 ]; then
                        		func_output_optimizer "e" "Error removing empty PID File $PID_PATH_FULL, code=$status"
                        		func_output_optimizer "e" "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
                                        exit $status
                		else
                    			if [ $VERBOSE_SWITCH -eq '1' ]; then
                                                func_output_optimizer "e" "Removing empty PID File $PID_PATH_FULL finished successfully"
                                        fi
                		fi
                	fi
		fi
	fi
fi

if [ $VERBOSE_SWITCH -eq '1' ]; then
	func_output_optimizer "i" "$(func_output_styler "middle")"
	func_output_optimizer "i" "$(func_output_styler "end")"
fi

## Check last task for errors
status=$?
if [ $status != 0 ]; then
        if [ $VERBOSE_SWITCH -eq '1' ]; then
	        func_output_optimizer "i" "$(func_output_styler "error")"
        fi
        func_output_optimizer "e" "!!! Error Sub Module $file_name_full from $FOLDER_SOURCE to $FOLDER_TARGET, code=$status !!!"
        if [ $VERBOSE_SWITCH -eq '1' ]; then
                func_output_optimizer "e" "!!! PID Remove Config: PID Path=$PID_PATH_FULL, PID=$PID !!!"
                func_output_optimizer "e" "!!! Sub Module $file_name_full v$version stopped with error(s) !!!"
	        func_output_optimizer "e" "$(func_output_styler "error")"
	        func_output_optimizer "i" "$(func_output_styler "end")"
	        func_output_optimizer "i" "$(func_output_styler "end")"
        fi
        exit $status
else
        if [ $VERBOSE_SWITCH -eq '1' ]; then
                func_output_optimizer "i" "<<< PID Remove Config: PID Path=$PID_PATH_FULL, PID=$PID <<<"
                func_output_optimizer "i" "<<< Sub Module $file_name_full v$version finished successfully <<<"
	        func_output_optimizer "i" "$(func_output_styler "end")"
	        func_output_optimizer "i" "$(func_output_styler "end")"
        fi
        exit $status
fi
