#!/bin/bash

set -o errexit
set -o pipefail
set -o xtrace

# Guess upstream branch name basing on $ZUUL_BRANCH
UPSTREAM_BRANCH="stable/${ZUUL_BRANCH##*/}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH%%-*}"

# Murano-specific branch(es)
if [ "$ZUUL_BRANCH" = '9.0/plugin' ] || [ "${ZUUL_BRANCH%/*}" = '9.0/release' ]; then
  UPSTREAM_BRANCH='stable/mitaka'
fi

# Defaults
unset MOS_RELEASE
UBUNTU_DIST='xenial'
CONSTRAINTS_REV="h=$UPSTREAM_BRANCH"

# Configure test:
#  - guess MOS_RELEASE for mos-requirements
#  - set virtualenv version constraint
#  - choose Ubuntu release
#  - override CONSTRAINTS_REV for EOL branches
case "$UPSTREAM_BRANCH" in
  'stable/2014.2')
    MOS_RELEASE=6.1
    VIRTUALENV_VER='<15.1'
    UBUNTU_DIST='trusty'
    CONSTRAINTS_REV='t=juno-eol'
    ;;
  'stable/2015.1.0')
    MOS_RELEASE=7.0
    VIRTUALENV_VER='<13.1.1'
    UBUNTU_DIST='trusty'
    CONSTRAINTS_REV='t=kilo-eol'
    ;;
  'stable/liberty')
    MOS_RELEASE=8.0
    VIRTUALENV_VER='<15.1'
    UBUNTU_DIST='trusty'
    CONSTRAINTS_REV='t=liberty-eol'
    ;;
  'stable/mitaka')
    MOS_RELEASE=9.0
    VIRTUALENV_VER='<15.1'
    UBUNTU_DIST='trusty'
    CONSTRAINTS_REV='t=mitaka-eol'
    ;;
  'stable/newton')
    MOS_RELEASE=10.0
    VIRTUALENV_VER='<15.1'
    ;;
esac

DOCKER_IMAGE="infra-ubuntu-$UBUNTU_DIST"

docker run -i --rm -v "$WORKSPACE:$WORKSPACE" "$DOCKER_IMAGE" /bin/bash -xe <<EODockerRun
set -o pipefail

# Generate host UUID
openssl rand -hex 16 > /etc/machine-id

# Download constraints
curl -fLsS -o /tmp/upper-constraints.txt "https://git.openstack.org/cgit/openstack/requirements/plain/upper-constraints.txt?$CONSTRAINTS_REV"

# (Re-)Install tox and virtualenv considering release-specific constraints
pip2 install -U "virtualenv$VIRTUALENV_VER"

# Start MySQL database
start-stop-daemon --start --background --user mysql --exec /usr/sbin/mysqld

# Start PostgreSQL database
pg_lsclusters -h | ( read PG_VERSION PG_CLUSTER _OTHERS; pg_ctlcluster \$PG_VERSION \$PG_CLUSTER start )

# Start MongoDB
start-stop-daemon --start --background --chuid mongodb --exec /usr/bin/mongod -- --config /etc/mongodb.conf

# Run tox as jenkins user
sudo -i -u jenkins /bin/bash -xe <<EOJenkins
cd "$WORKSPACE"
# Set locale to avoid unicode issues
export LANG=en_US.utf8
# Set default PATH doesn't contain sbin's
export PATH=$PATH:/usr/sbin:/sbin
# Prepare mos-requirements
# NOTE(dmeltsaykin): this breaks upstream constraints
#if [ -n "$MOS_RELEASE" ] && [ -f 'test-requirements.txt' ]; then
#    MOS_RELEASE=$MOS_RELEASE mos-requirements/scripts/prepare-env.sh venv
#fi
rm -rf mos-requirements
# Set log path
export OS_LOG_PATH="$(pwd -P)/.tox/$TOX_ENV/log"
# Use downloaded constraints
export UPPER_CONSTRAINTS_FILE='/tmp/upper-constraints.txt'
tox -v -e "$TOX_ENV"

### FIXME(aevseev) JUnit publisher prior to version 1.10 does not have option to skip non-existent reports
### Packaging CI has 1.2-beta-4 (!)
### # Prepare JUnit xml
### set +o errexit
### set +o pipefail
### if [ -f ".testrepository/0" ] && [ -x ".tox/$TOX_ENV/bin/subunit-1to2" ]; then
###     ".tox/$TOX_ENV/bin/pip" install junitxml
###     ".tox/$TOX_ENV/bin/subunit-1to2" < .testrepository/0 | ".tox/$TOX_ENV/bin/subunit2junitxml" -o ".tox/$TOX_ENV/log/junit.xml"
### fi
EOJenkins
EODockerRun
