#!/bin/bash
set -e
source /etc/profile
/bin/bash $WORKSPACE/utils/jenkins/fuel_unit_tests.sh
