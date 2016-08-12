#!/bin/bash

set -o xtrace
set -o errexit
set -o pipefail
set -o errtrace

trap 'exit 0' ERR

function cleanup-vms
{
    virsh list --name --inactive | grep -e '-test-' |
        xargs -r -L1 virsh undefine --snapshots-metadata && true
    local vm_name
    virsh list --name | grep -e '-test-' |
        while read vm_name
        do
            local run_time=$(ps -e -o etimes,args |
                                 awk "/[q]emu-system.*${vm_name}/ {print \$1}")
            if [ "${run_time}" -gt $(( 3*3600 )) ]
            then
                virsh destroy "${vm_name}" || true
                virsh undefine --snapshots-metadata "${vm_name}" || true
            fi
        done
}

function cleanup-images
{
    local vm_name
    find /run/shm -maxdepth 1 -type d -name '*-test-*' -mmin +$(( 3*60 )) \
         -printf '%f\n' |
        while read vm_name
        do
            if ! virsh list | grep -q -e "${vm_name}"
            then
                rm -rf "/run/shm/${vm_name}"
            fi
        done
}

cleanup-vms
cleanup-images
