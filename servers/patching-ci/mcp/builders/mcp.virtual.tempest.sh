#!/bin/bash

set -xe

source "${VENV_PATH}/bin/activate"

export IMAGE_PATH1604=/home/jenkins/images/xenial-server-cloudimg-amd64-disk1.img
export SHUTDOWN_ENV_ON_TEARDOWN
export REPOSITORY_SUITE
export ENV_NAME

export PYTHONIOENCODING=UTF-8

LC_ALL=en_US.UTF-8  py.test -vvv -s -k test_tcp_install_run_rally

REPORT_FILE=$(find "$(pwd)" -name "report_*.xml")

mv "${REPORT_FILE?}" "${WORKSPACE}/verification.xml"

deactivate
