#!/bin/bash
#
#   :mod:`fuel-stats-prepare-package-sources` -- wrapper for prepare fuel-stats packages for build
#   ====================================================================
#
#   .. module::fuel-stats-prepare-packages
#       :platform: Ubuntu 14.04
#       :synopsis: building fuel-stats packages from upstream source
#   .. vesionadded:: MOS-10.0
#   .. author:: Dmitry Kaigarodtsev <dkaiharodsev@mirantis.com>
#
#
#   .. envvar::
#       :var      PROJECT: source project name and basename for packages
#       :type     PROJECT: str
#       :default  PROJECT: fuel-stats
#       :var      GERRIT_HOST: FQDN of internal Gerrit
#       :type     GERRIT_HOST: str
#       :default  GERRIT_HOST: review.fuel-infra.org
#       :var      GERRIT_PORT: Number of IP port for SSH connection
#       :type     GERRIT_PORT: str
#       :default  GERRIT_PORT: 29418
#       :var      GERRIT_USER: Username for git
#       :type     GERRIT_USER: str
#       :default  GERRIT_USER: openstack-ci-jenkins
#       :var      GERRIT_USER_MAIL: E-mail for configure git
#       :type     GERRIT_USER_MAIL: str
#       :default  GERRIT_USER_MAIL: oscirobot+openstack-ci-jenkins@mirantis.com
#
#   .. requirements::
#       * vivid kernel
#
#   .. entrypoint:: main
#

set -ex

## variables
PKG_NAMES=(analytics collector migration static)
SRC_DIR="${WORKSPACE}/${PROJECT}-src"

## functions
# clean all package sources
remove_old_package_files () {
  CLEANUP_LIST=$(ls --almost-all -I "specs" -I ".git" -I ".gitreview" "${PKG_FOLDER}")
  for UPDATEBLE_FILE in "${CLEANUP_LIST[@]}"
  do
    rm -Rvf "${PKG_FOLDER}"/"${UPDATEBLE_FILE:?}"
  done
}

# replace pakage files by sources
update_package_sources () {
  if [ "${PKG}" = "static" ]
    # get static code from 'fuel-stats-analitics' to 'fuel-stats-static'
    then
      # download nodejs components for 'fuel-stats-static'
      cd "${SRC_DIR}/analytics/${PKG}"
      npm install
      ./node_modules/gulp/bin/gulp.js bower
      # move all package files from source to package folder
      mv -v "${SRC_DIR}/analytics/${PKG}" "${PKG_FOLDER}/${PROJECT}-${PKG}"
      # remove nodejs temporary folders
      rm -rf "${PKG_FOLDER}/${PROJECT}-${PKG}/node_modules/" "${PKG_FOLDER}/${PKG_NAME}/bower_components"
    else
      # copy all files from source to packages folder
      cp -Rv "${SRC_DIR}"/"${PKG}"/* "${PKG_FOLDER}/"
      if [ "${PKG}" = "analytics" ]
        then
          # remove 'fuel-stats-static' part from 'fuel-stats-analytics' files
          rm -rf "${PKG_FOLDER}/static"
      fi
  fi
}

abandon_old_patchsets () {
  # get list of old patchsets for package
  GERRIT_QUERY=$(ssh -p "${GERRIT_PORT}" "${GERRIT_USER}@${GERRIT_HOST}" \
  gerrit query project:fuel-infra/packages/"${PKG_NAME}" \
  status:open \
  owner:"${GERRIT_USER}" | egrep '^\ +number'| cut -d' ' -f4
  )
  for OLD_REVIEW in ${GERRIT_QUERY}
    do
      # abandon each old patchset
      ssh -p "${GERRIT_PORT}" "${GERRIT_USER}@${GERRIT_HOST}" \
      gerrit review --abandon "${OLD_REVIEW}",1
    done
}

push_packages_to_repositories () {
  COMMIT_MSG="Update '${PKG_NAME}' package up to ${CURRENT_SRC_COMMIT} revision"
  git -C "${PKG_FOLDER}" add --all
  scp -p -P "${GERRIT_PORT}" "${GERRIT_USER}@${GERRIT_HOST}":hooks/commit-msg "${PKG_FOLDER}/.git/hooks/"
  git -C "${PKG_FOLDER}" commit -m "${COMMIT_MSG}" || true
  git -C "${PKG_FOLDER}" push origin HEAD:refs/for/master > "${WORKSPACE}/${PKG_NAME}.log" || true
  if [[ ! -s "${WORKSPACE}/${PKG_NAME}.log" ]]
    # leave some comment for artifact
    then
      echo "No change for package ${PKG_NAME}" > "${WORKSPACE}/${PKG_NAME}.log"
  fi
}

## checks and actions
# 1.set description
CURRENT_SRC_COMMIT=$(git -C "${SRC_DIR}" rev-parse --short HEAD)
echo "Description string:" \
  "${PROJECT} revision: <a href='https://github.com/openstack/${PROJECT}/commit/${CURRENT_SRC_COMMIT}'>${CURRENT_SRC_COMMIT}</a>"

# 2.setup git config
git config --global user.name "${GERRIT_USER}"
git config --global user.email "${GERRIT_USER_MAIL}"

# 3.actions with packages
for PKG in "${PKG_NAMES[@]}"
  do
    # set variables used in functions
    PKG_NAME="${PROJECT}-${PKG}"
    PKG_FOLDER="${WORKSPACE}/${PKG_NAME}"
    # check for specs folder
    if [ ! -d "${PKG_FOLDER}/specs" ]
      then
        echo "ERROR: Couldn't find 'specs' folder in ${PKG_NAME} package repository"
        exit 1
    fi
    remove_old_package_files
    update_package_sources
    abandon_old_patchsets
    push_packages_to_repositories
  done
