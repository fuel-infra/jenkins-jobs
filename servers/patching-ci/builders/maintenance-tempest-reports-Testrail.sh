#!/bin/bash -ex

REPORT_XML="${REPORT_PREFIX}/${ENV_NAME}_${SNAPSHOT}/${REPORT_FILE}"

export TESTRAIL_PROJECT=${TESTRAIL_PROJECT:-'Mirantis OpenStack'}
export TESTRAIL_TEST_SUITE=${TESTRAIL_TEST_SUITE:-"Tempest ${MILESTONE}"}
export JENKINS_URL=${JENKINS_URL:-https://patching-ci.infra.mirantis.net/}

if [ ! -f "$REPORT_XML" ]; then
    echo "Can't find $REPORT_XML file"
    exit 1
fi

# if we need to change SUITE
if [ -n "$SUITE" ]; then
    TESTRAIL_SUITE="${SUITE}"
fi

# if we need to change MILESTONE
if [ -n "${MILESTONE}" ]; then
    TESTRAIL_MILESTONE="${MILESTONE}"
fi

if ${ADD_TIMESTAMP}; then
    TESTRAIL_PLAN_NAME+="-$(date +%Y/%m/%d)"
fi

TEMPLATE=()
if ${USE_TEMPLATE}; then
    TEMPLATE=(--testrail-name-template '{custom_test_group}.{title}' --xunit-name-template '{classname}.{methodname}')
fi

virtualenv report-venv
source report-venv/bin/activate
pip install -U pip setuptools
python setup.py install
report -v --testrail-plan-name "$TESTRAIL_PLAN_NAME" \
          --env-description "$SNAPSHOT-$TEST_GROUP" \
          --testrail-user  "${TESTRAIL_USER}" \
          --testrail-password "${TESTRAIL_PASSWORD}" \
          --testrail-project "${TESTRAIL_PROJECT}" \
          --testrail-milestone "${TESTRAIL_MILESTONE}" \
          --testrail-suite "${TESTRAIL_SUITE}" \
          --test-results-link "$BUILD" "$REPORT_XML" \
          "${TEMPLATE[@]}"

deactivate
rm -rf report-venv
