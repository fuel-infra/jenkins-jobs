#!/bin/bash -x
echo STARTED_TIME="`date -u +'%Y-%m-%dT%H:%M:%S'`" > ci_status_params.txt
export $extra_commits=`git ls-remote | grep 149944 | awk '{print $2}' | sed 's/\// /g' | sort -n -k5 | tail -n 1 | sed 's/ /\//g'`
osci-mirrors/fuel_master_mirror_vc.sh
echo FINISHED_TIME="`date -u +'%Y-%m-%dT%H:%M:%S'`" >> ci_status_params.txt

