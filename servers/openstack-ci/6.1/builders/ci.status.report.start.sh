#!/bin/bash -ex
export GERRIT_USER="openstack-ci-jenkins"
GERRIT_BRANCH=${GERRIT_BRANCH:-"$SOURCEBRANCH"}
if echo "${GERRIT_BRANCH}" | fgrep fuel ; then
    RELEASE=$(echo "${GERRIT_BRANCH}" | egrep -o 'fuel-[0-9.]*' | egrep -o '[0-9.]*' | cat)
else RELEASE=${GERRIT_BRANCH}
fi

if echo "${JOB_NAME}" | fgrep deb ; then
    if [ "${RELEASE}" == "6.1" ] || [ "${RELEASE}" == "master" ] ; then
        export REQUEST_TYPE="Trusty"
        else export REQUEST_TYPE="Precise"
    fi
    DISTR="deb"
elif echo "${JOB_NAME}" | fgrep rpm ; then
    export REQUEST_TYPE="Centos6"
    DISTR="rpm"
fi

if echo "${JOB_NAME}" | fgrep install ; then 
    export DISPLAY_NAME="Check ${DISTR} package for installation and simple testing" ;
elif echo "${JOB_NAME}" | fgrep deploy ; then 
    export DISPLAY_NAME="Check ${DISTR} package for installation in environment" ;
elif echo "${JOB_NAME}" | grep build ; then
    CHANGENUMBER=$(echo "${GERRIT_REFSPEC}" | cut -d '/' -f4)
    status=$(ssh "${GERRIT_USER}"@"${GERRIT_HOST}" -p "${GERRIT_PORT}" gerrit query --format=TEXT "${CHANGENUMBER}" | egrep -o " +status:.*" | awk -F': ' '{print $2}')
    if [ "${status}" == "MERGED" ] ; then
        export DISPLAY_NAME="Build ${DISTR} package on primary repository"
    else
        export DISPLAY_NAME="Build ${DISTR} package on temporary repository"
    fi
fi
ci-status-client/ci-status-report.sh start
