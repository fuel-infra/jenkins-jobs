#!/bin/bash

set -o errexit
set -o pipefail
set -o xtrace

# Guess upstream branch name basing on $ZUUL_BRANCH
UPSTREAM_BRANCH="stable/${ZUUL_BRANCH##*/}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH%%-*}"

# Fixup for old branch names
# openstack/requirements down't have branch stable/juno, thus use stable/kilo
case "$UPSTREAM_BRANCH" in
  'stable/2014.2')   UPSTREAM_BRANCH='stable/kilo' ;;
  'stable/2015.1.0') UPSTREAM_BRANCH='stable/kilo' ;;
esac

docker run -i --rm -v "$WORKSPACE:$WORKSPACE" "$DOCKER_IMAGE_TAG" /bin/bash -xe <<EODockerRun
set -o pipefail

# (Re-)Install tox and virtualenv considering release-specific constraints
pip2 install -U tox virtualenv \
  -c "https://git.openstack.org/cgit/openstack/requirements/plain/upper-constraints.txt?h=$UPSTREAM_BRANCH"

# Start MySQL database
start-stop-daemon --start --background --user mysql --exec /usr/sbin/mysqld

# Start PostgreSQL database
pg_lsclusters -h | ( read PG_VERSION PG_CLUSTER _OTHERS; pg_ctlcluster \$PG_VERSION \$PG_CLUSTER start )

# Run tox as jenkins user
sudo -i -u jenkins /bin/bash -xe <<EOJenkins
cd "$WORKSPACE"
# Set locale to avoid unicode issues
export LANG=en_US.utf8
# Tox virtualenv contains only pip, setuptools and wheel - no need to upgrade
sed -ri '/pip.+install/ s/ -(U|-upgrade) / /' tox.ini
# Set log path
export OS_LOG_PATH="$(pwd -P)/.tox/$TOX_ENV/log"
tox -e "$TOX_ENV"

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
