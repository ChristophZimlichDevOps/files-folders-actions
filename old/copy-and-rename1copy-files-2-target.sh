#!/bin/bash
echo "1.Sub Part of the Script: $0"

echo "Starting copy File(s)...Please, wait."
echo "Par1 PathInternal: $1"
echo "Par2 FileName: $2"
echo "Par3 PathExternal: $3"
echo "Start copying File(s)..."

cp  $1/$2 $3 #$PathInternal/$FileName $PathExternal

#cp /backup/internal/mysql/current-*.sql.gz /backup/external/mysql

echo "Finished copying File(s)..."
