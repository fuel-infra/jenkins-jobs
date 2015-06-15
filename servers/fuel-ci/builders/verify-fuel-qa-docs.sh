#!/bin/bash

set -ex

VENV=${WORKSPACE}_VENV

virtualenv ${VENV}
source ${VENV}/bin/activate || exit 1

pip install -r ${WORKSPACE}/fuelweb_test/requirements.txt
pip install -r ${WORKSPACE}/doc/requirements.txt

ERRORS=0
WARNS=0
PREV_WARNS=0
LOG_FILE=${WORKSPACE}/doc/output/make.log
GITHEAD=$(git rev-parse HEAD)

function build {
    (cd ${WORKSPACE}/doc; make doc-html 2>&1 1>/dev/null | awk '!/is deprecated/ && !/in <module>/ && !/import/ && !/ImportError/ && !/Traceback \(most/ {print $x}' | tee ${LOG_FILE})
}

mkdir -p ${WORKSPACE}/doc/output

# First count warnings from previous commit
git checkout HEAD~1

# Invoke build function
build

# Count only Warnings for later usage
PREV_ERRORS=$(grep -c Error ${LOG_FILE} || true)
PREV_WARNS=$(grep -ic WARNING ${LOG_FILE} || true)

echo Number of Errors in previous commit: ${PREV_WARNS}
echo Number of Warnings in previous commit: ${PREV_WARNS}

# Now build with the latest commit
git checkout ${GITHEAD}

# Invoke build function
build

if [[ ! -d doc/_build/html ]]; then
    echo Error: missing essential build directories.
    exit 1
fi

ERRORS=$(grep -ic ERROR ${LOG_FILE} || true)
WARNS=$(grep -ic WARNING ${LOG_FILE} || true)

echo Number of build Warnings: ${WARNS}
echo Number of build Errors: ${ERRORS}

# If number of Warnings or Errors has increased compared to previous commit: fail the job's build
if [[ ${ERRORS} -gt ${PREV_ERRORS} || ${WARNS} -gt ${PREV_WARNS} ]]; then
    exit 1
fi

exit 0
