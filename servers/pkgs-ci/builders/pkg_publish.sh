#!/bin/bash

set -xe

# Remove stale artifacts
rm -vf ./*.publish.setenvfile pkg-versions.*

# FIXME: use perestroika from openstack/fuel-mirror
# checkout fuel-mirror to ${WORKSPACE}/fuel-mirror
# and then copy perestroika directory to root ${WORKSPACE}

cp -rv "${WORKSPACE}/fuel-mirror/perestroika/"* "${WORKSPACE}"

# Guess Origin if not set
if [ -z "${ORIGIN}" ] ; then
    case "${GERRIT_CHANGE_STATUS}" in
        MERGED)
            ORIGIN="${DEB_ORIGIN_RELEASE}"
        ;;
        REF_UPDATED)
            ORIGIN="${DEB_ORIGIN_RELEASE}"
        ;;
        *)
            ORIGIN="${DEB_ORIGIN_TEST}"
        ;;
    esac
fi

export ORIGIN
/bin/bash -xe "publisher.v5/publish-${REPO_TYPE}-binaries.sh"