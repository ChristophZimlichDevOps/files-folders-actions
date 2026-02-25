#!/bin/bash

## Creator: Christoph Zimlich
##
##
## Summary
## This script will move folders and maybe recreate it like you want. Useful for backups for example.
##
## Parameter 1: Folder Source i.e. "/tmp/"
## Parameter 2: Folder Name Part Old i.e. "current" !!! NO WILDCARDS ALLOWED !!!
## Parameter 3: Folder Name Part New i.e. "$(date +%y%m%d%H%M%S)"
## Parameter 4: Recreate Folder Switch "--recreate-folder"=On...Folder will be recreated after renaming
##              else=Off...Folder will NOT be recreated after renaming
## Parameter 5: Output Switch "--logfile"=On...Output to logfile
##              else=Off...Output to console
## Parameter 6: Verbose Switch "-v"=On, else=Off
##
## Call it like this:
## sh FolderMv.sh "/home/backup/mysql/" "current" "$(date +%y%m%d%H%M%S)" "--recreate-folder-not" "--console" "-v"
## sh FolderMv.sh "/home/backup/mysql/" "current" "$(date +%y%m%d%H%M%S)" "--recreate-folder" "--logfile"
## sh FolderMv.sh "/home/backup/mysql/" "current" "$(date +%y%m%d%H%M%S)" "whatyouwant" "whatyouwant" "whatyouwant"

## Clear console to debug that stuff better
clear

## Enhanced debugging with set -x
#set -x

## Set Stuff
version="0.0.1"
file_name_full="FolderMv.sh"
file_name="FolderMv"
log="/tmp/$file_name.log"
FolderMvPID="/var/run/$file_name.pid"

## Check this script is running as root !
if [ "$(id -u)" != "0" ]; then echo "Aborting, this script needs to be run as root! EXIT";EXIT status=1/FAILURE;fi

## Only one instance of this script should ever be running and as its use is normally called via cron, if it's then run manually
## for test purposes it may intermittently update the ports.tcp & ports.udp files unnecessarily. So here we check no other instance
## is running. If another instance is running we pause for 3 seconds and then delete the PID anyway. Normally this script will run
## in under 150ms and via cron runs every 60 seconds, so if the PID file still exists after 3 seconds then it's a orphan PID file.
if [ -f "$FolderMvPID" ]; then
        sleep 3 #if PID file exists wait 3 seconds and test again, if it still exists delete it and carry on
        echo "There appears to be another Process $file_name_full PID $FolderMvPID is already running, waiting for 3 seconds ..."
        rm -f -- "$FolderMvPID"
fi
trap 'rm -f -- $FolderMvPID' EXIT #EXIT status=0/SUCCESS
echo $$ > "$FolderMvPID"

## Clear used stuff
declare -i output_switch
declare -i verbose_switch
declare -i logfile_missing_switch
declare -i status

## Check for arguments
folder_source=$1
folder_name_part_old=$2
folder_name_part_new=$3

if [ "$4" = --recreate-folder ]; then folder_recreate_switch=1; else folder_recreate_switch=0;fi
if [ "$5" = --logfile ]; then output_switch=1; else output_switch=0;fi
if [ "$6" = -v ]; then verbose_switch=1; else verbose_switch=0;fi

## Print file name
if [ $verbose_switch -eq '1' ]; then
        sh OutputStyler "start"
        echo ">>> Modul $file_name_full v$version starting >>>"
echo ">>> Move Config: Folder Source=$folder_source, Folder Name Part Old=$folder_name_part_old, Folder Name Part New=$folder_name_part_new >>>";fi


# Set log files
if [ ! -f $log ]; then logfile_missing_switch=1; else logfile_missing_switch=0;fi
if [ $logfile_missing_switch -eq '1' ]; then touch $log;fi
if [ $output_switch -eq '1' ]; then
        exec 3>&1 4>&2
        trap 'exec 2>&4 1>&3' 0 1 2 3 RETURN
        exec 1>>"$SYS_LOG" 2>&1
fi

