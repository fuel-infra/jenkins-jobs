#!/bin/bash

set -ex

VENV=${VENV:=${WORKSPACE}_VENV} # To be able to test on local env

virtualenv ${VENV}
source ${VENV}/bin/activate || exit 1

pip install -r ${WORKSPACE}/fuelweb_test/requirements.txt
pip install -r ${WORKSPACE}/doc/requirements.txt

ERRORS=0
WARNS=0
MISSING_MODULES_COUNT=0

PREV_ERRORS=0
PREV_WARNS=0
PREV_MISSING_MODULES_COUNT=0

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

# Count Warnings and Errors for later usage
PREV_ERRORS=$(grep -c ERROR ${LOG_FILE} || true)
PREV_WARNS=$(grep -c WARNING ${LOG_FILE} || true)

# Check if all python modules from ./fuelweb_test are currently described in ./doc/*.rst files
cd ${WORKSPACE}
PREV_MODULES=$(find fuelweb_test system_test -name *.py -not -name __init__.py | sed -e 's|/|.|g' | sed -e 's/.py$//g')
PREV_MISSING_MODULES=$(for module in $PREV_MODULES; do if ! egrep -q -r "$module$" ./doc ; then echo $module; fi; done)
if [ -n "$PREV_MISSING_MODULES" ]; then
    PREV_MISSING_MODULES_COUNT=$(echo "$PREV_MISSING_MODULES"|wc -l)
else
    PREV_MISSING_MODULES_COUNT=0
fi

echo Number of Errors in previous commit: ${PREV_ERRORS}
echo Number of Warnings in previous commit: ${PREV_WARNS}
echo Number of Undocumented modules in previous commit: ${PREV_MISSING_MODULES_COUNT}

# Now build with the latest commit
git checkout ${GITHEAD}

# Invoke build function
build

if [[ ! -d doc/_build/html ]]; then
    echo Error: missing essential build directories.
    exit 1
fi

ERRORS=$(grep -c ERROR ${LOG_FILE} || true)
WARNS=$(grep -c WARNING ${LOG_FILE} || true)

# Check if all python modules from ./fuelweb_test are described in ./doc/*.rst files
cd ${WORKSPACE}
MODULES=$(find fuelweb_test -name *.py -not -name __init__.py | sed -e 's|/|.|g' | sed -e 's/.py$//g')
MISSING_MODULES=$(for module in $MODULES; do if ! egrep -q -r "$module$" ./doc ; then echo $module; fi; done)
if [ -n "$MISSING_MODULES" ]; then
    MISSING_MODULES_COUNT=$(echo "$MISSING_MODULES"|wc -l)
else
    MISSING_MODULES_COUNT=0
fi

echo Number of current commit Errors: ${ERRORS}
echo Number of current commit Warnings: ${WARNS}
echo Number of undocumented modules in current commit: ${MISSING_MODULES_COUNT}

if [[ ${ERRORS} -gt ${PREV_ERRORS} || ${WARNS} -gt ${PREV_WARNS} ]]; then
    echo "If number of Warnings or Errors has increased compared to previous commit: fail the job's build"
    exit 1
fi

if [[ ${MISSING_MODULES_COUNT} -gt ${PREV_MISSING_MODULES_COUNT} ]]; then
    echo The following modules are not described in documentation files ./doc/:
    echo $MISSING_MODULES
    exit 1
fi

exit 0
