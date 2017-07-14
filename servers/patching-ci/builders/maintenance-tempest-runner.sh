#!/bin/bash

set -xe

# Input:
# REPORT_PREFIX=path to report directory
# ENV_NAME=devops name
# SNAPSHOT_NAME=tempest group name
# MILESTONE=7.0
# VENV_PATH=path to venv with devops
# TEMPEST_RUNNER=tempest runner type

# clean previous results to prevent double-reporting of same run

if [ -f "${REPORT_PREFIX}/verification.xml" ]; then
    mv -f "${REPORT_PREFIX}/verification.xml" "${REPORT_PREFIX}/verification.xml.unreported"
fi
rm -rf log.log verification.xml tmepest.log tempest.conf

source "${VENV_PATH}/bin/activate"

MILESTONE_MAJOR=$(echo "${MILESTONE}" | cut -c 1)

# retry 3 times, because dos.py is not stable sometimes (ntp problem)
for i in $(seq 3); do
    if [ "${MILESTONE_MAJOR}" -ge "7" ]; then
        dos.py revert-resume "${ENV_NAME}" "${SNAPSHOT_NAME}" && break
    else
        dos.py revert-resume "${ENV_NAME}" --snapshot-name "${SNAPSHOT_NAME}" && break
    fi
    echo "Revert-resume attempt $i is failed. Retrying..."
    dos.py destroy "${ENV_NAME}"
    sleep 15
done

sleep 600

VM_USERNAME="root"
VM_PASSWORD="r00tme"
VM_IP=$(dos.py list --ips|grep "${ENV_NAME}"|awk '{print $2}')

deactivate

SSH_OPTIONS=(-o "ConnectTimeout=20" -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null")
ssh_to_fuel_master() {
    #   $1 - command to execute
    sshpass -p "${VM_PASSWORD}" ssh "${SSH_OPTIONS[@]}" "${VM_USERNAME}@${VM_IP}" "$1"
}

scp_to_fuel_master() {
    #   $1 - file, can be 'flagged' with --recursive
    #   $2 - target path
    SCP_ARGS=()
    case $1 in
        -r|--recursive)
        SCP_ARGS+="-r"
        shift
        ;;
    esac
    targetpath=$2
    sshpass -p "${VM_PASSWORD}" scp "${SSH_OPTIONS[@]}" "${SCP_ARGS[@]}" "$1" "${VM_USERNAME}@${VM_IP}:${targetpath:-\"/tmp/\"}"
}

scp_from_fuel_master() {
    #   $1 - remote file, can be 'flagged' with --recursive
    #   $2 - local path
    SCP_ARGS=()
    case $1 in
        -r|--recursive)
        SCP_ARGS+="-r"
        shift
        ;;
    esac
    sshpass -p "${VM_PASSWORD}" scp "${SSH_OPTIONS[@]}" "${SCP_ARGS[@]}" "${VM_USERNAME}@${VM_IP}:$1" "$2"
}

check_return_code_after_command_execution() {
    if [ "$1" -ne 0 ]; then
        if [ -n "$2" ]; then
            echo "$2"
        fi
        exit 1
    fi
}

