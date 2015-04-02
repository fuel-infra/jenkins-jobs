#!/bin/bash

set -ex

export TESTRAIL_TEST_SUITE="Smoke/BVT"
export TESTRAIL_URL="https://mirantis.testrail.com"
ISO_BUID=$(echo ${ISO_BUILD_URL%/*}|awk -F/ '{ print $NF }')

python fuelweb_test/testrail/report.py --manual --verbose --job-name 6.1.test_all --build-number ${ISO_BUILD}

