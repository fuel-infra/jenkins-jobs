#!/bin/bash
set -ex

[[ "${UPDATES}" == "true" ]] && export UPDATES_SUFFIX="-updates"

# Change '|||' to ',' as separate in license_compliance file compliance csv format
# Combine and upload report
case ${PROJECT_NAME} in
    "mos")
     DISTRS="ubuntu centos"
     ;;
     "mcp")
     DISTRS="ubuntu"
     ;;
esac
for DISTR in ${DISTRS}; do
    sed -e 's/|||/,/g' "license_${PROJECT_NAME}_${RELEASE}${UPDATES_SUFFIX}_${DISTR}" > "license_${PROJECT_NAME}_${RELEASE}${UPDATES_SUFFIX}_${DISTR}.csv"
    python license-compliance/extract.py "${DISTR}${RELEASE}${UPDATES_SUFFIX}.csv" "license_${PROJECT_NAME}_${RELEASE}${UPDATES_SUFFIX}_${DISTR}.csv" "enc_lic_${DISTR}_output_${RELEASE}${UPDATES_SUFFIX}.csv" "${KEYPATH}"
done
