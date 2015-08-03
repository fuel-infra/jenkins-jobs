#!/bin/bash

set -o xtrace
set -o errexit

case "${REPO_TYPE}" in
    rpm) bash publisher.v4/publish-rpm-binaries.sh ;;
    deb) bash publisher.v4/publish-deb-binaries.sh ;;
esac
