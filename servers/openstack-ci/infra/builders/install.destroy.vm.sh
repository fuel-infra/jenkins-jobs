#!/bin/bash

set -o xtrace
set -o errexit

##
## Purge VMs if it was not cleaned properly
##

virsh_opts="--connect=qemu:///system"

[ ! -f vm_name ] && exit 0
VM_NAME=$(cat vm_name)
[ "$VM_NAME" == "" ] && exit 1
if virsh $virsh_opts domstate "$VM_NAME" &>/dev/null ; then
    virsh $virsh_opts destroy "$VM_NAME" || :
    for snapshot in $(virsh $virsh_opts snapshot-list "$VM_NAME" | grep -F -e "-snap" | awk '{print $1}') ; do
        virsh $virsh_opts snapshot-delete "$VM_NAME" "$snapshot" || :
    done
    virsh $virsh_opts undefine "$VM_NAME" || :
fi

[ -d "/run/shm/$VM_NAME" ] && rm -rf "/run/shm/$VM_NAME"
exit 0
