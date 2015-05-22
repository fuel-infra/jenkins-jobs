#!/bin/bash -x
echo STARTED_TIME="$(date -u +'%Y-%m-%dT%H:%M:%S')" > ci_status_params.txt
osci-mirrors/fuel_master_mirror_vc.sh
echo FINISHED_TIME="$(date -u +'%Y-%m-%dT%H:%M:%S')" >> ci_status_params.txt

