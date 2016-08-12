#!/bin/bash

set -o xtrace
set -o errexit

##
## Purge VMs if it was not cleaned properly
##

# fixme
# shellcheck disable=SC2015
[ ! -f vm_name ] && exit 0 || :

VM_NAME=$(cat vm_name)
# fixme
# shellcheck disable=SC2015
[ -z "${VM_NAME}" ] && exit 1 || :

export LIBVIRT_DEFAULT_URI="qemu:///system"

virsh destroy "${VM_NAME}" || :

for snapshot in $(virsh -q snapshot-list --name "${VM_NAME}"); do
    virsh snapshot-delete "${VM_NAME}" "${snapshot}" || :
done

virsh undefine "${VM_NAME}" || :

rm -rf "/run/shm/${VM_NAME}" || :
