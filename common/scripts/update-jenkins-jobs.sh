#!/bin/bash
set -ex

tox -e "${CI_NAME}"

source ".tox/${CI_NAME}/bin/activate"

CONFIG_PATH="${WORKSPACE}/../tmp/${JOB_NAME}"
# JOBS_LIST - Jenkins string parameter. Space separated list of job names to update.
# Will update all jobs if empty. Example: verify-mos-docs docker-rebuild-fuel-ci
JOBS_LIST=(${JOBS_LIST})

umask 0077
mkdir -p "${CONFIG_PATH}"
cat > "${CONFIG_PATH}/jenkins_jobs.ini" << EOF
[jenkins]
user=${JJB_USER}
password=${JJB_PASS}
url=${JENKINS_URL}
query_plugins_info=False
[job_builder]
ignore_cache=True
recursive=True
EOF

jenkins-jobs --conf "${CONFIG_PATH}/jenkins_jobs.ini" update "common:servers/${CI_NAME}" "${JOBS_LIST[@]}"
