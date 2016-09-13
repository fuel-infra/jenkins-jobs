#!/bin/bash
#
#   :mod: `prepare-venv.sh` -- Create virtualenv used by tests
#   ==========================================================
#
#   .. module:: plugin-venv.sh
#       :platform: Unix
#       :synopsis: Script used to prepare test virtualenv
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: Artur Kaszuba <akaszuba@mirantis.com>
#
#
#   This script is used to prepare virtualenv and install requirements for
#   fuel-qa
#
#
#   .. envvar::
#       :var  VENV_PATH: Path to directory with will be used to create
#                        virtualenv
#
#   .. requirements::
#
#       * slave with hiera enabled:
#           fuel_project::jenkins::slave::run_tests: true
#

set -ex

# Create temporary venv
rm -rf "${VENV_PATH}"
virtualenv "${VENV_PATH}"
source "${VENV_PATH}/bin/activate"

# Upgrade default venv pip to last version
pip install pip --upgrade

# Temporary solution to solve error:
#   'EntryPoint' object has no attribute 'resolve'
pip install setuptools --upgrade

# Install fuel-qa requirements
pip install -r fuelweb_test/requirements.txt
pip install -r fuelweb_test/requirements-devops-source.txt