if [ $verbose_switch -eq '1' ]; then
        if [ $output_switch -eq '1' ]; then
		sh OutputStyler "start"
        	echo ">>> Modul $file_name_full v$version starting >>>"
        	echo ">>> Move Config: Folder Source=$folder_source, Folder Name Part Old=$folder_name_part_old, Folder Name Part New=$folder_name_part_new >>>";fi
	sh OutputStyler "start"
	sh OutputStyler "middle"
	# shellcheck disable=SC2140
	echo "!!! ATTENTION !!! Parameter 2: File Name Part Old i.e. "current"	!!! ATTENTION !!!"
        echo "!!! ATTENTION !!!            NO WILDCARDS ALLOWED		!!! ATTENTION !!!"
	echo "Filename: $file_name_full"
        echo "Version: $version"
        echo "Verbose is ON"
	echo -n "Recreating Folder is "; if [ $folder_recreate_switch -eq '1' ]; then echo "ON"; else echo "OFF";fi
        if [ $logfile_missing_switch -eq '1' ]; then
                echo "Logfile: $log is missing"
                echo "Creating it at $log"
        fi
        if [ $output_switch -eq '1' ]; then echo "Output to logfile $log";fi
else echo "Output to console...As you can see xD";fi

## Check input stuff
if [ "$folder_source" = "" ]; then echo "Folder Source parameter is empty. EXIT";EXIT status=2/FAILURE;fi
if [ ! -d "$folder_source" ]; then echo "Folder Source parameter $folder_source is not a valid folder path. EXIT";EXIT status=2/FAILURE;fi
if [ "$folder_name_part_old" = "" ]; then echo "Folder Name Part Old parameter is empty. EXIT";EXIT status=2/FAILURE;fi
if [ "$folder_name_part_old" != "${folder_name_part_old//[\[\]|.? +*]/}" ]; then echo "Folder Name Part Old parameter $folder_name_part_old has wildcards * or ?... NOT ALLOWED. EXIT";EXIT status=2/FAILURE;fi
if [ "$folder_name_part_new" = "" ]; then echo "Folder Name Part New parameter is empty. EXIT";EXIT status=2/FAILURE;fi

## Lets roll
if [ $verbose_switch -eq '1' ]; then
	echo "Folder Source: $folder_source"
	echo "Folder Name Part Old: $folder_name_part_old"
	echo "Folder Name Part New: $folder_name_part_new"
	echo "Folder Name Full New: ${folder_source/$folder_name_part_old/"$folder_name_part_new"}"
	#echo "Folder Target: $folder_target"
	echo "Starting renaming folder from $folder_source to $folder_source$folder_name_part_new"
	mv -v "$folder_source" "$folder_source""$folder_name_part_new"
else
	mv "$folder_source" "$folder_source""$folder_name_part_new"
fi
## Check last task for errors
status=$?
if [ $status != 0 ]; then echo "Error renaming folder from $folder_source$folder_name_part_old to $folder_source$folder_name_part_new, code="$status;EXIT status=$status/FAILURE
else
        if [ $verbose_switch -eq '1' ]; then echo "Finished renaming folder from $folder_source$folder_name_part_old to $folder_source$folder_name_part_new";fi
fi

if [ $folder_recreate_switch -eq '1' ] ; then
	#if [ ! -d $folder_source$folder_name_part_old]; then echo "lol";else  echo "Folder to recreate $folder_source$folder_name_part_old already exists. EXIT";EXIT status=21/FAILURE;fi
	if [ $verbose_switch -eq '1' ]; then
	    echo "Starting recreate old folder at $folder_source$folder_name_part_old"
		mkdir -v "$folder_source" #$folder_name_part_old
		## for testing
		#cp -R -f -v $folder_source"sub/" $folder_source$folder_name_part_old
	else
		mkdir "$folder_source" #$folder_name_part_old
        ## for testing
		#cp -R -f $folder_source"sub/" $folder_source$folder_name_part_old
	fi
fi

if [ $verbose_switch -eq '1' ]; then
	sh OutputStyler "middle"
	sh OutputStyler "end"
fi

## Check last task for errors
STATUS=$?
if [ $STATUS != 0 ]; then
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		sh OutputStyler "error"
	fi
	echo "!!! Error Master Modul $FILE_NAME_FULL from $FOLDER_SOURCE to $FOLDER_TARGET, code=$STATUS !!!"
	if [ $VERBOSE_SWITCH -eq '1' ]; then
		echo "!!! Master Modul $FILE_NAME_FULL v$VERSION stopped with error(s) !!!"
		sh OutputStyler "error"
		sh OutputStyler "end"
		sh OutputStyler "end"
	fi
	exit $STATUS
else
	if [ $VERBOSE_SWITCH -eq '1' ]; then
			echo "<<< Master Modul $FILE_NAME_FULL v$VERSION finished successfully <<<"
		sh OutputStyler "end"
		sh OutputStyler "end"
	fi
	exit $STATUS
fi
