#!/bin/bash

set -o xtrace
set -o errexit
set -o pipefail

rm -f properties-*
for x in ${PACKAGE_LIST}
do
    package=$(echo "${x}" | awk -F @ '{print $1}')
    propfile="properties-${package}"
    echo "PACKAGENAME=${package}" > "${propfile}"
    ref=$(echo "${x}" | awk -F @ '{print $2}')
    [[ ${ref} ]] && echo "SPECBRANCH=${ref}" >> "${propfile}" ||:
done
