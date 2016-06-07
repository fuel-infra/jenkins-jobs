#!/bin/bash
#
#   :mod:`guess-testgroup` -- guess testgroup for system test
#   ==========================================
#
#   .. module:: guess-testgroup
#       :platform: Unix
#       :synopsis: Guess testgroup for system test (deployment)
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: Alexander Evseev <aevseev@mirantis.com>
#
#
#   This script is intended to create file containing guessed testgroup
#   for system test (deployment) basing on project name
#
#
#   .. envvar::
#       :var  GERRIT_PROJECT: Project name
#       :type GERRIT_PROJECT: string
#       :var  ZUUL_PROJECT: Project name. Used when GERRIT_PROJECT is undefined
#       :type ZUUL_PROJECT: string
#       :var  WORKSPACE: Working directory
#       :type WORKSPACE: path
#
#
#   .. class:: systest_testgroup.envfile
#       :var  TEST_GROUP: Testgroup for system test
#       :type TEST_GROUP: string
#       :var  UPDATE_FUEL: Update fuel packages during master node bootstrap
#       :type UPDATE_FUEL: bool
#
#
#   .. entrypoint:: main
#
#
#   .. affects::
#       :file systest_testgroup.envfile: env variable containig testgroup
set -ex

WORKSPACE="${WORKSPACE:-.}"


main () {
    #   .. function:: main
    #
    #       Create file containig info about test case for given project
    #
    #       :output systest_testgroup.envfile: file with testgroup
    #       :type   systest_testgroup.envfile: sample.envfile
    #
    #       :stdin: not used
    #       :stdout: not used
    #       :stderr: script trace
    #
    local _PROJECT=${GERRIT_PROJECT:-${ZUUL_PROJECT}}
    local _PROJECT_NAME=${_PROJECT#*/}
    local _TEST_GROUP
    local _UPDATE_FUEL=false

    # Fuel testgroups are derived from servers/fuel-ci/project-build-and-test-pkgs.yaml
    # Note, above jobs has three testgroups for fuel-library:
    #   - smoke_neutron
    #   - neutron_vlan_ha
    #   - review_in_fuel_library
    # Here is used only one - smoke_neutron
    # Most Fuel testcases require UPDATE_FUEL=true

    case ${_PROJECT_NAME} in
        fuel-agent)
            _TEST_GROUP=review_fuel_agent_ironic_deploy
            _UPDATE_FUEL=true
        ;;
        fuel-astute)
            _TEST_GROUP=review_astute_patched
            _UPDATE_FUEL=true
        ;;
        fuel-library)
            _TEST_GROUP=smoke_neutron
        ;;
        fuel-ostf)
            _TEST_GROUP=gate_ostf_update
            _UPDATE_FUEL=true
        ;;
        fuel-web)
            _TEST_GROUP=review_fuel_web_deploy
            _UPDATE_FUEL=true
        ;;
        python-fuelclient)
            _TEST_GROUP=review_fuel_client
            _UPDATE_FUEL=true
        ;;
    esac

    if [ -n "${_TEST_GROUP}" ]; then
        echo "TEST_GROUP=${_TEST_GROUP}" > "${WORKSPACE}/systest_testgroup.envfile"
        if [ "${_UPDATE_FUEL}" = "true" ]; then
            echo "UPDATE_FUEL=true" >> "${WORKSPACE}/systest_testgroup.envfile"
        fi
    fi
}

if [ "$0" == "${BASH_SOURCE}" ] ; then
    main "${@}"
fi
