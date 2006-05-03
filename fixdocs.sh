#!/bin/bash
# Created: Vipin Bhatnagar 28-Mar-2006
# replaces the @DATE@ strings in the doc files
# with mtime for doxygen
#
ARG=$1
for i in src/*/*/doc/*.dox; do
  SUBPACK=`echo $i | cut -d "/" -f2,3`
  CVTAG=`CmsTCPackageList.pl --pack $SUBPACK --rel $ARG | cut -d " " -f2`
  DATUM=`/usr/bin/stat --format="%y" "$i" | cut -d " " -f1`
  sed -e "s/@DATE@/$DATUM/g" \
      -e "s/@CVS_TAG@/$CVTAG/g" "$i" > "${i/.dox}".doy
done
