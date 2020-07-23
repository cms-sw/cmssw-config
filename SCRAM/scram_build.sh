#!/bin/bash
errfile="${SCRAM_INTwork}/build_error"
rm -f ${errfile}
(${SCRAM_GMAKE_PATH}gmake "$@" && [ ! -e ${errfile} ]) || (err=$?; echo "gmake: *** [There are compilation/build errors. Please see the detail log above.] Error $err" && exit $err)
