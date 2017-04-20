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

unset MOS_RELEASE
CONSTRAINTS_REV="h=$UPSTREAM_BRANCH"

# Guess MOS_RELEASE for mos-requirements
# Override CONSTRAINTS_REV for EOL branches
case "$UPSTREAM_BRANCH" in
  'stable/2014.2')   MOS_RELEASE=6.1; CONSTRAINTS_REV='t=juno-eol'    ;;
  'stable/2015.1.0') MOS_RELEASE=7.0; CONSTRAINTS_REV='t=liberty-eol' ;;
  'stable/liberty')  MOS_RELEASE=8.0                                  ;;
  'stable/mitaka')   MOS_RELEASE=9.0                                  ;;
  'stable/newton')   MOS_RELEASE=10.0                                 ;;
esac

docker run -i --rm -v "$WORKSPACE:$WORKSPACE" "$DOCKER_IMAGE_TAG" /bin/bash -xe <<EODockerRun
set -o pipefail

# (Re-)Install tox and virtualenv considering release-specific constraints
pip2 install -U tox virtualenv \
  -c "https://git.openstack.org/cgit/openstack/requirements/plain/upper-constraints.txt?$CONSTRAINTS_REV"

# Start MySQL database
start-stop-daemon --start --background --user mysql --exec /usr/sbin/mysqld

# Start PostgreSQL database
pg_lsclusters -h | ( read PG_VERSION PG_CLUSTER _OTHERS; pg_ctlcluster \$PG_VERSION \$PG_CLUSTER start )

# Run tox as jenkins user
sudo -i -u jenkins /bin/bash -xe <<EOJenkins
cd "$WORKSPACE"
# Set locale to avoid unicode issues
export LANG=en_US.utf8
# Prepare mos-requirements
if [ -n "$MOS_RELEASE" ] && [ -f 'test-requirements.txt' ]; then
    MOS_RELEASE=$MOS_RELEASE mos-requirements/scripts/prepare-env.sh venv
fi
# Set log path
export OS_LOG_PATH="$(pwd -P)/.tox/$TOX_ENV/log"
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