enable_public_ip() {
    source "${VENV_PATH}/bin/activate"
    public_mac=$(virsh dumpxml "${ENV_NAME}_admin" | grep -B 1 "${ENV_NAME}_public" | awk -F"'" '{print $2}' | head -1)
    public_ip=$(dos.py net-list "${ENV_NAME}" | awk '/public/{print $2}' | grep -E -o "[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}")
    public_net=$(dos.py net-list "${ENV_NAME}" | awk -F/ '/public/{print $2}')
    deactivate

    ssh_to_fuel_master <<EOF
iface=\$(grep -i -l "${public_mac}" /sys/class/net/*/address|awk -F'/' '{print \$5}')
ifconfig "\${iface}" up
ip addr add "${public_ip}.31/${public_net}" dev "\${iface}"
EOF
}

wait_up_env() {
    set +e
    env_id=$(ssh_to_fuel_master "fuel env" | tail -1 | awk '{print $1}')
    for testtype in ha sanity smoke; do
        for iteration in {1..60}; do
            failure=$(ssh_to_fuel_master "fuel health --env ${env_id} --check ha" | grep failure)
            if [[ -z "${failure}" ]]; then
                echo "${testtype} tests are passed"
                break
            else
                echo "${testtype} tests failed on ${iteration} iteration: ${failure}"
            fi
            sleep 60
        done
    done
    set -e
}

WORK_FLDR=$(ssh_to_fuel_master "mktemp -d")
ssh_to_fuel_master "chmod 777 $WORK_FLDR"
if [ "${MILESTONE_MAJOR}" -lt "9" ]; then
   enable_public_ip
fi
wait_up_env

echo "Used ${TEMPEST_RUNNER?} tempest runner"

if [[ "${TEMPEST_RUNNER}" == "mos-tempest-runner" ]]; then
    env_id=$(ssh_to_fuel_master "fuel env" | tail -1 | awk '{print $1}')
    ssh_to_fuel_master "fuel --env ${env_id} settings --download"
    objects_ceph=$(ssh_to_fuel_master "cat settings_${env_id}.yaml" | grep -A 7 "ceilometer:" | awk '/value:/{print $2}')
    echo "Download and install mos-tempest-runner project"
    git clone https://github.com/Mirantis/mos-tempest-runner.git -b "stable/${MILESTONE}"
    rm -rf mos-tempest-runner/.git*
    if ! ${objects_ceph}; then
        sed -i '/test_list_no_containers/d' mos-tempest-runner/shouldfail/*/swift
        sed -i '/test_list_no_containers/d' mos-tempest-runner/shouldfail/default_shouldfail.yaml
    fi
    scp_to_fuel_master -r mos-tempest-runner "${WORK_FLDR}"
    ssh_to_fuel_master "/bin/bash -x $WORK_FLDR/mos-tempest-runner/setup_env.sh"
    check_return_code_after_command_execution $? "Install mos-tempest-runner is failure."

    echo "Run tempest tests"
    set +e
    ssh_to_fuel_master <<EOF | tee tempest_run.log
/${WORK_FLDR}/mos-tempest-runner/rejoin.sh
. /home/developer/mos-tempest-runner/.venv/bin/activate
. /home/developer/openrc
run_tests > ${WORK_FLDR}/log.log
EOF

    scp_from_fuel_master -r /home/developer/mos-tempest-runner/tempest-reports/* .
    scp_from_fuel_master "${WORK_FLDR}/log.log" ./

    mv tempest-report.xml verification.xml
    set -e
elif [[ "${TEMPEST_RUNNER}" == "rally" ]]; then
    # Workaround for run on master node. install dependencies for tempest commit b39bbce80c69a57c708ed1b672319f111c79bdd5
    sed -i 's|rally verify install --source /var/lib/tempest --no-tempest-venv|rally verify install --source /var/lib/tempest --system-wide --version b39bbce80c69a57c708ed1b672319f111c79bdd5|g' rally-tempest/latest/setup_tempest.sh

    sed -i 's|FROM rallyforge/rally:latest|FROM rallyforge/rally:0.5.0|g' rally-tempest/latest/Dockerfile
    sed -i 's|RUN git clone https://git.openstack.org/openstack/tempest|RUN git clone https://git.openstack.org/openstack/tempest; cd tempest; git checkout b39bbce80c69a57c708ed1b672319f111c79bdd5|g' rally-tempest/latest/Dockerfile
    sed -i 's|pip install tempest/|pip install -U -r requirements.txt|g' rally-tempest/latest/Dockerfile

    docker build -t rally-tempest rally-tempest/latest
    docker save -o ./dimage rally-tempest

    scp_to_fuel_master dimage "${WORK_FLDR}/rally"
    ssh_to_fuel_master "ln -sf ${WORK_FLDR}/rally /root/rally"
    scp_to_fuel_master mos-ci-deployment-scripts/jenkins-job-builder/maintenance/helpers/rally_run.sh "${WORK_FLDR}"
    ssh_to_fuel_master "chmod +x ${WORK_FLDR}/rally_run.sh"

    echo "Run tempest tests"
    set +e
    ssh_to_fuel_master "/bin/bash -xe ${WORK_FLDR}/rally_run.sh > ${WORK_FLDR}/log.log"

    scp_from_fuel_master /var/lib/rally-tempest-container-home-dir/verification.xml ./
    scp_from_fuel_master "${WORK_FLDR}/log.log" ./
    set -e
elif [[ "${TEMPEST_RUNNER}" == "rally_without_docker" ]]; then
    scp_to_fuel_master mos-ci-deployment-scripts/jenkins-job-builder/shell_scripts/run_tempest_without_docker.sh "${WORK_FLDR}/tempest.sh"

    CONTROLLER_ID=$(ssh_to_fuel_master "fuel node | grep -m1 controller | awk '{print \$1}'")
    ssh_to_fuel_master "scp ${WORK_FLDR}/tempest.sh node-${CONTROLLER_ID}:/root/tempest.sh"

    # Workaround for 'There are problems and -y was used without --force-yes problem'
    ssh_to_fuel_master "ssh node-${CONTROLLER_ID} 'echo \"APT::Get::AllowUnauthenticated 1;\" >>  /etc/apt/apt.conf.d/02allow-unathenticated'"

    echo "Run tempest tests"
    set +e
    ssh_to_fuel_master "ssh node-${CONTROLLER_ID} 'bash -xe /root/tempest.sh'"

    # collect logs
    ssh_to_fuel_master "scp node-${CONTROLLER_ID}:/root/rally/verification.xml ${WORK_FLDR}/verification.xml"
    ssh_to_fuel_master "scp node-${CONTROLLER_ID}:/root/rally/log.log ${WORK_FLDR}/log.log"
    ssh_to_fuel_master "scp node-${CONTROLLER_ID}:/root/rally/tempest.conf ${WORK_FLDR}/tempest.conf"
    ssh_to_fuel_master "scp node-${CONTROLLER_ID}:/root/rally/tempest.log ${WORK_FLDR}/tempest.log"

    scp_from_fuel_master "${WORK_FLDR}/verification.xml" ./
    scp_from_fuel_master "${WORK_FLDR}/log.log" ./log.log
    scp_from_fuel_master "${WORK_FLDR}/tempest.conf" ./tempest.conf
    scp_from_fuel_master "${WORK_FLDR}/tempest.log" ./tempest.log
    set -e
else
    echo "INVALID TEMPEST RUNNER '${TEMPEST_RUNNER}'"
fi

set +e

if [[ -n "${REPORT_PREFIX}" ]]; then
    mkdir -p "${REPORT_PREFIX}"
    cp -f verification.xml "${REPORT_PREFIX}"
fi

source "${VENV_PATH}/bin/activate"
SNAPSHOT_NAME="after-tempest-${BUILD_ID}-$(date +%d-%m-%Y_%Hh_%Mm)"
dos.py snapshot "${ENV_NAME}" "${SNAPSHOT_NAME}"
dos.py destroy "${ENV_NAME}"
deactivate
