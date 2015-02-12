#!/bin/bash -x
export $extra_commits=`git ls-remote | grep 149944 | awk '{print $2}' | sed 's/\// /g' | sort -n -k5 | tail -n 1 | sed 's/ /\//g'`
osci-mirrors/fuel_master_mirror_vc.sh
