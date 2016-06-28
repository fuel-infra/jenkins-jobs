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
GREEN='\033[0;32m'
NC='\033[0m'

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

    # generate nodes and covered roles list
    ./lab-vm exec puppet-master ls -1 /var/lib/hiera/nodes/ 2>/dev/null | \
      sed 's/.test.local.yaml//g' | sed 's/-/_/g' | \
      tee "${WORKSPACE}/selected.txt" | sed 's/[0-9]*//g' | sort -u \
      > "${WORKSPACE}/covered.txt"

    # generate roles (without roles already covered by nodes list)
    ./lab-vm exec puppet-master ls -1 /var/lib/hiera/roles/ 2>/dev/null | \
      sed 's/.yaml//g' | grep -v -w -f "${WORKSPACE}/covered.txt" \
      >> "${WORKSPACE}/selected.txt"

    # generate a file with role to image name mapping
    ./lab-vm exec puppet-master "grep -RPo '^#.*(?<=image:)[^\s]+' \
      /var/lib/hiera/roles" | awk -F '/|image:|.yaml:#' '{print $6, $8}' \
      > "${WORKSPACE}/mapping.txt"

    # iterate all the filtered roles
    grep -v -w -f "${WORKSPACE}/blacklist.txt" "${WORKSPACE}/selected.txt" | \
      egrep "${INCLUDE}" | egrep -v -w "${EXCLUDE}" | sed 's/_/-/g' | \
      xargs -n1 -P"${PARALLELISM}" -I '%' bash -c "
        # create lock file on puppet run
        touch ${WORKSPACE}/%.running
        # generate role name
        ROLE=\$(echo % | sed 's/-/_/g' | sed 's/[0-9]*//g')
        # check if image name set in mapping file
        IMAGE=\$(awk -v role=\${ROLE} '{if (\$1 == role) { print \$2 }}' \
          ${WORKSPACE}/mapping.txt)
        # create new VM and perform first puppet run
        ./lab-vm create % \${IMAGE} 2>&1 | (sed 's/^/%: /') | \
          tee -a ${WORKSPACE}/first_run.txt
        # stop tests when got exit code of 1, 4 or 6 on second puppet run
        ./lab-vm exec % puppet agent --detailed-exitcodes --test 2>&1 | \
          (sed 's/^/%: /') | tee -a ${WORKSPACE}/second_run.txt
        # save exit code
        STATUS=\${PIPESTATUS}
        # remove lock as puppet run is finished
        rm ${WORKSPACE}/%.running
        # check if status code is 1, 4 or 6
        if [[ '146' =~ \${STATUS} ]]; then
            exit 255
        else
            printf '%: ${GREEN}Success: second run deployment success!${NC}\n' | \
              tee -a ${WORKSPACE}/successful.txt
        fi
        ./lab-vm remove %
      " || RETURN="${?}"

    # disable script trace from here to form clear output
    set +x

    # wait until all processes are stopped
    while ls "${WORKSPACE}"/*.running > /dev/null 2>&1; do
        sleep 1
    done

    # prepare and display deployment summary
    printf '\n\n========== SUCCESSFUL NODES =========\n\n'
    cat "${WORKSPACE}/successful.txt"

    printf '\n\n========== FIRST RUN ERRORS =========\n\n'
    grep 'Error:' "${WORKSPACE}/first_run.txt" | sort -s -k 1,1

    printf '\n\n========== SECOND RUN ERRORS =========\n\n'
    grep 'Error:' "${WORKSPACE}/second_run.txt" | sort -s -k 1,1

    # exit with return code if any exists
    if [[ -n "${RETURN}" ]]; then
        exit "${RETURN}"
    else
        exit 0
    fi
}

if [ "$0" == "${BASH_SOURCE}" ] ; then
    main "${@}"
fi
