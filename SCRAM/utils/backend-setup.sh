#!/bin/bash -e
backend=$(echo $1 | cut -d- -f2 | cut -d: -f1)
req_type=$(echo $1 | cut -d- -f1)
CAPS=$(echo $1 | cut -d- -f2 | cut -d: -f2)
TOOL=config/toolbox/${SCRAM_ARCH}/tools/selected/${backend}.xml

if [ ! -e ${TOOL} ] ; then
  echo "Error: Unknown backend ${backend}" >&2
  exit 1
fi

if [ "${CAPS}" = "reset" ] ; then
  cp -f $CMSSW_RELEASE_BASE/${TOOL} ${TOOL}.tmp
elif [ "${backend}" = "cuda" ] ; then
  if [ "${CAPS}" = "native" ] ; then
    DOTS=$(cudaComputeCapabilities | awk '{ print $2 }' | sort -u)
    CAPS=$(echo $DOTS | sed -e 's#\.*##g')
    
    if [ "${CAPS}" = "" ] ; then
      echo "Warning: Unable to find cuda compute capabilities." >&2
      exit 0
    fi
  else
    CAPS=$(echo ${CAPS} | tr ',' '\n' | sed 's|^sm_||' | tr '\n' ' ' | sed 's| *$||')
  fi
  cp -f ${TOOL} ${TOOL}.tmp
  # remove existing capabilities
  sed -i -e "s# *-gencode arch=compute_..,code=sm_.. *# #g" ${TOOL}.tmp
  sed -i -e "s# *-gencode arch=compute_..,code=\[sm_..,compute_..\] *# #g" ${TOOL}.tmp

  # add support for the capabilities found on this machine
  for CAP in $CAPS; do
    sed -i -e "/flags CUDA_FLAGS=/s#=\"#=\"-gencode arch=compute_$CAP,code=[sm_$CAP,compute_$CAP] #" ${TOOL}.tmp
  done
  CAPS=$(echo $CAPS | tr ' ' '\n' | sed 's|^|sm_|' | tr '\n' ',' | sed 's|,$||')
elif [ "${backend}" = "rocm" ] ; then
  if [ "${CAPS}" = "native" ] ; then
    CAPS=$(rocmComputeCapabilities | awk '{ print $2 }' | sort -u)
    if [ "${CAPS}" = "" ] ; then
      echo "Warning: Unable to find rocm compute capabilities." >&2
      exit 0
    fi
  else
    CAPS=$(echo ${CAPS} | tr ',' ' ')
  fi
  cp -f ${TOOL} ${TOOL}.tmp
  #Remove existing capabilities flag
  sed -r -i -e '/flags ROCM_FLAGS=.*gfx[0-9a-f]+/d' ${TOOL}.tmp

  #add support for the capabilities found on this machine
  for CAP in $CAPS; do
    sed -i -e "s#</client>#</client>\n  <flags ROCM_FLAGS=\"--offload-arch=${CAP}\"/>#" ${TOOL}.tmp
  done
  CAPS=$(echo $CAPS | tr ' ' ',' | sed 's|,$||')
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
else
  [ -f .SCRAM/${SCRAM_ARCH}/tools/${backend} ] && touch .SCRAM/${SCRAM_ARCH}/tools/${backend}
  rm -f ${TOOL}.tmp
  echo "No change, compute capabilities for ${backend} are already set."
fi
