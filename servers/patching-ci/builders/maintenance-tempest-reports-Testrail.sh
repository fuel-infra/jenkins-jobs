#!/bin/bash -ex

# Input:
# REPORT_FILE=xml report file name
# TESTRAIL_PLAN_NAME=name of testplan on testrail (Tempest MU8 05-32-2017)
# TEST_GROUP=tempest configuration group
# TESTRAIL_PROJECT=testrail project (Mirantis OpenStack)
# TESTRAIL_SUITE=testrail suite (Tempest 7.0)
# MILESTONE=7.0
# SPECIFICATION=snapshot for describe env in testrail
# ADD_TIMESTAMP=need add timestamp to plan name
# USE_TEMPLATE=use testrail report template or not

if [ ! -f "${REPORT_FILE?}" ]; then
    echo "Can't find \"${REPORT_FILE}\" report file"
    exit 1
fi

TESTRAIL_SUITE=${TESTRAIL_SUITE:-"Tempest ${MILESTONE}"}
SEND_SKIPPED=${SEND_SKIPPED:-false}
USE_TEMPLATE=${USE_TEMPLATE:-false}

if [[ "${ADD_TIMESTAMP}" == "true" ]]; then
    TESTRAIL_PLAN_NAME+="-$(date +%Y/%m/%d)"
fi

ARGS=()
if [[ "${USE_TEMPLATE}" == "true" ]]; then
    ARGS+=(--testrail-name-template '{custom_test_group}.{title}' --xunit-name-template '{classname}.{methodname}')
fi

if [ -n "${TEST_GROUP}" ]; then
    SPECIFICATION="${SPECIFICATION?}-${TEST_GROUP?}"
fi

if [ -z "${TEST_BUILD_URL}" ]; then
    TEST_BUILD_URL="${BUILD_URL}"
fi

if [ "${SEND_SKIPPED}" == "true" ]; then
    ARGS+=(--send-skipped)
fi

if [ ! -f report-venv/bin/activate ]; then
    rm -rf report-venv
    virtualenv report-venv
    source report-venv/bin/activate
    pip install -U pip setuptools six # six need for workaround setup.py below
    python setup.py install
else
    source report-venv/bin/activate
fi

report -v --testrail-plan-name "${TESTRAIL_PLAN_NAME?}" \
          --env-description "${SPECIFICATION?}"\
          --testrail-user "${TESTRAIL_USER?}" \
          --testrail-password "${TESTRAIL_PASSWORD?}" \
          --testrail-project "${TESTRAIL_PROJECT?}" \
          --testrail-milestone "${MILESTONE?}" \
          --testrail-suite "${TESTRAIL_SUITE?}" \
          --test-results-link "${TEST_BUILD_URL}"\
          "${ARGS[@]}" \
          "${REPORT_FILE?}"

deactivate

if [ -f "${REPORT_FILE}" ]; then
    mv -f "${REPORT_FILE}" "${REPORT_FILE}.reported"
fi
