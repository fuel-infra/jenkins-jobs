#!/bin/bash

set -e

source /etc/profile

./run_tests.sh

for plugin in $(ls built_plugins); do
   echo "<a href="${BUILD_URL}artifact/built_plugins/${plugin}">${plugin}</a>"
done
