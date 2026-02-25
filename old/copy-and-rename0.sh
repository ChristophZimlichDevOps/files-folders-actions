#!/bin/bash
echo "Main Part of the Script: $0"

PathInternal=/backup/internal/mysql
echo "Path Internal: $PathInternal"

PathExternal=/backup/external/mysql
echo "Path External: $PathExternal"

FileName=current-*.sql.gz
echo "FileName Style: $FileName"

FilesInternal=$(ls $PathInternal/$FileName)
echo "File(s): $FilesInternal"

Date=$(date +%Y%m%d%H%M%S)
echo "DateTimeStamp: $Date"

#sh /home/christoph.zimlich/bin/linux/shell/FilesFoldersActions/old/copy-and-rename1copy-files-2-target.sh $PathInternal $FileName $PathExternal

FilesExternal=$(ls $PathExternal/$FileName)
#echo "File(s): ${FilesExternal[@]"

sh /home/christoph.zimlich/bin/linux/shell/FilesFoldersActions/old/copy-and-rename2rename-mysqldump.sh $Date $PathInternal $PathExternal "${FilesInternal[@]}"
#sh /home/christoph.zimlich/bin/linux/shell/FilesFoldersActions/old/copy-and-rename2rename-mysqldump.sh $Date "${FilesInternal[@]}" "${FilesExternal[@]}"

echo "Job is done. Thanks 4 waiting"
echo "Have a nice Judgement Day"
echo "Greetings"
echo "Your Sahra Conner"
