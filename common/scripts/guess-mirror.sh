#!/bin/bash

set -o xtrace

# fixme: this section is for disabling our mirror snapshots for xenial builds, need rework
if [ "${GUESS_MIRROR:-true}" == false ] ; then

    echo > mirror.setenvfile
    echo > mirror.jenkins-injectfile
    exit 0
fi

###################### Guess mirror host ###############

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location || :)
LOCATION=${LOCATION_FACT:-bud}

case "${LOCATION}" in
    poz|bud|budext|undef)
        MIRROR_HOST="mirror.seed-cz1.fuel-infra.org"
        LOCATION="cz"
        ;;
    mnv|scc|sccext)
        MIRROR_HOST="mirror.seed-us1.fuel-infra.org"
        LOCATION="usa"
        ;;
    *)
        MIRROR_HOST="mirror.fuel-infra.org"
esac

###################### Get MIRROR_CENTOS ###############

CENTOS_MIRROR_ID=${CENTOS_MIRROR_ID:-latest}
CENTOS_VERSION=${CENTOS_VERSION:-7.2.1511}

if [ -z "${MIRROR_CENTOS}" ]; then
    if [ "${CENTOS_MIRROR_ID}" == 'latest' ]; then
        CENTOS_MIRROR_ID=$(curl -sSf "http://${MIRROR_HOST}/pkgs/snapshots/centos-${CENTOS_VERSION}-latest.target.txt" | sed '1p;d')
    fi
    MIRROR_CENTOS="http://${MIRROR_HOST}/pkgs/snapshots/${CENTOS_MIRROR_ID}/"
fi

###################### Get MIRROR_UBUNTU ###############

# If UBUNTU_MIRROR_ARTIFACT is set get UBUNTU_MIRROR_ID from artifact
if [[ -n "${UBUNTU_MIRROR_ARTIFACT}" ]]; then
    export $(curl -sSf "${UBUNTU_MIRROR_ARTIFACT}")
fi

UBUNTU_MIRROR_ID=${UBUNTU_MIRROR_ID:-latest}
UBUNTU_DIST=${UBUNTU_DIST:-trusty}

# By default disable Ubuntu proposed repository
ENABLE_UBUNTU_PROPOSED=${ENABLE_UBUNTU_PROPOSED:-false}

if [ -z "${MIRROR_UBUNTU}" ]; then
    if [ "${UBUNTU_MIRROR_ID}" = "latest" ]; then
        UBUNTU_MIRROR_ID=$(curl -sSf "http://${MIRROR_HOST}/pkgs/snapshots/ubuntu-${UBUNTU_MIRROR_ID}.target.txt" | sed '1p;d')
    fi
    UBUNTU_MIRROR_URL="http://${MIRROR_HOST}/pkgs/snapshots/${UBUNTU_MIRROR_ID}/"

    MIRROR_UBUNTU="deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST} main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-security main universe multiverse"

    # Add proposed repository only when required
    if [[ "${ENABLE_UBUNTU_PROPOSED}" = true ]]; then
        MIRROR_UBUNTU="${MIRROR_UBUNTU}|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-proposed main universe multiverse"
    fi
fi

# Save parameters to file in format required by source in bash
cat > mirror.setenvfile <<EOF
MIRROR_HOST="${MIRROR_HOST}"
MIRROR_CENTOS="${MIRROR_CENTOS}"
UBUNTU_MIRROR_URL="${UBUNTU_MIRROR_URL}"
MIRROR_UBUNTU="${MIRROR_UBUNTU}"
EOF
# Save parameters to file in format required by jenkins inject
cat > mirror.jenkins-injectfile <<EOF
MIRROR_HOST=${MIRROR_HOST}
MIRROR_CENTOS="${MIRROR_CENTOS}"
UBUNTU_MIRROR_URL=${UBUNTU_MIRROR_URL}
MIRROR_UBUNTU=${MIRROR_UBUNTU}
EOF
