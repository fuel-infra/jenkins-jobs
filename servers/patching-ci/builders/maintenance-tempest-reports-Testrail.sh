#!/bin/bash -ex

# Input:
# REPORT_FILE=xml report file name
# TESTRAIL_PLAN_NAME=name of testplan on testrail (Tempest MU8 05-32-2017)
# TEST_GROUP=tempest configuration group
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

if [[ "${ADD_TIMESTAMP}" == "true" ]]; then
    TESTRAIL_PLAN_NAME+="-$(date +%Y/%m/%d)"
fi

TEMPLATE=()
if [[ "${USE_TEMPLATE}" == "true" ]]; then
    TEMPLATE=(--testrail-name-template '{custom_test_group}.{title}' --xunit-name-template '{classname}.{methodname}')
fi

if [ ! -f report-venb/bin/activate ]; then
    rm -rf report-venv
    virtualenv report-venv
    source report-venv/bin/activate
    pip install -U pip setuptools six # six need for workaround setup.py below
    python setup.py install
else
    source report-venv/bin/activate
fi

report -v --testrail-plan-name "${TESTRAIL_PLAN_NAME?}" \
          --env-description "${SPECIFICATION?}-${TEST_GROUP?}" \
          --testrail-user "${TESTRAIL_USER?}" \
          --testrail-password "${TESTRAIL_PASSWORD?}" \
          --testrail-project "Mirantis OpenStack" \
          --testrail-milestone "${MILESTONE?}" \
          --testrail-suite "${TESTRAIL_SUITE?}" \
          --test-results-link "${BUILD_URL}"\
          "${TEMPLATE[@]}" \
          "${REPORT_FILE?}"

deactivate

if [ -f "${REPORT_FILE}" ]; then
    mv -f "${REPORT_FILE}" "${REPORT_FILE}.reported"
fi
