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
    srt)
        MIRROR_HOST="osci-mirror-srt.srt.mirantis.net"
        ;;
    msk)
        MIRROR_HOST="osci-mirror-msk.msk.mirantis.net"
        ;;
    kha)
        MIRROR_HOST="osci-mirror-kha.kha.mirantis.net"
        LOCATION="hrk"
        ;;
    poz|bud|bud-ext|undef)
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

###################### Get MIRROR_UBUNTU ###############

# If UBUNTU_MIRROR_ARTIFACT is set get UBUNTU_MIRROR_ID from artifact
if [[ -n "${UBUNTU_MIRROR_ARTIFACT}" ]]; then
    export $(curl -sSf "${UBUNTU_MIRROR_ARTIFACT}")
fi

UBUNTU_MIRROR_ID=${UBUNTU_MIRROR_ID:-latest}
UBUNTU_DIST=${UBUNTU_DIST:-trusty}

if [ -z "${MIRROR_UBUNTU}" ]; then
    if [ "${UBUNTU_MIRROR_ID}" = "latest" ]; then
        UBUNTU_MIRROR_URL=$(curl -fLsS "http://${MIRROR_HOST}/pkgs/ubuntu-latest.htm")
    else
        UBUNTU_MIRROR_URL="http://${MIRROR_HOST}/pkgs/${UBUNTU_MIRROR_ID}/"
    fi
    MIRROR_UBUNTU="deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST} main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-security main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-proposed main universe multiverse"
fi

# Save parameters to file in format required by source in bash
cat > mirror.setenvfile <<EOF
MIRROR_HOST="${MIRROR_HOST}"
UBUNTU_MIRROR_URL="${UBUNTU_MIRROR_URL}"
MIRROR_UBUNTU="${MIRROR_UBUNTU}"
EOF
# Save parameters to file in format required by jenkins inject
cat > mirror.jenkins-injectfile <<EOF
MIRROR_HOST=${MIRROR_HOST}
UBUNTU_MIRROR_URL=${UBUNTU_MIRROR_URL}
MIRROR_UBUNTU=${MIRROR_UBUNTU}
EOF
