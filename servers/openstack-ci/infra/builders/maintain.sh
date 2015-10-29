#!/bin/bash

set -o xtrace
set -o errexit

main () {
    local WRKDIR=$(pwd)
    [ -d "${WRKDIR}/build" ] && local _builderpath="${WRKDIR}/build" || exit 1

    # Aborted containers cleanup
    docker ps -a | grep -F -e "Exited" | cut -d ' ' -f 1 | xargs -I% docker rm %

    # Unpublished packages cleanup
    rm -rf "${HOME}/built_packages"

    # Init chroots for new version of perestroika
    # `init` instead of `update` due to CentOS7 rolling release
    local _confpath="${_builderpath}/conf"
    while read -r conffile ; do
        local confname=${conffile##*/}
        local confname=${confname/.conf}
        [ "$confname" == "common" ] && continue
        "${_builderpath}/build" \
            --dist "${confname}" \
            --init \
            --verbose
    done < <(find "${_confpath}" -name "*.conf")
}

main "${@}"

exit 0
