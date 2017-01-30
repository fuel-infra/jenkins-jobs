#!/bin/bash
set -ex
# Encryption compliance
[[ "${ONLY_LICENSE_REPORT}" == true ]] && exit 0

create_artifacts () {
    SOURCE_DIR="${1}"
    OUTPUT_FILE="${2}"
    [ -f "${OUTPUT_FILE}" ] && rm "${OUTPUT_FILE}"
    for DIR in "${SOURCE_DIR}"/* ; do
        PROJECTFILE=$(find "${DIR}" -iname project_id)
        if [ "${PROJECTFILE}" ] ; then
            local PROJECT_ID=$(cat "${PROJECTFILE}")
            local PROJECT=$(echo "${PROJECTFILE}" | awk -F"/" '{print $(NF-1)}')
            echo "${PROJECT}:${PROJECT_ID}" >> "${OUTPUT_FILE}"
        fi
    done
}

remove_projects () {
    for i in $(cat "$@") ; do
       project_id=$(echo "${i}" | cut -d':' -f2)
       project=$(echo "${i}" | cut -d':' -f1)
       echo "Remove project ${project}"
       scripts/remove_project.sh "${project_id}"
    done
}

export MIRROR_HOST=${MIRROR_HOST:-"perestroika-repo-tst.infra.mirantis.net"}
export JENKINS_PRODUCT=${JENKINS_PRODUCT:-"https://product-ci.infra.mirantis.net"}
export RPM_DIST_NAME=${RPM_DIST_NAME:-"centos6"}
UPDATES_SUFFIX=''
[[ "$UPDATES" == "true" ]] && export UPDATES_SUFFIX="-updates"
export CENTOS_REPO="mirror/${RELEASE}_rpm_packages${UPDATES_SUFFIX}"
export UBUNTU_REPO="mirror/${RELEASE}_deb_packages${UPDATES_SUFFIX}"
export PROJECT_CENTOS="centos-fuel-$RELEASE-stable${UPDATES_SUFFIX}"
export PROJECT_UBUNTU="ubuntu-fuel-$RELEASE-stable${UPDATES_SUFFIX}"
export PATH_TO_PROJECT_CENTOS="packages/${PROJECT_CENTOS}"
export PATH_TO_PROJECT_UBUNTU="packages/${PROJECT_UBUNTU}"

[ -f projects.tar.gz ] && tar -xvf projects.tar.gz

if "${REMOVE_PROJECTS}" ; then
    for DISTR in CENTOS UBUNTU ; do
        eval PATH_TO_PROJECT=\$"PATH_TO_PROJECT_"${DISTR}
        eval PROJECT=\$"PROJECT_"${DISTR}
        if [ -f "${PROJECT}.txt" ] ; then
            remove_projects "${PROJECT}.txt"
            rm -rf "${PATH_TO_PROJECT}"
        elif [ -d "${PATH_TO_PROJECT}" ] ; then
            SRCDIRS=$(find "${PATH_TO_PROJECT}" -iname project_id)
            if [ -n "$SRCDIRS" ] ; then
                create_artifacts "${PATH_TO_PROJECT}" "${PROJECT}.txt"
                remove_projects "${PROJECT}.txt"
                rm -rf "${PATH_TO_PROJECT}"
            fi
        else echo "ERROR. Can't remove ${PROJECT} projects, because not files with project_id" && exit 1
        fi
    done
    [ $? = 0 ] && exit 0 || exit 1
fi

[ ! -d "packages" ] && mkdir packages
[ ! -d packages/centos-fuel-"${RELEASE}-stable${UPDATES_SUFFIX}"/ ] && mkdir packages/centos-fuel-"${RELEASE}-stable${UPDATES_SUFFIX}"/
[ ! -d packages/ubuntu-fuel-"${RELEASE}-stable${UPDATES_SUFFIX}"/ ] && mkdir packages/ubuntu-fuel-"${RELEASE}-stable${UPDATES_SUFFIX}"/

# Prepare for analysis & analyses
bash -ex full_analyse_rpm.sh centos"${RELEASE}${UPDATES_SUFFIX}".csv
bash -ex full_analyse_deb.sh ubuntu"${RELEASE}${UPDATES_SUFFIX}".csv

create_artifacts "${PATH_TO_PROJECT_CENTOS}" "${PROJECT_CENTOS}".txt
create_artifacts "${PATH_TO_PROJECT_UBUNTU}" "${PROJECT_UBUNTU}".txt
tar -czf projects.tar.gz ./*.txt
