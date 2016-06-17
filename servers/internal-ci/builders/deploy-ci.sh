#!/bin/bash
#
#   :mod:`deploy-ci` -- Deployment CI script
#   ==========================================
#
#   .. module:: deploy-ci
#       :platform: Unix
#       :synopsis: This builds complete environment using all available roles to test it.
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: Pawel Brzozowski <pbrzozowski@mirantis.com>
#
#
#   This module does everything which is required to test all available roles
#   It contains:
#       * tenant cleaner
#       * tenant setup
#       * preparation of base VMs (Puppet Master, Name server)
#       * role iterator
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
#       * ci-lab
#       * git
#       * sed
#
#
#   .. entrypoint:: main
#
#
#   .. affects::
#       :directory ci-lab: directory to checkout ci-lab code
#       :directory ci-lab-tmp: temporary directory with python environment
#
#
#   .. seealso:: https://mirantis.jira.com/browse/PROD-1017
#   .. warnings:: can't be run multiple times per once

set -ex

BUILD_ID="${BUILD_ID:-0}"
WORKSPACE="${WORKSPACE:-.}"

main () {
    #   .. function:: main
    #
    #       Main function to handle VM creation and testing
    #
    #       :stdin: not used
    #       :stdout: useless debug information
    #       :stderr: not used
    #
    #   .. note:: https://mirantis.jira.com/browse/PROD-1017
    #

    echo "FORCE=1" \
    "BASE_DIR=${WORKSPACE}" \
    "TMP_DIR=${WORKSPACE}/virtualenv" \
    "GERRIT_REFSPEC=\"${GERRIT_REFSPEC}\"" \
    "DNS1=${DNS1}" \
    "DNS2=${DNS2}" \
    "OS_FLAVOR_NAME=${OS_FLAVOR_NAME}" \
    "OS_IMAGE_NAME=${OS_IMAGE_NAME}" \
    "OS_OPENRC_PATH=${OS_OPENRC_PATH}" > "${WORKSPACE}/config_local"

    # prepare environment
    cd "${WORKSPACE}"
    ./tools/prepare_env.sh

    # refresh openstack environment
    cd "${WORKSPACE}"
    ./tools/openstack_clean_all_vms.sh
    # wait for all VM to be stopped
    sleep 30
    ./tools/openstack_clean_config.sh || true
    ./tools/openstack_prepare.sh

    # prepare hiera data
    cd "${WORKSPACE}/hiera"
    ./gen_ssl review.test.local
    ./gen_ssh gerrit_root
    ./gen_ssh gerrit_ssh_rsa
    ./gen_ssh gerrit_ssh_dsa dsa
    ./gen_ssh jenkins_master_rsa
    ./gen_ssh jenkins_publisher_rsa
    ./gen_ssh zuul_rsa
    ./gen_ssh jenkins_slave_osci_rsa
    ./gen_ssh jenkins_slave_rsa
    ./gen_ssl test-ci.test.local
    ./gen_gpg perestroika_gpg

    # prepare base VMs
    cd "${WORKSPACE}"
    ./lab-vm create ns1
    ./lab-vm create puppet-master

    # check each role
    # WORKAROUND (second pass Puppet run) https://bugs.launchpad.net/bugs/1578766
    cd "${WORKSPACE}"

    # get blacklist
    ./lab-vm exec puppet-master cat /etc/puppet/blacklist.txt | \
      grep -v '^$\|^\s*\#' > "${WORKSPACE}/blacklist.txt"

    # get all available roles
    ./lab-vm exec puppet-master ls -1 /var/lib/hiera/roles/ 2>/dev/null | \
      sed 's/.yaml//g' | egrep "${INCLUDE}" | egrep -v -w "${EXCLUDE}" \
      > "${WORKSPACE}/selected.txt"

    # iterate all the filtered roles
    grep -v -w -f "${WORKSPACE}/blacklist.txt" "${WORKSPACE}/selected.txt" | \
      sed 's/_/-/g' | xargs -n1 -P"${PARALLELISM}" -I '%' bash -c "
        # create new VM and perform first puppet run
        ./lab-vm create % 2>&1 | (sed 's/^/%: /')
        # stop tests when got exit code of 1, 4 or 6 on second puppet run
        ./lab-vm exec % puppet agent --test 2>&1 | (sed 's/^/%: /')
        if [[ '146' =~ \${PIPESTATUS} ]]; then
            exit 255
        fi
        ./lab-vm remove %
      "
    exit "${?}"
}

if [ "$0" == "${BASH_SOURCE}" ] ; then
    main "${@}"
fi
