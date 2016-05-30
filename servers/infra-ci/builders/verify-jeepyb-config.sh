#!/bin/bash
#
#   :mod:`verify-jeepyb-config` -- Script to test config file
#   ============================================================
#
#   .. module:: verify-jeepyb-config
#       :platform: Unix
#       :synopsis: Check syntax of projects.yaml file located
#                  in jeepyb-config repository
#   .. vesionadded:: MOS-10.0
#   .. vesionchanged:: MOS-10.0
#   .. author:: Dmitry Burmistrov <dburmistrov@mirantis.com>
#               Artur Mihura <amihura@mirantis.com>
#
#
#   This script is created so as to:
#     * Check syntax and sorting of projects.yaml file in jeepyb-config repo
#     * Get detailed output if syntax of projects.yaml is not correct
#
#
#   .. envvar::
#       :var  SRC: File to test
#       :type SRC: string
#       :var  RPM_HOST: Ubuntu related project names
#       :type RPM_HOST: url
#       :var  DEB_HOST: Centos related project names
#       :type DEB_HOST: url
#       :var  NEW_PROJECTS: The name of added projects
#       :type NEW_PROJECTS: string
#       :var  SYNTAX_FAILED: Shows incorrect syntax
#       :type SYNTAX_FAILED: string
#       :var  SORTING_FAILED: Shows incorrect sorting
#       :type SORTING_FAILED: string
#       :var  GERRIT_MESSAGE: Message from gerrit
#       :type GERRIT_MESSAGE: string
#       :var  GERRIT_CMD: gerrit command to run
#       :type GERRIT_CMD: string
#
#
#   .. requirements::
#
#       * ``diff`` in ``/usr/bin/diff``
#       * ``wget`` in ``/usr/bin/wget``
#       * ``git`` in ``/usr/bin/git``
#       * ``grep`` in ``/bin/grep``
#       * ``ssh`` in ``/usr/bin/ssh``
#       * ``sort`` in ``/usr/bin/sort``
#
#
#   .. seealso:: https://bugs.launchpad.net/fuel/+bug/1496072
#   .. warnings:: never use on productions for test purposes

set -ex

SRC="projects.yaml"
RPM_HOST="http://kojipkgs.fedoraproject.org/packages"
DEB_HOST="https://launchpad.net/ubuntu/+source"

# Verify new projects against upsteam
NEW_PROJECTS=$(git show projects.yaml | fgrep "project: " | grep "^+" | awk '{print $NF}')
unset CENTOS_FAILED
unset UBUNTU_FAILED
for prj in ${NEW_PROJECTS}; do
    case $(echo "${prj}" | egrep -o '(centos|trusty)') in
        centos)
            wget -qO /dev/null "${RPM_HOST}/${prj##*/}" \
                || CENTOS_FAILED="${CENTOS_FAILED} ${prj}"
            ;;
        trusty)
            wget -qO /dev/null "${DEB_HOST}/${prj##*/}" \
                || UBUNTU_FAILED="${UBUNTU_FAILED} ${prj}"
            ;;
    esac
done

# Check syntax
unset SYNTAX_FAILED
SYNTAX_FAILED=$( grep -v \
    -e '^$' \
    -e '^-' \
    -e '^  project:' \
    -e '^  description:' \
    -e '^  acl-config:' \
    -e '^  upstream:' \
    projects.yaml || :)

# Check sorting
unset SORTING_FAILED
[ -f "${SRC}" ] \
  && SORTING_FAILED=$(diff -u <(grep project: "${SRC}") <(grep project: "${SRC}" | LANG=C sort) || :)

unset GERRIT_MESSAGE

if [ -n "$SYNTAX_FAILED" ] ; then
    GERRIT_MESSAGE=${GERRIT_MESSAGE}"
* Syntax error:
${SYNTAX_FAILED}"
fi

if [ -n "$SORTING_FAILED" ] ; then
    GERRIT_MESSAGE=${GERRIT_MESSAGE}"
* Sorting order: FAILED"
else
    GERRIT_MESSAGE=${GERRIT_MESSAGE}"
* Sorting order: OK"
fi

if [ -n "$UBUNTU_FAILED" ] ; then
    GERRIT_MESSAGE=${GERRIT_MESSAGE}"
* Ubuntu source name: FAILED
Cannot find requested packages at https://launchpad.net
Nonexistent packages: ${UBUNTU_FAILED}"
fi

if [ -n "$CENTOS_FAILED" ] ; then
    GERRIT_MESSAGE=${GERRIT_MESSAGE}"
* CentOS source name: FAILED
Cannot find requested packages at http://koji.fedoraproject.org
Nonexistent packages: ${CENTOS_FAILED}"
fi

if [ "$GERRIT_MESSAGE" != "" ] ; then
    GERRIT_CMD=gerrit\ review\ $GERRIT_CHANGE_NUMBER,$GERRIT_PATCHSET_NUMBER\ \'--message="$GERRIT_MESSAGE"\'
    ssh -p "${GERRIT_PORT}" "${GERRIT_USER}@${GERRIT_HOST}" \'"${GERRIT_CMD}"\'
fi

exit 0
