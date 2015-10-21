#!/bin/bash

set -ex

REPOS_PATH="${WORKSPACE}/build-fuel-packages/repos/"
rm -rf "${REPOS_PATH}"
mkdir -p "${REPOS_PATH}"

build_repo() {

  # we preparing repos for build in case we are not on master branch
  # or have gerrit_patchsets defined
  if [ "$3" != "master" ] || [ "$5" != "none" ] ; then
    #Clone everything and checkout to branch (or hash)
    git clone "$2" "${REPOS_PATH}/$1" && (cd "${REPOS_PATH}/$1" && git checkout -q "$3")

    # we have some patchsets
    if [ "$5" != "none" ]; then
      for patchset in $5; do
        cd "${REPOS_PATH}/$1" && git fetch "$4" "$patchset" && git cherry-pick FETCH_HEAD
      done
    fi
  fi
}

# Gerrit URLs and commits
ASTUTE_GERRIT_URL=https://review.openstack.org/openstack/fuel-astute
FUEL_AGENT_GERRIT_URL=https://review.openstack.org/openstack/fuel-agent
FUEL_MAIN_GERRIT_URL=https://review.openstack.org/openstack/fuel-main
FUEL_MIRROR_GERRIT_URL=https://review.openstack.org/openstack/fuel-mirror
FUEL_NAILGUN_AGENT_GERRIT_URL=https://review.openstack.org/openstack/fuel-nailgun-agent
FUELLIB_GERRIT_URL=https://review.openstack.org/openstack/fuel-library
FUELMENU_GERRIT_URL=https://review.openstack.org/openstack/fuel-menu
FUELUPGRADE_GERRIT_URL=https://review.openstack.org/openstack/fuel-upgrade
NAILGUN_GERRIT_URL=https://review.openstack.org/openstack/fuel-web
NETWORKCHECKER_GERRIT_URL=https://review.openstack.org/openstack/network-checker
OSTF_GERRIT_URL=https://review.openstack.org/openstack/fuel-ostf
PYTHON_FUELCLIENT_GERRIT_URL=https://review.openstack.org/openstack/python-fuelclient
SHOTGUN_GERRIT_URL=https://review.openstack.org/openstack/shotgun


{
  echo ASTUTE_GERRIT_COMMIT="${ASTUTE_GERRIT_COMMIT}";
  echo FUEL_AGENT_GERRIT_COMMIT="${FUEL_AGENT_GERRIT_COMMIT}";
  echo FUEL_MAIN_GERRIT_COMMIT="${FUEL_MAIN_GERRIT_COMMIT}";
  echo FUEL_MIRROR_GERRIT_COMMIT="${FUEL_MIRROR_GERRIT_COMMIT}";
  echo FUEL_NAILGUN_AGENT_GERRIT_COMMIT="${FUEL_NAILGUN_AGENT_GERRIT_COMMIT}";
  echo FUELLIB_GERRIT_COMMIT="${FUELLIB_GERRIT_COMMIT}";
  echo FUELMENU_GERRIT_COMMIT="${FUELMENU_GERRIT_COMMIT}";
  echo FUELUPGRADE_GERRIT_COMMIT="${FUELUPGRADE_GERRIT_COMMIT}";
  echo NAILGUN_GERRIT_COMMIT="${NAILGUN_GERRIT_COMMIT}";
  echo OSTF_GERRIT_COMMIT="${OSTF_GERRIT_COMMIT}";
  echo PYTHON_FUELCLIENT_GERRIT_COMMIT="${PYTHON_FUELCLIENT_GERRIT_COMMIT}";
  echo SHOTGUN_GERRIT_COMMIT="${SHOTGUN_GERRIT_COMMIT}";
}  > "${WORKSPACE}/gerrit_commits.txt"

build_repo astute "${ASTUTE_REPO}" "${ASTUTE_COMMIT}" "${ASTUTE_GERRIT_URL}" "${ASTUTE_GERRIT_COMMIT}"
build_repo fuel-agent "${FUEL_AGENT_REPO}" "${FUEL_AGENT_COMMIT}" "${FUEL_AGENT_GERRIT_URL}" "${FUEL_AGENT_GERRIT_COMMIT}"
build_repo fuel-createmirror "${FUEL_MIRROR_REPO}" "${FUEL_MIRROR_COMMIT}" "${FUEL_MIRROR_GERRIT_URL}" "${FUEL_MIRROR_GERRIT_COMMIT}"
build_repo fuel-library "${FUELLIB_REPO}" "${FUELLIB_COMMIT}" "${FUELLIB_GERRIT_URL}" "${FUELLIB_GERRIT_COMMIT}"
build_repo fuel-main "${FUEL_MAIN_REPO}" "${FUEL_MAIN_COMMIT}" "${FUEL_MAIN_GERRIT_URL}" "${FUEL_MAIN_GERRIT_COMMIT}"
build_repo fuel-nailgun "${NAILGUN_REPO}" "${NAILGUN_COMMIT}" "${NAILGUN_GERRIT_URL}" "${NAILGUN_GERRIT_COMMIT}"
build_repo fuel-nailgun-agent "${FUEL_NAILGUN_AGENT_REPO}" "${FUEL_NAILGUN_AGENT_COMMIT}" "${FUEL_NAILGUN_AGENT_GERRIT_URL}" "${FUEL_NAILGUN_AGENT_GERRIT_COMMIT}"
build_repo fuel-ostf "${OSTF_REPO}" "${OSTF_COMMIT}" "${OSTF_GERRIT_URL}" "${OSTF_GERRIT_COMMIT}"
build_repo fuel-upgrade "${FUELUPGRADE_REPO}" "${FUELUPGRADE_COMMIT}" "${FUELUPGRADE_GERRIT_URL}" "${FUELUPGRADE_GERRIT_COMMIT}"
build_repo fuelmenu "${FUELMENU_REPO}" "${FUELMENU_COMMIT}" "${FUELMENU_GERRIT_URL}" "${FUELMENU_GERRIT_COMMIT}"
build_repo network-checker "${NETWORKCHECKER_REPO}" "${NETWORKCHECKER_COMMIT}" "${NETWORKCHECKER_GERRIT_URL}" "${NETWORKCHECKER_GERRIT_COMMIT}"
build_repo python-fuelclient "${PYTHON_FUELCLIENT_REPO}" "${PYTHON_FUELCLIENT_COMMIT}" "${PYTHON_FUELCLIENT_GERRIT_URL}" "${PYTHON_FUELCLIENT_GERRIT_COMMIT}"
build_repo shotgun "${SHOTGUN_REPO}" "${SHOTGUN_COMMIT}" "${SHOTGUN_GERRIT_URL}" "${SHOTGUN_GERRIT_COMMIT}"
