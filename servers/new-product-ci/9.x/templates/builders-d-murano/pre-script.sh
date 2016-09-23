#!/bin/bash

echo "INFO: Plugin PRE-BUILD SCRIPT"
set -ex
# needed for plugin-deploy-test.sh
#  Since plugin-deploy-test.sh tries to copy plugin from
#  build job by PATH PLUGIN_FILE_PATH, we need to hook-up this behaviour
inject PLUGIN_ENV_PATH_NAME 'MURANO_PLUGIN_PATH'
if [[ ! -n "$RPM_PACKAGES_URLS" ]]; then
    # Inject PLUGIN_FILE for test-runner with filename rendered from guess_rpm_filename()
    # Inject RPM_PACKAGES_URLS for test-runner, with file url rendered from snaphot
    inject PLUGIN_FILE "${PLUGIN_RPM_FILENAME_FROM_REPO}"
    inject RPM_PACKAGES_URLS "http://${MIRROR_HOST}/${PLUGIN_REPO_SUB_URL}/${PLUGIN_VERSION}/centos/${PLUGIN_MOS_VERSION}-${PLUGIN_PKG_DIST}/snapshots/${PLUGIN_OS_REPO_ID}/x86_64/Packages/${PLUGIN_RPM_FILENAME_FROM_REPO}"
fi

# update plugin storage dir
inject PLUGINS "${WORKSPACE}/${PLUGIN_TEST_REPO}/plugins_data"
inject PLUGIN_FRAMEWORK_WORKSPACE "${PLUGIN_TEST_REPO}"

# Link logs directory, to be able fetch them with usual publishers
ln -fs "${PLUGIN_TEST_REPO}/logs" .

# Move venv to /tmp, due PATH lenght limit. See: https://github.com/pypa/pip/issues/1773
VENV_PATH=$(mktemp -d)
inject VENV_PATH "${VENV_PATH}"

# Run prepare script itself
bash -x "${PLUGIN_TEST_REPO}/utils/fuel-qa-builder/prepare_env.sh"
