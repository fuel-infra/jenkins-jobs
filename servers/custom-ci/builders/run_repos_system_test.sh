#!/bin/bash
#
#   :mod:`run_repos_system_test` -- Run system tests without Fuel ISO
#   =================================================================
#
#   .. module:: run_repos_system_test
#       :platform: Unix
#       :synopsis: Run system tests without Fuel ISO
#   .. versionadded:: MOS-10.0
#   .. versionchanged:: MOS-10.0
#   .. author:: Aliaksei Cherniakou <acherniakou@mirantis.com>
#
#   This script is implemented to run system tests without Fuel ISO and only
#   using YAML files with RPM and DEB repositories configuration.
#
#   It contains:
#       * description of the script itself
#       * description of required environment variables
#
#   .. envvar::
#       :var  BUILD_ID: Id of Jenkins build under which this
#                       script is running
#       :type BUILD_ID: int
#       :var  WORKSPACE: Location where build is started
#       :type WORKSPACE: path
#       :var  ENV_PREFIX: Name prefix for constructing
#                         devops environment name
#       :type ENV_PREFIX: string
#       :var  FUEL_RELEASE_URL: URL where fuel-release rpm package
#                               can be downloaded from. Can contain
#                               wildcards supported by wget.
#       :type FUEL_RELEASE_URL: URL
#       :var  FUEL_RELEASE_PATH: Path where fuel-release rpm package
#                                will be stored
#       :type FUEL_RELEASE_PATH: path
#       :var  RPM_REPOS_YAML: Path where provided by user YAML file
#                             with RPM repositories configuration is placed
#       :type RPM_REPOS_YAML: path
#       :var  DEB_REPOS_YAML: Path where provided by user YAML file
#                             with DEB repositories configuration is placed
#       :type DEB_REPOS_YAML: path
#       :var  fuel_qa_gerrit_commit: List of gerrit changes of fuel-qa to
#                                    cherry pick during job run
#       :type fuel_qa_gerrit_commit: space separated list
#
#   .. seealso:: https://mirantis.jira.com/browse/PROD-4824
#

set -ex

# Fail if there're no yaml files with repositories configuration provided by user
[ -f "${RPM_REPOS_YAML}" ]
[ -f "${DEB_REPOS_YAML}" ]

# Checking gerrit commits for fuel-qa
if [ "${fuel_qa_gerrit_commit}" != "none" ] ; then
  for commit in ${fuel_qa_gerrit_commit}; do
    git fetch origin "${commit}" && git cherry-pick FETCH_HEAD
  done
fi

FUEL_RELEASE_FILE_NAME=$(basename "${FUEL_RELEASE_URL}")

# shellcheck disable=SC2086
wget --no-parent \
    -r \
    -nd \
    -e robots=off \
    -A "${FUEL_RELEASE_FILE_NAME}" \
    "$(dirname "${FUEL_RELEASE_URL}")/" &&
  mv ${FUEL_RELEASE_FILE_NAME} "${FUEL_RELEASE_PATH}"

echo STARTED_TIME="$(date -u +'%Y-%m-%dT%H:%M:%S')" > ci_status_params.txt

rm -rf logs/*

ENV_NAME=${ENV_PREFIX}.${BUILD_NUMBER}.${BUILD_ID}
ENV_NAME=${ENV_NAME:0:68}
echo "export ENV_NAME=\"${ENV_NAME}\"" > "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

# There's no need in to run such tests but system_tests.sh script requires it,
# so creating the iso file to satisfy this requirement.
ISO_PATH="${WORKSPACE}/workaround.empty.iso"
echo "remove the line when iso argument becomes optional in fuel-devops" > "${ISO_PATH}"

export PATH_TO_CERT=${WORKSPACE}/${ENV_NAME}.crt
export PATH_TO_PEM=${WORKSPACE}/${ENV_NAME}.pem

sh -x "utils/jenkins/system_tests.sh" \
  -t test \
  -w "${WORKSPACE}" \
  -e "${ENV_NAME}" \
  -o --group="${TEST_GROUP}" \
  -i "${ISO_PATH}"
