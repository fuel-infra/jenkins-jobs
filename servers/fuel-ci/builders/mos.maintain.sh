#!/bin/bash

set -o xtrace
set -o errexit

main () {
    local WRKDIR=$(pwd)/perestroika
    [ -d "${WRKDIR}/docker-builder" ] && local _dpath="${WRKDIR}/docker-builder" || exit 1

    # Aborted containers cleanup
    docker ps -a | grep -F -e "Exited" -e "Dead" | cut -d ' ' -f 1 | xargs -I% docker rm %

    # Clean up all build related containers
    # FIXME: There is no way to properly detect lifetime of the container, so
    #        remove all build containers
    docker ps -a \
        | egrep " (mock|s)build:latest" \
        | cut -d ' ' -f 1 \
        | xargs -I% docker rm -f %

    # Unpublished packages cleanup
    rm -rf "${HOME}"/built_packages/

    # we MUST use external DNS
    echo "DNSPARAM=\"--dns 8.8.8.8\"" > "${_dpath}"/config

    # Create images
    local _images="$(docker images | grep -F -e "build" | cut -d ' ' -f 1)"
    for image in mockbuild sbuild ; do
        [ "$(echo "${_images}" | grep -Fc -e "${image}")" -eq 0 ] && docker build -t "${image}" "${_dpath}/${image}/"
    done

    # Create or update chroots
    local _rpmchroots="$(ls -1 /var/cache/docker-builder/mock/cache/)"
    TARGET_CENTOS_DISTS=(7)
    for target in "${TARGET_CENTOS_DISTS[@]}" ; do
        if [ "$(echo "${_rpmchroots}" | grep -Fc -e "-${target}-")" -eq 0 ] ; then
            env "DIST=${target}" bash "${_dpath}/create-rpm-chroot.sh"
        else
            env "DIST=${target}" bash "${_dpath}/update-rpm-chroot.sh"
        fi
    done

    local _debchroots="$(ls -1 /var/cache/docker-builder/sbuild/)"
    TARGET_UBUNTU_DISTS=(trusty)
    for target in "${TARGET_UBUNTU_DISTS[@]}"; do
        if [ "$(echo "${_debchroots}" | grep -Fc -e "${target}")" -eq 0 ] ; then
            env "DIST=${target}" bash "${_dpath}/create-deb-chroot.sh"
        else
            env "DIST=${target}" bash "${_dpath}/update-deb-chroot.sh"
        fi
    done
}

main "${@}"

exit 0
