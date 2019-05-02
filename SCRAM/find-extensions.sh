#!/bin/bash
cd $CMSSW_BASE
TMPDIR=$1 ; shift
if [ ! -f $TMPDIR/uses.out ] ; then
  mkdir -p $TMPDIR
  gunzip -qc $CMSSW_RELEASE_BASE/etc/dependencies/uses.out.gz > $TMPDIR/uses.out
fi
PKGS=$@
if [ "$PKGS" = "" ] ; then
  for pkg in $(find src -mindepth 2 -maxdepth 2 -type d | grep -v '/.git/' | sed 's|^src/||') ; do
    PKGS="${PKGS} ${pkg}"
  done
fi
PKG_REGEX=""
for pkg in ${PKGS} ; do
  PKG_REGEX="${PKG_REGEX}\|^${pkg}/"
done
PKG_REGEX=$(echo "$PKG_REGEX" | sed 's/^\\|//')
cat $TMPDIR/uses.out | tr ' ' '\n' | grep "$PKG_REGEX" | sort -u | sed 's|^.*\.||' | sort -u
