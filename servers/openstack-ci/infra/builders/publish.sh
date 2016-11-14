#!/bin/bash

set -o xtrace
set -o errexit

echo "PACKAGENAME=${DIST}:${GERRIT_PROJECT##*/}"
case "${REPO_TYPE}" in
        rpm|deb) bash -ex "publisher.v5/publish-${REPO_TYPE}-binaries.sh" ;;
         * ) echo "Unsupported repository type" ; exit 1 ;;
esac
