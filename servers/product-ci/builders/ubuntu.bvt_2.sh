rm -rf logs/*

ISO_PATH=`seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}"`

echo $ISO_PATH

sh -x "utils/jenkins/system_tests.sh" -t test -w $WORKSPACE -V $VENV_PATH -j $JOB_NAME -o --group=$TEST_GROUP -i $ISO_PATH