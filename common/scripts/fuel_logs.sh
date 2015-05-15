#!/bin/bash

set -ex

find "${WORKSPACE}/logs/" -name "fail*.tar.xz" -type f -exec "${WORKSPACE}/utils/jenkins/fuel_logs.py" "{}" >"{}.filtered.log" \;
