#!/bin/bash
set -ex

py.test utils/configuration_validator/  --dir deployment/
