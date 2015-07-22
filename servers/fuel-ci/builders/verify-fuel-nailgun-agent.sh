#!/bin/bash

# Sourcing profile file is required for rvm to work.
# As it it produces a lot of logs, we don't use 'set -x' here

set -e

source /etc/profile

./run_tests.sh
