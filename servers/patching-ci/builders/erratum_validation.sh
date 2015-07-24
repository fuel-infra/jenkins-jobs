#!/bin/bash -ex

git clone https://review.fuel-infra.org/tools/sustaining

git diff HEAD~1 --name-only --diff-filter=AM | grep ".yaml$" | xargs --no-run-if-empty python sustaining/scripts/erratumvalidation.py