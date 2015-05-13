#!/bin/bash

set -o xtrace
set -o errexit
set -o pipefail

FILE_COUNT=$(grep '<failure' build* | wc -l)
cat << EOF > overall.xml
<testsuite name="Package build" tests="Package build" errors="0" failures="${FILE_COUNT}" skip="0">
EOF
for x in build*
do
  cat "${x}" | grep -v "testsuite" >> overall.xml
  rm -f "${x}"
done
echo '</testsuite>' >> overall.xml
