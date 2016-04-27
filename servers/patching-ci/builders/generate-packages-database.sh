#!/bin/bash
set -ex

#################################################
#
# Used variables
#
# RELEASE_VERSION   : Version of MOS
#                   : e.g "7, 8"
#
# DISTRO            : OS type
#                   : e.g. "centos, ubuntu"
#
# IS_UPDATES        : Use to create MU report
#                   : e.g. "true" for scan MU, proposed or security updates
#
# UPDATES_REPO_NAME : Name of MOS component. Only for case IS_UPDATES=true
#                     e.g. "updates" by default, but not used without IS_UPDATE
#
# MU_NUMBER         : Number of Maintenance updates
#
# URLS              : List of URLs separated by "|"
#                   : e.g. centos repo http://mirror.fuel-infra.org/mos-repos/centos/mos7.0-centos6-fuel
#                   : ubuntu repo http://mirror.fuel-infra.org/mos-repos/ubuntu/7.0
#                   : List of all repositories you can see here
#                     https://mirantis.jira.com/wiki/display/PRD/Repository+structure+for+every+release
#

die () {
   echo "$@"
   exit 1
}

##################################################
#
# Initialize variables
#

MOS_COMPONENT="os"
URLS_TO_METADATA=''

if [ "${IS_UPDATES}" == "true" ] ; then
    MU_SUFFIX="-mu-${MU_NUMBER}"
    UPDATES_SUFFIX="-${UPDATES_REPO_NAME}"
    MOS_COMPONENT="mu-${MU_NUMBER}-${UPDATES_REPO_NAME}"
fi

UBUNTU_REPO_SUFFIX="dists/mos${RELEASE_VERSION}${UPDATES_SUFFIX}/main/binary-amd64/Packages"
OUTPUT_FILE="${RELEASE_VERSION}-${DISTRO}${MU_SUFFIX}.sqlite"
OLDIFS="$IFS"
IFS='|'

##################################################
#
# Determine URL to metadata repository
#

for URL in $URLS ; do
    IFS="$OLDIFS"
    case "${DISTRO}" in
       centos)
          wget "${URL}/${MOS_COMPONENT}.target.txt" -O "${RELEASE_VERSION}-${DISTRO}-${MOS_COMPONENT}.target.txt"
          SNAPSHOT=$(head -1 "${RELEASE_VERSION}-${DISTRO}-${MOS_COMPONENT}.target.txt")
          wget "${URL}/${SNAPSHOT}/x86_64/repodata/repomd.xml" -O "${RELEASE_VERSION}-${MOS_COMPONENT}-repomd.xml"
          CENTOS_REPO_FILENAME=$(grep "primary\.sqlite" "${RELEASE_VERSION}-${MOS_COMPONENT}-repomd.xml" |\
              grep location | cut -d '"' -f2)
          REPO_SUFFIX="x86_64/${CENTOS_REPO_FILENAME}"
          BASE_URL="${URL}"
          ;;
       ubuntu)
          wget "${URL}.target.txt" -O "${RELEASE_VERSION}-${DISTRO}-target.txt"
          SNAPSHOT=$(head -1 "${RELEASE_VERSION}-${DISTRO}-target.txt")
          REPO_SUFFIX="${UBUNTU_REPO_SUFFIX}"
          # Remove $RELEASE_VERSION from $URL for Ubuntu repository
          BASE_URL="${URL%$RELEASE_VERSION*}"
          ;;
       *)
          die "Distribution is not defined"
    esac
    URLS_TO_METADATA="${URLS_TO_METADATA} ${BASE_URL}/${SNAPSHOT}/${REPO_SUFFIX}"
done

##################################################
#
# Put variables to setenv file for publish-packages-database job
#

echo "FILE=${OUTPUT_FILE}" > "${WORKSPACE}/filename.properties"
echo "DISTRO=${DISTRO}" >> "${WORKSPACE}/filename.properties"
echo "RELEASE_VERSION=${RELEASE_VERSION}" >> "${WORKSPACE}/filename.properties"

##################################################
#
# Generate repository report
#

if [ "$IS_UPDATES" == "true" ] ; then
    python generate-databases-scripts/generate-db.py -s "${DISTRO}" -r "${RELEASE_VERSION}" \
        -d "${URL_TO_DB}/${RELEASE_VERSION}/${DISTRO}-latest.sqlite" -n "${MU_NUMBER}"\
        -u "${URLS_TO_METADATA}" -o "${OUTPUT_FILE}"
else
    python generate-databases-scripts/generate-db.py -s "${DISTRO}" -r "${RELEASE_VERSION}" \
        -g "${URLS_TO_METADATA}" -o "${OUTPUT_FILE}"
fi
