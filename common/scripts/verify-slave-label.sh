#!/bin/bash
set -ex
cd utils/label_compliance
./parse_yaml.py "${LABEL_NAME}" > test.param
