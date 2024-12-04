#!/bin/bash
[ $(uname -m) = "x86_64" ] || exit 0
[ "${SCRAM}" != "" ] || SCRAM=scram
PSABI_ARCH_PREFIX="x86-64-v"
PSABI_ARCHS=$(ld.so --help | grep -E " ${PSABI_ARCH_PREFIX}[0-9]+ " | grep -i supported | sed 's|^ *||;s| .*||' | tr '\n' ' ')
MULTIARCH_TARGET=$(grep '"SCRAM_TARGET"' ${LOCALTOP}/config/Self.xml | grep ' value=' | sed 's|^ .*value="||;s|".*||')
SCRAM_DEFAULT_MICROARCH=$(grep '"SCRAM_DEFAULT_MICROARCH"' ${LOCALTOP}/config/Self.xml | grep ' value=' | sed 's|^ .*value="||;s|".*||')
SCRAM_TARGETS=$(grep 'SCRAM_TARGETS="' ${LOCALTOP}/config/Self.xml | sed 's|^.*SCRAM_TARGETS="||;s|".*||')
SCRAM_ALL_MICROARCHS=$(echo ${SCRAM_DEFAULT_MICROARCH} ${SCRAM_TARGETS} | tr ' ' '\n' | grep "${PSABI_ARCH_PREFIX}" | sort | uniq | tr '\n' ' ')
