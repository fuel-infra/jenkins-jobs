#!/bin/bash

set -o xtrace
set -o errexit

case "${REPO_TYPE}" in
    rpm) bash publisher/publish-rpm-binaries.sh ;;
      *) bash publisher/publish-deb-binaries.sh ;;
esac
