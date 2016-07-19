#!/bin/bash

set -o xtrace
set -o errexit

main () {

    test -f mirror.setenvfile && source mirror.setenvfile

    # FIXME: use perestroika from openstack/fuel-mirror
    # checkout fuel-mirror to ${WORKSPACE}/fuel-mirror
    # so docker builder is in ${WORKSPACE}/fuel-mirror/perestroika
    local WRKDIR=${WORKSPACE}/fuel-mirror/perestroika
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
    rm -rf "${HOME}/built_packages/*"

    # Create images
    for image in mockbuild sbuild ; do
        if ! docker inspect "${image}:latest" > /dev/null 2>&1; then
            docker build -t "${image}" "${_dpath}/${image}/"
        fi
    done

    # Create or update chroots
    local _rpmchroots
    _rpmchroots="$(ls -1 /var/cache/docker-builder/mock/cache/)"
    for target in $(find "${_dpath}/mockbuild/" -maxdepth 1 -name '*.conf' | egrep -o '[0-9]+') ; do
        if [ "$(echo "${_rpmchroots}" | grep -Fc -e "-${target}-")" -eq 0 ] ; then
            env "DIST=${target}" bash "${_dpath}/create-rpm-chroot.sh"
        else
            env "DIST=${target}" bash "${_dpath}/update-rpm-chroot.sh"
        fi
    done

    local _debchroots
    _debchroots="$(ls -1 /var/cache/docker-builder/sbuild/)"
    target='trusty'
    if [ "$(echo "${_debchroots}" | grep -Fc -e "${target}")" -eq 0 ] ; then
        env "DIST=${target}" "UPSTREAM_MIRROR=${UBUNTU_MIRROR_URL}" bash "${_dpath}/create-deb-chroot.sh"
    else
        env "DIST=${target}" bash "${_dpath}/update-deb-chroot.sh"
    fi

    # Init chroots for new version of perestroika
    # `init` instead of `update` due to CentOS7 rolling release
    if [ -f "${WRKDIR}/build" ] ; then
        local _confpath="${WRKDIR}/conf"
        while read -r conffile ; do
            local confname=${conffile##*/}
            local confname=${confname/.conf}
            [ "$confname" == "common" ] && continue
            "${WRKDIR}/build" \
                --dist "${confname}" \
                --init \
                --verbose
        done < <(find "${_confpath}" -name "*.conf")
    fi
}

main "${@}"

exit 0
