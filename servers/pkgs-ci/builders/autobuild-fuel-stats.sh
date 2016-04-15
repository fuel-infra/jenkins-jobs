#!/bin/bash
#
#   :mod:`autobuild-fuel-stats` -- A Wrapper for building fuel-stats packages
#   ====================================================================
#
#   .. module::autobuild-fuel-stats
#       :platform: Ubuntu 14.04
#       :synopsis: building fuel-stats packages
#   .. vesionadded:: MOS-9.0
#   .. author:: Alexey Golubev <agolubev@mirantis.com>
#
#
#   .. envvar::
#       :var      GERRIT_HOST: FQDN of internal Gerrit
#       :type     GERRIT_HOST: str
#       :default  GERRIT_HOST: review.fuel-infra.org
#       :var      EXT_GERRIT_HOST: FQDN of upstream Gerrit
#       :type     EXT_GERRIT_HOST: str
#       :default  EXT_GERRIT_HOST: review.openstack.org
#       :var      GERRIT_PORT: Number of IP port for SSH connection
#       :type     GERRIT_PORT: str
#       :default  GERRIT_PORT: 29418
#       :var      GERRIT_USER: Username for git
#       :type     GERRIT_USER: str
#       :default  GERRIT_USER: openstack-ci-jenkins
#       :var      COMMIT_MSG: Commit message for git
#       :type     GERRIT_MSG: str
#       :default  COMMIT_MSG: "Autobuild patchset ${{BUILD_NUMBER}}"
#       :var      GERRIT_USER_MAIL: E-mail for configure git
#       :type     GERRIT_USER_MAIL: str
#       :default  GERRIT_USER_MAIL: oscirobot+openstack-ci-jenkins@mirantis.com
#       :var      FUELMAIN_COMMIT: commit for fuel-main
#       :type     FUELMAIN_COMMIT: refspec:str
#       :var      BUILD_NUMBER: Number of build Jenkins Job
#       :type     BUILD_NUMBER: str
#       :var      WORKSPACE: Location where build is started, defaults to ``.``
#       :type     WORKSPACE: path
#
#   .. requirements::
#       * vivid kernel
#
#   .. entrypoint:: main
#

set -ex

export STAT_TYPES=(analytics collector migration static)
export SRC_DIR="${WORKSPACE}/orig"
export PROJECTS="fuel-stats"


main () {
 git config user.email "${GERRIT_USER_MAIL}"
 git clone "https://${EXT_GERRIT_HOST}/openstack/${PROJECTS}" "${SRC_DIR}"

 for STAT_TYPE in "${STAT_TYPES[@]}"; do
     export PRJ_DIR="${WORKSPACE}/${PROJECTS}-${STAT_TYPE}"
     mkdir "${PRJ_DIR}"
     git clone ssh://"${GERRIT_USER}@${GERRIT_HOST}:${GERRIT_PORT}/fuel-infra-packages/${PROJECTS}-${STAT_TYPE}.git" "${PRJ_DIR}"
     pushd "${PRJ_DIR}"
     if [ "${STAT_TYPE}" != "static" ]; then
         # Update data in the package repository with that from the project one
         mv "${PROJECTS}-${STAT_TYPE}/"* "${PRJ_DIR}"
         rm -rf "${PROJECTS}-${STAT_TYPE}-${PKG_VERSION}"/*
         cp -r "${SRC_DIR}/${STAT_TYPE}/"* "${PROJECTS}-${STAT_TYPE}-${PKG_VERSION}/"
         if [ "$STAT_TYPE" = "analytics" ]; then
             rm -rf "${PROJECTS}-${STAT_TYPE}-${PKG_VERSION}/static"
         fi
     else
         pushd "${SRC_DIR}/analytics/static"
         npm install
         ./node_modules/gulp/bin/gulp.js bower
         rm -rf "${PRJ_DIR}/src/${PROJECTS}-static-${PKG_VERSION}/${PROJECTS}-static/static"
         cp -r "${SRC_DIR}/analytics/static" "${PRJ_DIR}/src/${PROJECTS}-static-${PKG_VERSION}/${PROJECTS}-static/"
     fi

     # Update version in debian/changelog
     pushd "${PRJ_DIR}/debian"
     dch -v "${PKG_VERSION}.$(date +%Y%m%d%H%M)" 'Automatic package update'

     # Change directory to "${PRJ_DIR}"
     popd

     # Abandon open requests in the packages repository
     for i in $(ssh -p "${GERRIT_PORT}" "${GERRIT_USER}@${GERRIT_HOST}" gerrit query\
                project:fuel-infra-packages/${PROJECTS}-${STAT_TYPE}\
                status:open owner: openstack-ci-jenkins | egrep '^\ +number'| cut -d' ' -f4); do
         ssh -p "${GERRIT_PORT}" "${GERRIT_USER}@${GERRIT_HOST}" gerrit review --abandon "${i}",1
     done

     # Commit the latest changes
     gitdir="$(git rev-parse --git-dir)"
     scp -p -P "${GERRIT_PORT}" "${GERRIT_USER}@${GERRIT_HOST}":hooks/commit-msg "${gitdir}/hooks/"
     git add --all
     git commit -m "${COMMIT_MSG}"
     git push origin HEAD:refs/for/master 2>&1 | tee "${BUILD_TAG}-${STAT_TYPE}.log"
     awk '/^remote:[ \t]*https/ print $2' "${BUILD_TAG}-${STAT_TYPE}.log" > "${WORKSPACE}/${BUILD_TAG}-${STAT_TYPE}.txt"
 done
}

if [ "$0" == "${BASH_SOURCE}" ] ; then
    main "${@}"
fi
