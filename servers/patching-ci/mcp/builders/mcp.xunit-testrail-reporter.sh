#!/bin/bash -ex

if [ ! -f "${REPORT_FILE?}" ]; then
    echo "Can't find \"${REPORT_FILE}\" report file"
    exit 1
fi

ARGS=()
if [ -n "${TESTRAIL_NAME_TEMPLATE}" ]; then
    ARGS+=(--testrail-name-template "${TESTRAIL_NAME_TEMPLATE}")
fi

if [ -n "${XUNIT_NAME_TEMPLATE}" ]; then
    ARGS+=(--xunit-name-template "${XUNIT_NAME_TEMPLATE}")
fi

if [ -z "${TEST_BUILD_URL}" ]; then
    TEST_BUILD_URL="${BUILD_URL}"
fi

if [ "${SEND_SKIPPED}" == true ]; then
    ARGS+=(--send-skipped)
fi

if [ ! -f report-venv/bin/activate ]; then
    rm -rf report-venv
    virtualenv report-venv
    source report-venv/bin/activate
    pip install -U pip
else
    source report-venv/bin/activate
fi

pip install -U git+https://github.com/gdyuldin/testrail_reporter

report -v --testrail-plan-name "${TESTRAIL_PLAN_NAME?}" \
          --env-description "${ENV_DESCRIPTION?}"\
          --testrail-user "${TESTRAIL_USER?}" \
          --testrail-password "${TESTRAIL_PASSWORD?}" \
          --testrail-project "${TESTRAIL_PROJECT?}" \
          --testrail-milestone "${TESTRAIL_MILESTONE?}" \
          --testrail-suite "${TESTRAIL_SUITE?}" \
          --test-results-link "${TEST_BUILD_URL}"\
          "${ARGS[@]}" \
          "${REPORT_FILE?}"

deactivate
