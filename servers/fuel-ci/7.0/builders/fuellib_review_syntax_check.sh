#!/bin/bash
set -ex
source /etc/profile
/bin/bash $WORKSPACE/utils/jenkins/fuel_syntax_check.sh -a
