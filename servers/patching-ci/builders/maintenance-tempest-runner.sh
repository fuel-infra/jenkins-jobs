#!/bin/bash -xe

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

source "${VENV_PATH}/bin/activate"

if [ "$(echo "$MILESTONE" | cut -c 1)" -ge "7" ]; then
    dos.py revert-resume "$ENV_NAME" "$SNAPSHOT_NAME"
else
    dos.py revert-resume "$ENV_NAME" --snapshot-name "$SNAPSHOT_NAME"
fi
VM_USERNAME="root"
VM_PASSWORD="r00tme"
VM_IP=$(dos.py list --ips|grep "${ENV_NAME}"|awk '{print $2}')

deactivate

SSH_OPTIONS=(-o ConnectTimeout=20 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
ssh_to_fuel_master() {
    #   $1 - command to execute
    sshpass -p "${VM_PASSWORD}" ssh "${SSH_OPTIONS[@]}" "${VM_USERNAME}@${VM_IP}" "$1"
}

scp_to_fuel_master() {
    #   $1 - file, can be 'flagged' with --recursive
    #   $2 - target path
    SCP_ARGS=""
    case $1 in
        -r|--recursive)
        SCP_ARGS="-r"
        shift
        ;;
    esac
    targetpath=$2
    sshpass -p "${VM_PASSWORD}" scp "${SSH_OPTIONS[@]}" "${SCP_ARGS}" "$1" "${VM_USERNAME}@${VM_IP}:${targetpath:-\"/tmp/\"}"
}

scp_from_fuel_master() {
    #   $1 - remote file, can be 'flagged' with --recursive
    #   $2 - local path
    SCP_ARGS=""
    case $1 in
        -r|--recursive)
        SCP_ARGS="-r"
        shift
        ;;
    esac
    sshpass -p "${VM_PASSWORD}" scp "${SSH_OPTIONS[@]}" "${SCP_ARGS}" "${VM_USERNAME}@${VM_IP}:$1" "$2" 
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
enable_public_ip
wait_up_env

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

    echo "download tempest result"
    scp_from_fuel_master -r /home/developer/mos-tempest-runner/tempest-reports/* .
    mv tempest-report.xml verification.xml
    echo "DONE"
elif [[ "$TEMPEST_RUNNER" == "rally" ]]; then
    sed -i 's|rally verify install --source /var/lib/tempest --no-tempest-venv|rally verify install --source /var/lib/tempest|g' rally-tempest/latest/setup_tempest.sh
    sed -i 's|FROM rallyforge/rally:latest|FROM rallyforge/rally:0.3.1|g' rally-tempest/latest/Dockerfile
    # Workaround for run on master node. install dependencies for tempest commit b39bbce80c69a57c708ed1b672319f111c79bdd5
    sed -i 's|RUN git clone https://git.openstack.org/openstack/tempest |RUN git clone https://git.openstack.org/openstack/tempest; cd tempest; git checkout b39bbce80c69a57c708ed1b672319f111c79bdd5; cd - |g' rally-tempest/latest/Dockerfile

    sudo docker build -t rally-tempest rally-tempest/latest
    sudo docker save -o ./dimage rally-tempest

    scp_to_fuel_master dimage "${WORK_FLDR}/rally"
    ssh_to_fuel_master "ln -sf ${WORK_FLDR}/rally /root/rally"
    scp_to_fuel_master mos-ci-deployment-scripts/jenkins-job-builder/maintenance/helpers/rally_run.sh "${WORK_FLDR}"
    ssh_to_fuel_master "chmod +x ${WORK_FLDR}/rally_run.sh"
    ssh_to_fuel_master "/bin/bash -xe ${WORK_FLDR}/rally_run.sh > ${WORK_FLDR}/log.log"

    scp_from_fuel_master /var/lib/rally-tempest-container-home-dir/verification.xml ./
fi

set +e
scp_from_fuel_master "$WORK_FLDR/log.log" ./

mkdir -p "${REPORT_PREFIX}"
cp verification.xml "${REPORT_PREFIX}"

source "${VENV_PATH}/bin/activate"
SNAPSHOT_NAME="after-tempest-${BUILD_ID}-$(date +%d-%m-%Y_%Hh_%Mm)"
dos.py snapshot "${ENV_NAME}" "${SNAPSHOT_NAME}"
dos.py destroy "${ENV_NAME}"
deactivate
