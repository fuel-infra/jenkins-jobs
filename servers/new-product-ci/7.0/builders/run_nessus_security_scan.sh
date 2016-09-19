#!/bin/bash

set -ex

# refresh volumes in case of changes
virsh pool-refresh default

# debug info: show all volumes
virsh vol-list --details default

virsh vol-delete nessus.qcow2 --pool default || true
virsh vol-clone nessus_orig.qcow2 nessus.qcow2 --pool default

