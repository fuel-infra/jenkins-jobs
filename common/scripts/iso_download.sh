#!/bin/bash
set -ex
#
# Script used to download ISO, it requires MAGNET_LINK
# variable to work correctly.
#
# Required variables:
#  ENABLE_ISO_DOWNLOAD - general check, must be 'true' for this script work,
#                        needed for smart invoke current script using inject
#                        from previous scripts in the job
#  MAGNET_LINK         - ISO source, it could contain strings started with:
#   http*              - download magnet link from this link
#   magnet:*           - ISO will be downloaded directly from this link
#   latest             - download latest ISO build from jenkins in
#                        MAGNET_LINK_JENKINS_URL, this allow to download last
#                        version of ISO, even if not pass BVT tests
#   latest-stable      - download latest tested ISO build from jenkins
#                        MAGNET_LINK_JENKINS_URL,
#                        this allow to download lastes BVT tested version of ISO
#   release-*          - this allow to download released version of ISO, it
#                        should contain ISO
#                        version in name, like release-8.0
#
# Optional variables:
#  MAGNET_LINK_JENKINS_URL - jenkins server used to build ISO and as a source
#                            of magnet link artifact, this variable is optional
#                            and by default use product-ci
#  MAGNET_LINK_ISO_VERSION - ISO version, this is name used in jenkins job and
#                            is used to construct download URL, it is optional
#                            and by default should point to latest MOS
#

# set defaults
ENABLE_ISO_DOWNLOAD=${ENABLE_ISO_DOWNLOAD:-true}
MAGNET_LINK_JENKINS_URL=${MAGNET_LINK_JENKINS_URL:-https://product-ci.infra.mirantis.net/}
MAGNET_LINK_ISO_VERSION=${MAGNET_LINK_ISO_VERSION:-9.0}

# exit if ENABLE_ISO_DOWNLOAD not 'true'
[[ "${ENABLE_ISO_DOWNLOAD}" == "true" ]] || exit

# Check whether we want to download released ISO from known source
if [[ "${MAGNET_LINK}" =~ release-* ]]; then
    RELEASE_ISO_VERSION="${MAGNET_LINK##release-}"

    case "${RELEASE_ISO_VERSION}" in
        6.1)
            MAGNET_LINK='http://seed.fuel-infra.org/fuelweb-release/MirantisOpenStack-6.1.iso.torrent'
        ;;

        7.0)
            MAGNET_LINK='http://seed.fuel-infra.org/fuelweb-release/MirantisOpenStack-7.0.iso.torrent'
        ;;

        8.0)
            MAGNET_LINK='http://seed.fuel-infra.org/fuelweb-release/MirantisOpenStack-8.0.iso.torrent'
        ;;

        9.0)
            MAGNET_LINK='http://seed.fuel-infra.org/fuelweb-release/MirantisOpenStack-9.0.iso.torrent'
        ;;

        *)
            echo "Not defined ISO source for ${RELEASE_ISO_VERSION}"
        ;;
    esac
fi

# Check whether we want to download ISO in automatic way
case "${MAGNET_LINK}" in
    latest|latest-stable)
        if [[ ! "${MAGNET_LINK_JENKINS_URL}" =~ ^http ]]; then
            echo "MAGNET_LINK_JENKINS_URL must contains URL adress of jenkins server"
            exit 1
        fi
        if [[ -z "${MAGNET_LINK_ISO_VERSION}" ]]; then
            echo "MAGNET_LINK_ISO_VERSION must contains ISO version"
            exit 1
        fi

        # Construct URL used to download magnet_link artifact
        case "${MAGNET_LINK}" in
            latest)
                MAGNET_LINK_ARTIFACT="${MAGNET_LINK_JENKINS_URL}/job/${MAGNET_LINK_ISO_VERSION}.all/lastSuccessfulBuild/artifact/artifacts/magnet_link.txt"
            ;;
            latest-stable)
                MAGNET_LINK_ARTIFACT="${MAGNET_LINK_JENKINS_URL}/job/${MAGNET_LINK_ISO_VERSION}.test_all/lastSuccessfulBuild/artifact/magnet_link.txt"
            ;;
            *)
                echo "Unknown option for MAGNET_LINK"
                exit 1
            ;;
        esac
        export $(curl -sSf "${MAGNET_LINK_ARTIFACT}")
    ;;

    http*.txt)
        export $(curl -sSf "${MAGNET_LINK}")
    ;;
esac

if [[ -z "${MAGNET_LINK}" ]]; then
    echo "Missing MAGNET_LINK, it is required to start ISO download"
    exit 1
fi

# Download ISO
ISO_PATH=$(seedclient.py -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

# Detect version of downloaded ISO, name examples:
# - fuel-9.0-community-4161-2016-05-13_10-26-43.iso - new community builds
# - fuel-community-6.1-741-2016-05-13_04-59-02.iso  - old community builds
# - fuel-9.0-custom-161-2016-05-13_11-03-31.iso     - new custom builds
# - fuel-gerrit-7.0-1345-2016-03-31_09-35-03.iso    - old custom builds
# - fuel-9.0-317-2016-05-13_08-00-00.iso            - product builds
# - fuel-9.0-mos-356-2016-05-13_06-18-00.iso        - product builds with suffix
#
# This code will represent ISO version in standarized format:
#  {MOS_VERSION}-{SUFFIX}-{BUILD}
#
# Where:
#  MOS_VERSION - version of MOS
#  SUFFIX      - additional suffix for MOS
#  BUILD       - ISO build number
#
# Example:
#  9.0-317            - for fuel-9.0-317-2016-05-13_08-00-00.iso
#  9.0-mos-356        - for fuel-9.0-mos-356-2016-05-13_06-18-00.iso
#  9.0-community-4161 - for fuel-9.0-community-4161-2016-05-13_10-26-43.iso
#  6.1-community-741  - for fuel-community-6.1-741-2016-05-13_04-59-02.iso


ISO_VERSION_STRING=$(readlink "${ISO_PATH}" | \
    sed -n -r 's/^.*fuel(-[a-z]+)?-([0-9.]+)(-[a-z]+)?(-[0-9]+).*/\2\1\3\4/p')

# save it as inject variables
cat > iso.setenvfile <<EOF
ISO_PATH=${ISO_PATH}
ISO_VERSION_STRING=${ISO_VERSION_STRING}
EOF

if [[ ! -L "${ISO_PATH}" ]]; then
  echo "ISO not found"
  exit -1
fi
