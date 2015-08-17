#!/bin/bash

set -o xtrace
set -o errexit

case "${REPO_TYPE}" in
        rpm) bash -ex publisher.v5/publish-rpm-binaries.sh ;;
        deb) bash -ex publisher.v5/publish-deb-binaries.sh ;;
         * ) echo "Unsupported repository type" ; exit 1 ;;
esac
