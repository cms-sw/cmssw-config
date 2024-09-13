#!/bin/bash -e
backend=$(echo $1 | cut -d- -f2)
req_type=$(echo $1 | cut -d- -f1)
config_changed=false
SELF_TOOL=${LOCALTOP}/config/Self.xml
ALL_BACKENDS=$(grep ALPAKA_BACKENDS= ${SELF_TOOL} | sed 's|.*=.||;s|".*||')
if [ "${req_type}" = "enable" ]; then
  if [ $(echo " $ALL_BACKENDS " | grep " ${backend} " | wc -l) -gt 0 ] ; then
    echo "Alpaka backend ${backend} already enabled."
    exit 0
  else
    sed -i -e "s|ALPAKA_BACKENDS=\"|ALPAKA_BACKENDS=\"${backend} |" ${SELF_TOOL}
    config_changed=true
  fi
elif [ "${req_type}" = "disable" ]; then
  if [ $(echo " $ALL_BACKENDS " | grep " ${backend} " | wc -l) -eq 0 ] ; then
    echo "Alpaka backend ${backend} already disabled."
    exit 0
  else
    SEL_BACKEND=$(echo ${ALL_BACKENDS} | tr ' ' '\n' | grep -v "${backend}" | tr '\n' ' ' | sed 's| *$||')
    sed -i -e "s|ALPAKA_BACKENDS=.*\"|ALPAKA_BACKENDS=\"${SEL_BACKEND}\"|" ${SELF_TOOL}
    config_changed=true
  fi
fi
if $self_updated ; then
  scram setup self        >/dev/null 2>&1
  scram build -r echo_CXX >/dev/null 2>&1
  echo "Alpaka backend ${backend} is ${req_type}."
fi
