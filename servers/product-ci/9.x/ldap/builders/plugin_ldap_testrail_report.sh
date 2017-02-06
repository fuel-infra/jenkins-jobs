#!/bin/bash

set -ex

export TESTRAIL_USER=${TESTRAIL_USER}
export TESTRAIL_PASSWORD=${TESTRAIL_PASSWORD}
export TESTRAIL_REPORTER_PATH="report"
export TESTRAIL_PROJECT="Mirantis OpenStack"
export TESTRAIL_URL="https://mirantis.testrail.com"

# creating env for testrail reporter
rm -rf "${VENV_PATH}"
virtualenv "${VENV_PATH}"
source "${VENV_PATH}"/bin/activate
  pip install -U pip
  # NEED FIX! (move scripts from custom repo to Mirantis repo)
  pip install git+https://github.com/gdyuldin/testrail_reporter.git@stable
  wget "$PLUGIN_TEST_URL"/artifact/custom_tests/report.xml
  SNAPSHOT_ID=$(echo "$CUSTOM_VERSION" | awk '{print $2}')

  case "$PLUGIN_CONFIG" in
      mld_proxy)
          ENV_DESCRIPTION="Fuel_LDAP_plugin_with_proxy"
          ;;
      mld_no_proxy)
          ENV_DESCRIPTION="Fuel_LDAP_plugin_without_proxy"
          ;;
      *)
          ENV_DESCRIPTION="Fuel_LDAP_plugin_unknown_config"
  esac

  TEST_RUN_TIMESTAMP=$(date -d @"$SNAPSHOT_TIMESTAMP" "+%m/%d/%Y %T")

  "$TESTRAIL_REPORTER_PATH" -v \
  --testrail-plan-name "LDAP plugin 3.0.0 $SNAPSHOT_ID $TEST_RUN_TIMESTAMP" \
  --env-description "$ENV_DESCRIPTION" \
  --testrail-url  "$TESTRAIL_URL" \
  --testrail-user  "$TESTRAIL_USER" \
  --testrail-password "$TESTRAIL_PASSWORD" \
  --testrail-project "$TESTRAIL_PROJECT" \
  --testrail-milestone "$TESTRAIL_MILESTONE" \
  --testrail-suite "$TESTRAIL_SUITE" \
  --test-results-link "$PLUGIN_TEST_URL" \
  report.xml
deactivate
