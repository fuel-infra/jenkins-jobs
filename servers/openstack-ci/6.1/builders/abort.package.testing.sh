#!/bin/bash -ex

git pull origin refs/changes/66/5266/2

venv_path=/home/jenkins/venv-abort-package-testing
if [ ! -d "$venv_path" ]
then
    virtualenv --system-site-packages "$venv_path"
    source "$venv_path/bin/activate"
    pip install --upgrade python-jenkins
else
    source "$venv_path/bin/activate"
fi

python abort-package-testing
