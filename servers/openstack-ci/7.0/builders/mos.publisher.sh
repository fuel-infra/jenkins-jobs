#!/bin/bash

set -o xtrace
set -o errexit

case "${REPO_TYPE}" in
        rpm) bash -ex publisher.v4/publish-rpm-binaries.sh ;;
        deb) bash -ex publisher.v4/publish-deb-binaries.sh ;;
         * ) echo "Unsupported repository type" ; exit 1 ;;
esac

export REPO_PATH_PREFIX=osci/
export REPO_REQUEST_PATH_PREFIX=osci/review/
export BASE_PATH=base/
export UPDATES_PATH=updates/
export SECURITY_PATH=security/

case "${REPO_TYPE}" in
    rpm) bash publisher/publish-rpm-binaries.sh ;;
      *) bash publisher/publish-deb-binaries.sh ;;
esac
