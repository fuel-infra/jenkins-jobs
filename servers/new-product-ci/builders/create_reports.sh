#!/bin/bash -ex

[[ "${UPDATES}" == "true" ]] && export UPDATES_SUFFIX="-updates"

# Change '|||' to ',' as separate in license_compliance file compliance csv format
# Combine and upload report
for DISTR in centos ubuntu; do
    sed -e 's/|||/,/g' "license_mos_${RELEASE}${UPDATES_SUFFIX}_${DISTR}" > "license_mos_${RELEASE}${UPDATES_SUFFIX}_${DISTR}.csv"
    python license-compliance/extract.py "${DISTR}${RELEASE}${UPDATES_SUFFIX}.csv" "license_mos_${RELEASE}${UPDATES_SUFFIX}_${DISTR}.csv" "enc_lic_${DISTR}_output_${RELEASE}${UPDATES_SUFFIX}.csv"
done
