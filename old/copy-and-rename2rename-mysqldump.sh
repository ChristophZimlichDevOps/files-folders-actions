#!/bin/bash
echo "2.Sub Part of the Script: $0"

echo "Par1 - Date: $1"
echo "Par2 - Path Int: $2"
echo "Par3 - Path Ext: $3"
echo "Rename content current 2 $1"
echo "File: $@"
echo "Start renaming..."

#rename -v current $1 "${1[@]}"

#rename -v current $1 "${2[@]}"

files_string_full="find $2 -maxdepth 1 -type f -name current -ls"

	#files=( $( find "$folder_source" -maxdepth "$folder_deep" -type f -name "$name_part_old" -ls | awk '{print $NF}') )
	files=( "$( find "$folder_source" -maxdepth 1 -type f -name "$name_part_old" -ls | awk '{print $NF}')" )

	for item in "${files[@]}"; do echo "Array files: $item"; done

	if [ ${#files[@]} -eq '0' ]; then echo "No file(s) to rename at $folder_source$name_part_old."
	else
		for file in "${files[@]}"
		do
        		if [ ! -f "$file" ]; then echo "File Path $file is not a valid. Go to next one. NEXT";break;fi
                		rename -v "$name_part_old_clean" "$name_part_new" "$file"
       
        	## Check last task for errors
        	status=$?
        	if [ $status != 0 ]; then
                	echo "Error renaming file $file from $name_part_old_clean to $name_part_new, code="$status;
                        echo "!!! Sub Modul $file_name_full v$version stopped with error(s) !!!"; break;EXIT status=$status/FAILURE
        	else
                	if [ $verbose_switch -eq '1' ]; then echo "Renaming file $file from $name_part_old_clean to $name_part_new finished";fi
        	fi
		done
	fi

echo "Finished renaming..."
