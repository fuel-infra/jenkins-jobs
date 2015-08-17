#!/bin/bash

set -o xtrace
set -o errexit

##
## Purge VMs if it was not cleaned properly
##

function virsh {
    virsh --connect=qemu:///system "${@}"
}

[ ! -f vm_name ] && exit 0 || :
VM_NAME=$(cat vm_name)
[ "${VM_NAME}" == "" ] && exit 1 || :
if [ $(virsh list --all 2>/dev/null | grep -Fc -e " ${VM_NAME} ") -ne 0 ] ; then
    virsh destroy "${VM_NAME}" || :
    for snapshot in $(virsh snapshot-list "${VM_NAME}" | grep -F -e "-snap" | awk '{print $1}') ; do
        virsh snapshot-delete "${VM_NAME}" "${snapshot}" || :
    done
    virsh undefine "${VM_NAME}" || :
fi

[ -d "/run/shm/${VM_NAME}" ] && rm -rf "/run/shm/${VM_NAME}" || :
