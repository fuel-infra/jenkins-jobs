#!/bin/bash
set -ex
source /etc/profile

py.test utils/configuration_validator/  --dir deployment/
