#!/bin/bash -ex
# Required parameters:
# - FUELMAIN_COMMIT         commit for fuel-main
# - fuelmain_gerrit_commit  (array) refspecs for commits in fuel-main gerrit
# - NOARTIFACT_MIRROR       upstream mirror without late artifacts (??)
# - EXTRA_RPM_REPOS         additional CentOS repos
# - make_args               (array) additional parameters to make command

export BUILD_DIR="${WORKSPACE}/${JOB_NAME}/build"
export LOCAL_MIRROR="${WORKSPACE}/${JOB_NAME}/local_mirror"
export ARTS_DIR="${WORKSPACE}/artifacts"
export DEPS_DIR="${BUILD_DIR}/deps"
export DESTINATION_DIR="${WORKSPACE}/${JOB_NAME}/late-artifacts"


echo "STEP 1/4. Clean before start"
# =================================

rm -rf "${ARTS_DIR}"
rm -rf "${DEPS_DIR}"
rm -rf "${DESTINATION_DIR}"


echo "STEP 2/4. Apply crunches"
# =============================

git checkout "${FUELMAIN_COMMIT}"
for commit in ${fuelmain_gerrit_commit} ; do
    git fetch https://review.openstack.org/openstack/fuel-main "${commit}" && git cherry-pick FETCH_HEAD
done


echo "STEP 3/4. Make packages-late target"
# ========================================

make deep_clean
# make_args is list of additional args
# shellcheck disable=SC2086
make packages-late ${make_args}

echo "STEP 4/4. Gather results"
# ========================================

# copy pkgs
mkdir -p "${DESTINATION_DIR}"
find "${BUILD_DIR}/packages/rpm/RPMS/" -type f -name '*.rpm' -exec cp -v {} "${DESTINATION_DIR}" \;
ls "${DESTINATION_DIR}"

# create artifact for publisher
# shellcheck disable=SC2129
echo "BUILD_HOST=$(hostname)                                            " >  "${ARTS_DIR}/buildresult.params"
echo "PKG_PATH=${DESTINATION_DIR}                                       " >> "${ARTS_DIR}/buildresult.params"
echo "GERRIT_CHANGE_STATUS=MERGED                                       " >> "${ARTS_DIR}/buildresult.params"
echo "REQUEST_NUM=                                                      " >> "${ARTS_DIR}/buildresult.params"
echo "LP_BUG=                                                           " >> "${ARTS_DIR}/buildresult.params"
echo "IS_SECURITY=false                                                 " >> "${ARTS_DIR}/buildresult.params"
echo "EXTRAREPO=${EXTRA_RPM_REPOS}                                      " >> "${ARTS_DIR}/buildresult.params"
echo "REPO_TYPE=rpm                                                     " >> "${ARTS_DIR}/buildresult.params"
echo "DIST=centos7                                                      " >> "${ARTS_DIR}/buildresult.params"
echo "                                                                  " >> "${ARTS_DIR}/buildresult.params"
echo "# Added for publisher                                             " >> "${ARTS_DIR}/buildresult.params"
echo "ORIGIN=Mirantis                                                   " >> "${ARTS_DIR}/buildresult.params"
echo "IS_UPDATES=true                                                   " >> "${ARTS_DIR}/buildresult.params"
echo "REPO_REQUEST_PATH_PREFIX=                                         " >> "${ARTS_DIR}/buildresult.params"
echo "REPO_BASE_PATH=??                                                 " >> "${ARTS_DIR}/buildresult.params"
# ubuntu section is skipped (it doesn't matter)
# shellcheck disable=SC2129
echo "RPM_OS_REPO_PATH=mos-repos/centos/mos8.0-centos7/os               " >> "${ARTS_DIR}/buildresult.params"
echo "RPM_PROPOSED_REPO_PATH=mos-repos/centos/mos8.0-centos7/proposed   " >> "${ARTS_DIR}/buildresult.params"
echo "RPM_UPDATES_REPO_PATH=mos-repos/centos/mos8.0-centos7/updates     " >> "${ARTS_DIR}/buildresult.params"
echo "RPM_SECURITY_REPO_PATH=mos-repos/centos/mos8.0-centos7/security   " >> "${ARTS_DIR}/buildresult.params"
echo "RPM_HOLDBACK_REPO_PATH=mos-repos/centos/mos8.0-centos7/holdback   " >> "${ARTS_DIR}/buildresult.params"
echo "REMOTE_REPO_HOST=perestroika-repo-tst.infra.mirantis.net          " >> "${ARTS_DIR}/buildresult.params"

