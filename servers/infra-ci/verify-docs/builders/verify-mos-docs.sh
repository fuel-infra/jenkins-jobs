#!/bin/bash

set -ex

VENV=${WORKSPACE}_VENV

virtualenv --clear "${VENV}"
source "${VENV}/bin/activate" || exit 1

pip install -r requirements.txt


ERRORS=0
WARNS=0
PREV_WARNS=0
LOG_FILE=${WORKSPACE}/output/make.log
GITHEAD=$(git rev-parse HEAD)

function build {
# shellcheck disable=SC2069
    make clean html pdf 2>&1 1>/dev/null | awk '!/image\.py.*rescaling/ && !/\/pdf\/pdf_.*rst/ && /WARNING/i {print $x}' | tee "${LOG_FILE}"
}

mkdir -p "${WORKSPACE}/output"

# First count warnings from previous commit
git checkout HEAD~1

# Invoke build function
build

# Count only Warnings for later usage
PREV_WARNS=$(grep -ic WARNING "${LOG_FILE}" || true)
echo Number of Warnings in previous commit: "${PREV_WARNS}"

# Now build with the latest commit
git checkout "${GITHEAD}"

# Invoke build function
build

if [[ ! -d _build/pdf || ! -d _build/html ]]; then
    echo Error: missing essential build directories.
    exit 1
fi

ERRORS=$(grep -ic ERROR "${LOG_FILE}" || true)
WARNS=$(grep -ic WARNING "${LOG_FILE}" || true)

echo Number of build Warnings: "${WARNS}"
echo Number of build Errors: "${ERRORS}"
echo "Description string: Warnings ${WARNS} Errors ${ERRORS}"

# If there was at least one error or number of Warnings has increased compared to previous commit: fail the job's build
if [[ ${ERRORS} -gt 0 || ${WARNS} -gt ${PREV_WARNS} ]]; then
    exit 1
fi

# copy pdf for publishing build results
cp -r _build/pdf _build/html

exit 0
