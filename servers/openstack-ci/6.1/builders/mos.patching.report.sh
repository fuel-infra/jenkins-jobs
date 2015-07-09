#!/bin/bash -ex
function retry {
    local count=$1; shift
    local ec
    while [[ "$count" -gt 0 && "$ec" != 0 ]]
    do
        "$@" && true
        ec=$?
        sleep 5
        ((count--))
    done
    return "$ec"
}
HOST="https://errata-tst.infra.mirantis.net"
APPNAME="${ERRATA_USER}"
ACCESSTOKEN="${ERRATA_PASSWORD}"
if echo "${GERRIT_BRANCH}" | fgrep fuel ; then
    RELEASE="$(echo "${GERRIT_BRANCH}" | egrep -o 'fuel-[0-9.]*' | egrep -o '[0-9.]*' | cat)"
else RELEASE="${GERRIT_BRANCH}"
fi

if [ "${UPDATES}" ] && [ -f "project.envfile" ] ; then
    source project.envfile
    if echo "${JOB_NAME}" | fgrep deb ; then
        DISTR="Ubuntu"
    elif echo "${JOB_NAME}" | fgrep rpm ; then
        DISTR="Centos"
    fi
    retry 3 curl -H "X-Auth-Application: ${APPNAME}" -H "X-Auth-Token: ${ACCESSTOKEN}" -X POST -d "launchpad=${LP_BUG}&release=${RELEASE}&distro=${DISTR}&package=${PACKAGENAME}&version=${PACKAGEVERSION}&git_commit=${GERRIT_PATCHSET_REVISION}&git _project=${GERRIT_PROJECT}" "${HOST}/api/package/update.json?"
fi
