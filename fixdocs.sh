#!/bin/bash
# Created: Vipin Bhatnagar 28-Mar-2006
# replaces the @DATE@ strings in the doc files
# with mtime for doxygen
#
for i in src/*/*/doc/*.dox; do  
  DATUM=`/usr/bin/stat --format="%y" "$i" | cut -d " " -f1`
  sed "s/@DATE@/$DATUM/g" "$i" > "${i/.dox}".doy
done
