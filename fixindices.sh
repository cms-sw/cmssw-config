#/bin/bash
#for cmsglimpse usage: Vipin Bhatnagar 20-SEP-2006
for x in `ls -A1 .glimpse_full`
do
    ln -s .glimpse_full/$x $x
done
rm -rf .glimpse_filenames
cp .glimpse_full/.glimpse_filenames .glimpse_filenames.tmp
sed -e "s|$LOCALTOP/src/||g" .glimpse_filenames.tmp > .glimpse_filenames
rm -rf .glimpse_filenames.tmp
