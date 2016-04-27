#!/bin/bash
set -ex

git clone https://review.fuel-infra.org/tools/sustaining

VENV="${WORKSPACE}_VENV"

virtualenv "${VENV}"
source "${VENV}"/bin/activate || exit 1

pip install -r sustaining/scripts/erratumvalidation_requirements.txt

git diff HEAD~1 --name-only --diff-filter=AM | grep ".yaml$" | xargs --no-run-if-empty python sustaining/scripts/erratumvalidation.py