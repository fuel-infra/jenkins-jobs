#!/bin/bash -x
export $extra_commits=`ssh -p 29418 fuel-watcher@review.openstack.org gerrit query --format=TEXT --current-patch-set '149944' | awk '/ref:/ {print $NF}'`
osci-mirrors/fuel_master_mirror_vc.sh
