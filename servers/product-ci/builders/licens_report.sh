#!/bin/bash
set -ex

create_deb_repos () {
    DSC_DIR=$1
    SNAPSHOT=$2
    PROJECT_VERSION="${RELEASE}"
    REMOTE_PATH=/mos-repos/ubuntu/${PROJECT_VERSION}
    FILES_DIR=snapshots
    PROJECT_NAME=mos
    UPDATES=${UPDATES:-''}
    SUITE="${PROJECT_NAME}${PROJECT_VERSION}"
    REPO_NAME="${PROJECT_NAME}${PROJECT_VERSION}"
    [[ "$UPDATES" == "true" ]] && SUITE="${SUITE}-${UPDATES_REPO_NAME}" && REPO_NAME="${UPDATES_REPO_NAME}" && DSC_DIR="${DSC_DIR}"
    # Getting copy of proposed repository of given snapshot
    [ -d "${WRK_DIR}/${DSC_DIR}" ] && rm -rf "${WRK_DIR}/${DSC_DIR}"
    mkdir -p "${WRK_DIR}/${DSC_DIR}"/conf
    cat >"${WRK_DIR}/${DSC_DIR}"/conf/distributions<<-EOF
	Origin: Mirantis
	Label: ${PROJECT_NAME}
	Suite: ${SUITE}
	Codename: ${REPO_NAME}
	Update: ${REPO_NAME}
	Architectures: amd64 i386 source
	Components: main restricted
	UDebComponents: main restricted
	Contents: . .gz .bz2
	EOF
    cat >"${WRK_DIR}/${DSC_DIR}"/conf/updates<<-EOF
	Name: ${REPO_NAME}
	Suite: ${SUITE}
	VerifyRelease: blindtrust
	Components: main restricted
	Method: http://${MIRROR_HOST%% *}${REMOTE_PATH%/*}/${FILES_DIR}/${SNAPSHOT}
	EOF
    REPREPRO_OPTS="--verbose --basedir "${WRK_DIR}/${DSC_DIR}" --dbdir +b/db --outdir +b/public/ --distdir +b/public/dists/ --confdir +b/conf"
    #need pass all components as separate arguments
    # shellcheck disable=SC2086
    reprepro $REPREPRO_OPTS export
    # shellcheck disable=SC2086
    reprepro $REPREPRO_OPTS update
}

[[ "${REMOVE_PROJECTS}" == "true" ]] && exit 0

export WRK_DIR=$(pwd)
MIRROR_HOST=${MIRROR_HOST:-"mirror.fuel-infra.org"}
export RPM_DIST_NAME=${RPM_DIST_NAME:-"centos7"}
BASE="os"
UPDATES_SUFFIX=''
UPDATES_REPO_NAME=${UPDATES_REPO_NAME:-"updates"}

[[ "$UPDATES" == "true" ]] && export UPDATES_SUFFIX="-updates" && export BASE="${UPDATES_REPO_NAME}"
export UBUNTU_REPO=mirror/"${RELEASE}_deb_packages${UPDATES_SUFFIX}"
export CENTOS_REPO=mirror/"${RELEASE}_rpm_packages${UPDATES_SUFFIX}"

[ ! -d "mirror" ] && mkdir mirror
RSYNC_OPTIONS="-avPzt --delete --chmod=a+rx"

if [ "${DIRECT_LINKS}" != true ] ; then
    DEB_SNAPSHOT=$(rsync -l "rsync://${MIRROR_HOST}/mirror/mos-repos/ubuntu/${RELEASE}" | awk '{print $7}' | cut -d'/' -f2)
    RPM_SNAPSHOT=$(rsync -l "rsync://${MIRROR_HOST}/mirror/mos-repos/centos/mos${RELEASE}-${RPM_DIST_NAME}/${BASE}" | awk '{print $7}' | cut -d'/' -f2)
else
    DEB_SNAPSHOT=$(echo "${DEB_URL}" | awk -F'/' '{print $(NF-1)}')
    RPM_SNAPSHOT=$(echo "${RPM_URL}" | awk -F'/' '{print $(NF-1)}')
fi

# Copy src and bin packages for analyse from mirrors
create_deb_repos "${UBUNTU_REPO}" "${DEB_SNAPSHOT}"
# need pass all components as separate arguments
# shellcheck disable=SC2086
rsync ${RSYNC_OPTIONS} rsync://"${MIRROR_HOST}/mirror/mos-repos/centos/mos${RELEASE}-${RPM_DIST_NAME}/snapshots/${RPM_SNAPSHOT}"/ "${CENTOS_REPO}"

# Create License Report with delimited |||
license-compliance/rpm_license.sh "${CENTOS_REPO}"/x86_64/Packages/* > license_mos_"${RELEASE}${UPDATES_SUFFIX}"_centos
license-compliance/deb_license.sh "${UBUNTU_REPO}"/public/pool/main/* > license_mos_"${RELEASE}${UPDATES_SUFFIX}"_ubuntu
