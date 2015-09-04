echo STARTED_TIME="`date -u +'%Y-%m-%dT%H:%M:%S'`" > ci_status_params.txt
osci-mirrors/fuel_master_mirror_vc.sh
echo "USE_STABLE_MOS_FOR_STAGING = $USE_STABLE_MOS_FOR_STAGING" >> ${WORKSPACE:-"."}/mirror_staging.txt
echo FINISHED_TIME="`date -u +'%Y-%m-%dT%H:%M:%S'`" >> ci_status_params.txt

