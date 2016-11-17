#!/bin/bash
#
#   :mod:`vote-merge-commits.sh` -- Submit ready-to-merge merge-commits
#   ==========================================
#
#   .. module:: vote-merge-commits.sh
#       :platform: Unix
#       :synopsis: Submit ready-to-merge merge-commits
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: Alexander Evseev <aevseev@mirantis.com>
#
#
#   This script searches for merge-commits having Verified+1 from packaging CI,
#   and votes Code-Review+2, Workflow+1. Packaging CI is triggered for merge
#   by W+1, and non-author core review is required by Gerrit policies for
#   OpenStack projects.
#
#
#   .. envvar::
#       :var  GERRIT_HOST: Hostname of IP address of Gerrit instance
#       :type GERRIT_HOST: string
#       :var  GERRIT_PORT: TCP port for SSH connection to Gerrit instance
#       :type GERRIT_PORT: int
#       :var  GERRIT_USER: Username for Gerrit
#       :type GERRIT_USER: string
#       :var  GIT_BRANCH: Vote only for changes from given branch
#       :type GIT_BRANCH: string
#
#
#   .. requirements::
#
#       * SSH connection to GERRIT_HOST:GERRIT_PORT as GERRIT_USER
#       * Vote permissions in Gerrit for user GERRIT_USER
#
#
#   .. entrypoint:: main
#
#
#   .. seealso:: https://mirantis.jira.com/browse/PROD-8262

set -ex
set -o pipefail

# Check gerrit parameters. Fail if GERRIT_HOST and GERRIT_USER is unset.
: "${GERRIT_HOST?}"
: "${GERRIT_PORT:=29418}"
: "${GERRIT_USER?}"

# Gerrit query includes:
#   change owner  - owner:openstack-ci-mirrorer-jenkins
#   change status - status:open
#   topic         - topic:^sync/stable/.+
#   specific vote - label:Verified+1,user=pkgs-ci
GERRIT_QUERY='owner:openstack-ci-mirrorer-jenkins status:open topic:^sync/stable/.+ label:Verified+1,user=pkgs-ci'

# Append branch filter if GIT_BRANCH is given
if [ -n "${GIT_BRANCH}" ]; then
    GERRIT_QUERY+=" branch:${GIT_BRANCH}"
fi

# Gerrit command wrapper
GERRIT_CMD="ssh -p ${GERRIT_PORT} ${GERRIT_USER}@${GERRIT_HOST} -- gerrit"

# Disable warning:
#   SC2086: Double quote to prevent globbing and word splitting.
# shellcheck disable=2086
main () {
    #   .. function:: main
    #
    #       Searches for merge-commits having V+1 from packaging CI, and votes
    #       for it CR+2 and W+1
    #
    #       :stdin: not used
    #       :stdout: useful debug information
    #       :stderr: not used
    #

    ${GERRIT_CMD} query --current-patch-set ${GERRIT_QUERY} \
    | awk '$1 == "ref:" {split($2,a,/\//); printf "%d,%d\n", a[4], a[5]}' \
    | xargs -I% ${GERRIT_CMD} review --code-review 2 --workflow 1 %
}

if [ "$0" == "${BASH_SOURCE}" ] ; then
    main "${@}"
fi
