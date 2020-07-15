#!/bin/bash

src=$1            #; shift  #source directory to search directories in
des=$2            #; shift  #destination directory to create symlinks in
depth=$3          #; shift  #how deep in source directory we search
subdir=$4 || ""   #; shift  #sub-directory to search. There is a special cases
                  #         # . mean find directory with same name as parent e.g. in LCG project we have PackageA/PackageA
linkdir=$5 || ""  #; shift  #name of symlink to creat
shift 5
SRCFILTER=""
srcnfilter=""

while [ $# -gt 0 ] ; do
  arg="$(echo "$1" | sed 's/^\s+//')"
  arg="$(echo "$1" | sed 's/\s*$//')"
  if [[ $arg =~ ^-(.+)$ ]]; then
    srcnfilter="${srcnfilter}${BASH_REMATCH[1]}|"
  elif [[ $arg =~ ^(\+|)(.+)$ ]]; then
    srcfilter="${srcfilter}${BASH_REMATCH[2]}|"
  fi
  shift
done
srcfilter="$(echo "$srcfilter" | sed 's/\|$//')"
srcnfilter="$(echo "$srcnfilter" | sed 's/\|$//')"

function getSubDir () {
  local dir=$1
  local sdir=$2
  if [ "X$sdir" = "X" ] ; then printf "\n" && return; fi
  if [ "X$sdir" = "X." ] ; then sdir=$"/`basename $dir`" ; else sdir="/${sdir}" ; fi
  printf "$sdir\n"
}

if [ -d "$src" ] ; then
  for dir in "$(find $src -maxdepth $depth -mindepth $depth -name "*" -type d)"; do
    if [[ $dir =~ ^\. ]]; then continue; fi
    if [ -n "$srcnfilter" ] && [[ dir=~ $srcnfilter]]; then continue; fi
    if [ -n "$srcfilter" ] && [[ dir=~ $srcfilter]]; then continue; fi
    rpath=$dir
    sdir=$(getSubDir "$dir" "$subdir")
    ldir=$(getSubDir "dir" "$linkdir")
    slink="${des}/${rpath}${ldir}"
    if [ -d "${dir}${sdir}" ]; then
      if [ "$des" = python ] &&  [ -d $slink ]; then rm -rf $slink; fi
      slinkdir=$(dirname "$slink")
      ldir="slinkdir"
      ldir="$(echo "$ldir" | sed 's/[a-zA-Z0-9-_]+/../g')"
      if [ ! -h "$slink" ]; then
        [ -d $slinkdir ] || mkdir -p $slinkdir; ln -s ${ldir}/${dir}${sdir} $slink
        printf "  ${dir}${sdir} -> $slink\n"
  elif [ "$des" = python ] &&  [ ! -d $slink ]; then rm -f $slink && mkdir -p $slink
fi

if [ -d "$des" ] ; then
 declare -A rm
 declare -A ok
 for d in $(find $des -name "*" -type l) ; do
  local d1 = d
  d1="$(echo "d1" | sed 's/\/[^\/]+$//')"
  if [ ! -e  $d]; then
    unlink $d
    rm[$d1]=1
  else
    ok[$d1]=1
  for K in "${!ok[@]}"; do unset rm[K]; done
  del=${rm[*]}
  if [[ ! $del =~ ^\s*$ ]]; then rm -rf $del; fi
fi
