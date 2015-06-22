#!/bin/bash

set -ex

LOGS="${WORKSPACE}/fuel-qa/logs/"

rm -rf "${LOGS}"

mkdir -p "${LOGS}"

echo "Data 0" > "${WORKSPACE}/fuel-qa/nosetests.xml"

echo "Data 1" > "${LOGS}/File1"
echo "Data 2" > "${LOGS}/File2"
