#!/bin/bash

set -o xtrace
set -o errexit

case "${REPO_TYPE}" in
    rpm) bash publisher/publish-rpm-binaries.sh ;;
      *) bash publisher/publish-deb-binaries.sh ;;
esac

export REPO_REQUEST_PATH_PREFIX=review/

export RPM_OS_REPO_PATH="mos-repos/centos/${PROJECT_NAME}${PROJECT_VERSION}-centos6-fuel/os"
export RPM_PROPOSED_REPO_PATH="mos-repos/centos/${PROJECT_NAME}${PROJECT_VERSION}-centos6-fuel/cr"
export RPM_UPDATES_REPO_PATH="mos-repos/centos/${PROJECT_NAME}${PROJECT_VERSION}-centos6-fuel/updates"
export RPM_SECURITY_REPO_PATH="mos-repos/centos/${PROJECT_NAME}${PROJECT_VERSION}-centos6-fuel/security"
export RPM_HOLDBACK_REPO_PATH="mos-repos/centos/${PROJECT_NAME}${PROJECT_VERSION}-centos6-fuel/holdback"

export DEB_REPO_PATH="mos-repos/ubuntu"
export DEB_DIST_NAME="${PROJECT_NAME}${PROJECT_VERSION}"
export DEB_PROPOSED_DIST_NAME="${DEB_DIST_NAME}-proposed"
export DEB_UPDATES_DIST_NAME="${DEB_DIST_NAME}-updates"
export DEB_SECURITY_DIST_NAME="${DEB_DIST_NAME}-security"
export DEB_HOLDBACK_DIST_NAME="${DEB_DIST_NAME}-holdback"

case "${REPO_TYPE}" in
        rpm) bash -ex publisher.v4/publish-rpm-binaries.sh ;;
        deb) bash -ex publisher.v4/publish-deb-binaries.sh ;;
         * ) echo "Unsupported repository type" ; exit 1 ;;
esac
