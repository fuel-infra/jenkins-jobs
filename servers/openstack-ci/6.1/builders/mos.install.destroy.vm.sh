#!/bin/bash -ex

##
## Purge VMs if it was not cleaned properly
##

[ ! -f vm_name ] && exit 0 || :
VM_NAME=`cat vm_name`
[ "$VM_NAME" == "" ] && exit 1 || :
if [ `virsh --connect=qemu:///system list --all 2>/dev/null | grep " $VM_NAME " | wc -l` != "0" ] ; then
    virsh --connect=qemu:///system destroy $VM_NAME || :
    for snapshot in `virsh --connect=qemu:///system snapshot-list $VM_NAME | grep "\-snap" | awk '{print $1}'` ; do
        virsh --connect=qemu:///system snapshot-delete $VM_NAME $snapshot || :
    done
    virsh --connect=qemu:///system undefine $VM_NAME || :
fi

[ -d "/run/shm/$VM_NAME" ] && rm -rf /run/shm/$VM_NAME || :

#sudo virsh destroy `cat vm_name` || :
#sudo rm -rf /run/shm/`cat vm_name` || :
