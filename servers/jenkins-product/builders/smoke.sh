export PATH=/bin:/usr/bin:/sbin:/usr/sbin:$PATH

rm -rf logs/*

export VENV_PATH=/home/jenkins/venv-nailgun-tests
export TIMEOUT=60
export ATTEMPTS=8
#export STORAGE_POOL_NAME="ssd"
export CONNECTION_STRING='qemu+tcp://127.0.0.1:16509/system'
export ISO_PATH=`seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}"`

sh -x "utils/jenkins/system_tests.sh" -t test -w "${WORKSPACE}" -V "${VENV_PATH}" -j "${JOB_NAME}" -o --group=deploy_simple_cinder