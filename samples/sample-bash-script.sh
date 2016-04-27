#!/bin/bash
#
#   :mod:`sample-bash-script` -- Sample script
#   ==========================================
#
#   .. module:: sample-bash-script
#       :platform: Unix, Windows
#       :synopsis: Do some useful and unuseful things
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: John Snow <jsnow@mirantis.com>
#
#
#   This is a sample module created for demonstration purposes
#   It contains:
#       * description for sample module
#       * description of required environment variables
#       * sample function and its description
#       * definition of sample setenvfile
#
#
#   .. envvar::
#       :var  BUILD_ID: Id of Jenkins build under which this
#                       script is running, defaults to ``0``
#       :type BUILD_ID: int
#       :var  WORKSPACE: Location where build is started, defaults to ``.``
#       :type WORKSPACE: path
#
#   .. requirements::
#
#       * ``curl`` in ``/usr/bin/curl``
#       * sudo rigths
#
#
#   .. class:: sample.envfile
#       :var  OUT: useless output variable
#       :type OUT: path
#
#
#   .. entrypoint:: main
#
#
#   .. affects::
#       :file sample.envfile: dumped env variables
#
#
#   .. seealso:: https://mirantis.jira.com/wiki/display/PRD/XXX
#   .. warnings:: never use on productions for test purposes

set -ex

BUILD_ID="${BUILD_ID:-0}"
WORKSPACE="${WORKSPACE:-.}"


main () {
    #   .. function:: main
    #
    #       Do some useless things, shows how to document functions,
    #       and how to add documentation strings
    #
    #       :param A: just a first parameter of function
    #       :type A: url
    #
    #       :output useless.envfile: file with
    #       :type   useless.envfile: sample.envfile
    #
    #       :stdin: not used
    #       :stdout: useless debug information
    #       :stderr: not used
    #
    #   .. note:: https://mirantis.jira.com/PROD-XX
    #
    local A="${1}"

    # Free-style documentation strings are allowed and appreciated
    echo "${A}"

    # this variable is unused to show how to disable check
    # shellcheck disable=SC2034
    local _useless_variable=42

    echo "OUT=${BUILD_ID}" > "${WORKSPACE}/useless.envfile"
}

if [ "$0" == "${BASH_SOURCE}" ] ; then
    main "${@}"
fi