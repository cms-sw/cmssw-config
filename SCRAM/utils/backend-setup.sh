#!/bin/bash -e
backend=$(echo $1 | cut -d- -f2 | cut -d: -f1)
req_type=$(echo $1 | cut -d- -f1)
CAPS=$(echo $1 | cut -d- -f2 | cut -d: -f2)
TOOL=config/toolbox/${SCRAM_ARCH}/tools/selected/${backend}.xml

if [ ! -e ${TOOL} ] ; then
  echo "Error: Unknown backend ${backend}" >&2
  exit 1
fi

TOOL_FLAG="$(echo ${backend} | tr a-z A-Z)_FLAGS"
FLAG_VALUES=()
if [ "${CAPS}" = "reset" ] ; then
  cp -f $CMSSW_RELEASE_BASE/${TOOL} ${TOOL}.tmp
elif [ "${backend}" = "cuda" ] ; then
  if [ "${CAPS}" = "native" ] ; then
    DOTS=$(cudaComputeCapabilities | awk '{ print "sm_"$2 }')
    CAPS=$(echo $DOTS | sed -e 's#\.*##g')
    if [ "${CAPS}" = "" ] ; then
      echo "Warning: Unable to find cuda compute capabilities." >&2
      exit 0
    fi
  fi
  cp -f ${TOOL} ${TOOL}.tmp

  # remove existing capabilities
  sed -r -i -e 's/-gencode +arch=compute[^ "]+//g' ${TOOL}.tmp

  # set supported capabilities found on this host
  for CAP in $(echo $CAPS | tr ' ,' '\n\n' | sort -u | sed 's#^sm_##g'); do
    FLAG_VALUES+=("-gencode arch=compute_$CAP,code=[sm_$CAP,compute_$CAP]")
  done
elif [ "${backend}" = "rocm" ] ; then
  if [ "${CAPS}" = "native" ] ; then
    CAPS=$(rocmComputeCapabilities | awk '{ print $2 }' | tr '\n' ' ')
    if [ "${CAPS}" = "" ] ; then
      echo "Warning: Unable to find rocm compute capabilities." >&2
      exit 0
    fi
  fi
  cp -f ${TOOL} ${TOOL}.tmp

  # remove existing capabilities flags
  sed -r -i -e 's/--offload-arch=gfx[0-9a-f]+//g' ${TOOL}.tmp

  # set supported capabilities found on this host
  for CAP in $(echo $CAPS | tr ' ,' '\n\n' | sort -u); do
    FLAG_VALUES+=("--offload-arch=${CAP}")
  done
fi

if [ ! -z "${FLAG_VALUES}" ]; then
  # add the new flags
  for ((i = 0; i < ${#FLAG_VALUES[@]}; i++)) ; do
    sed -i -e "s#</client>#</client>\n  <flags ${TOOL_FLAG}=\"${FLAG_VALUES[$i]}\"/>#" ${TOOL}.tmp
  done

  # remove empty tool flags lines
  sed -r -i -e "/ ${TOOL_FLAG}=\" *\"/d" ${TOOL}.tmp
fi

if [ $(diff -w ${TOOL}.tmp ${TOOL} | wc -l) -gt 0 ] ; then
  mv ${TOOL}.tmp ${TOOL}
  scram setup ${backend} >/dev/null 2>&1
  echo -n "Compute capabilities for ${backend} are "
  if [ "${CAPS}" = "reset" ] ; then
    echo "reset."
  else
    echo "set to ${CAPS}"
  fi
  echo "${backend} tool has been updated. It is recommanded to re-build all packages which requires ${backend}."
  echo "You can run \`scram build checkdeps\` once to checkout all packages which depend on ${backend}."
else
  [ -f .SCRAM/${SCRAM_ARCH}/tools/${backend} ] && touch .SCRAM/${SCRAM_ARCH}/tools/${backend}
  rm -f ${TOOL}.tmp
  echo "No change, compute capabilities for ${backend} are already set."
fi
