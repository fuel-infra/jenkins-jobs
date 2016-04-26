#!/bin/bash -ex

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
MAGNET_LINK_ISO_8_0='magnet:?xt=urn:btih:4709616bca3e570a951c30b7cf9ffeb2c0359f5c&dn=MirantisOpenStack-8.0.iso&tr=http%3A%2F%2Ftracker01-bud.infra.mirantis.net%3A8080%2Fannounce&tr=http%3A%2F%2Ftracker01-scc.infra.mirantis.net%3A8080%2Fannounce&tr=http%3A%2F%2Ftracker01-msk.infra.mirantis.net%3A8080%2Fannounce&ws=http%3A%2F%2Fvault.infra.mirantis.net%2FMirantisOpenStack-8.0.iso'
MAGNET_LINK_JENKINS_URL=${MAGNET_LINK_JENKINS_URL:-https://product-ci.infra.mirantis.net/}
MAGNET_LINK_ISO_VERSION=${MAGNET_LINK_ISO_VERSION:-9.0}

# exit if ENABLE_ISO_DOWNLOAD not 'true'
[[ "${ENABLE_ISO_DOWNLOAD}" == "true" ]] || exit

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

    release-*)
        RELEASE_ISO_VERSION="${MAGNET_LINK##release-}"
        MAGNET_LINK_VARIABLE="MAGNET_LINK_ISO_${RELEASE_ISO_VERSION/\./_}"
        if [[ -n "${!MAGNET_LINK_VARIABLE}" ]]; then
            MAGNET_LINK="${!MAGNET_LINK_VARIABLE}"
        else
            echo "Not defined ${MAGNET_LINK_VARIABLE} for released ${MAGNET_LINK_ISO_VERSION} ISO"
            exit 1
        fi
    ;;

    http*)
        export $(curl -sSf "${MAGNET_LINK}")
    ;;
esac

if [[ -z "${MAGNET_LINK}" ]]; then
    echo "Missing MAGNET_LINK, it is required to start ISO download"
    exit 1
fi

# Download ISO
ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")
ISO_VERSION_STRING=$(readlink "${ISO_PATH}" | sed -n -e 's/^.*\(fuel\)\(-community\|-gerrit\)\?-\([0-9.]\+-[0-9]\+\).*/\3/p')

# save it as inject variables
cat > iso.setenvfile <<EOF
ISO_PATH=${ISO_PATH}
ISO_VERSION_STRING=${ISO_VERSION_STRING}
EOF

if [[ ! -L "${ISO_PATH}" ]]; then
  echo "ISO not found"
  exit -1
fi
