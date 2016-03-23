#!/bin/bash

set -ex

VENV="${WORKSPACE}_VENV"
virtualenv -p python2.7 "${VENV}"
source "${VENV}/bin/activate" || exit 1

pip install "bandit==${BANDIT_PACKAGE_VERSION}"

BANDIT_ARGS=(-c "${VENV}"/etc/bandit/bandit.yaml -r "${WORKSPACE}"/"${GERRIT_PROJECT}" -n5)

if [[ ! -z "${BANDIT_PLUGIN_EXCLUDE}" ]]; then
  for i in "${BANDIT_PLUGIN_EXCLUDE[@]}"
    do
      sed -i -e "s/- ${i}/#- ${i}/g" "${VENV}/etc/bandit/bandit.yaml"
  done
  BANDIT_ARGS+=(-p All)
fi
bandit "${BANDIT_ARGS[@]}"
