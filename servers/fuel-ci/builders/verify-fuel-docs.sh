#!/bin/bash

set -ex

ERRORS=0
WARNS=0
LOG_FILE=${WORKSPACE}/output/make.log

mkdir -p ${WORKSPACE}/output

make clean html pdf 2>&1 1>/dev/null | awk '!/image\.py.*rescaling/ && !/\/pdf\/pdf_.*rst/ && /WARNING/i {print $x}' | tee ${LOG_FILE}

if [[ ! -d _build/pdf || ! -d _build/html ]]; then
    echo Error: mising essential build directories.
    exit 1
fi

# Count Errors and Warnings.
ERRORS=$(grep -ic ERROR ${LOG_FILE} || true)
WARNS=$(grep -ic WARNING ${LOG_FILE} || true)

echo Number of build Warnings: ${WARNS}
echo Number of build Errors: ${ERRORS}

if [[ ${ERRORS} -gt 0 ]]; then
    exit 1
fi

# copy pdf for publishing build results
cp -r _build/pdf _build/html

exit 0
