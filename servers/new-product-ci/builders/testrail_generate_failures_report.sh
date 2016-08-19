#!/bin/bash
#
#   :mod:`testrail_generate_failures_report` -- script for failures report
#   ==========================================
#
#   .. module:: testrail_generate_failures_report
#       :platform: Unix
#       :synopsis: script generates swarm tests failures report
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: Serhii Boikov <sboykov@mirantis.com>
#
#   .. envvar::
#       :var  BUILD_ID: Id of Jenkins build under which this
#                       script is running, defaults to ``0``
#       :type BUILD_ID: int
#       :var  WORKSPACE: Location where build is started, defaults to ``.``
#       :type WORKSPACE: path
#       :var  HTML_REPORT: Name of the file where report will be stored
#       :type HTML_REPORT: string
#       :var  JENKINS_URL: URL of current Jenkins master it's used by
#                          "${TESTRAIL_FAILURE_REPORTER}"
#       :type JENKINS_URL: string
#       :var  TESTRAIL_MILESTONE: Testrail milestone ID
#       :type TESTRAIL_MILESTONE: int
#       :var  LAUNCHPAD_MILESTONE: Launchpad milestone ID
#       :type LAUNCHPAD_MILESTONE: int
#       :var  TESTRAIL_PROJECT: Name of project at testrail
#       :type TESTRAIL_PROJECT: string
#       :var  TESTRAIL_URL: Testrail URL it is used by
#                           "${TESTRAIL_FAILURE_REPORTER}"
#       :type TESTRAIL_URL: string
#       :var  VENV_PATH: Path to the python VENV that should be used by job
#       :type VENV_PATH: path
#       :var  BUILD_URL: The URL where the results of jenkins build
#                        can be found
#                        (e.g. http://buildserver/jenkins/job/MyJobName/666/)
#       :type BUILD_URL: string
#
#
#   .. affects::
#       :file "${HTML_REPORT}": store failed swarm tests
#
#
#   .. seealso:: https://mirantis.jira.com/browse/QA-2677

set -ex

BUILD_ID="${BUILD_ID:-0}"
WORKSPACE="${WORKSPACE:-.}"

# Prepare venv
source "${VENV_PATH:-/home/jenkins/venv-nailgun-tests-2.9/bin/activate}"
export PYTHONPATH="$(pwd):$PYTHONPATH"

# Initialize variables
export TESTRAIL_FAILURE_REPORTER="fuelweb_test/testrail/generate_failure_group_statistics.py"

python "${TESTRAIL_FAILURE_REPORTER}" -f html -o "${HTML_REPORT}" -j "${TEST_RUNNER_JOB_NAME}"

echo "description string: <iframe frameborder='0' scrolling='yes'" \
    "style='display:block; width:100%; height:150vh;'" \
    "src='${BUILD_URL}/artifact/${HTML_REPORT}'>" \
    "</iframe>"
