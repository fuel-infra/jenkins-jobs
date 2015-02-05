rm -rf logs/*
export VENV_PATH=/home/jenkins/venv-nailgun-tests
ENV_NAME=$ENV_PREFIX.$BUILD_NUMBER.$BUILD_ID
ENV_NAME=${ENV_NAME:0:68}
ISO_PATH=`seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}"`

sh -x "utils/jenkins/system_tests.sh" -t test -w "$WORKSPACE" -e "$ENV_NAME" -o --group="$TEST_GROUP" -i "$ISO_PATH"
