#!/bin/bash

set -o errexit
set -o pipefail
set -o xtrace

# Get Jenkins GID/UID to use the same inside docker image
JENKINS_UID=$(id -u "${JENKINS_USERNAME:-jenkins}")
JENKINS_GID=$(id -g "${JENKINS_USERNAME:-jenkins}")

# Dockerfile content should not be parsed by shell to avoid variable expansion, but
# we need to change the 'FROM' instruction, so dockerfile should be prepared in a special way
# Prepare dockerfile content without `FROM`
dockerfile=$(cat << 'EODockerfile'
ARG JENKINS_UID=1000
ARG JENKINS_GID=1000

ARG MOS_VERSION=master

ENV DB_ROOT_PW insecure_slave
ENV DB_USER openstack_citest
ENV DB_PW openstack_citest
ENV DB_NAME openstack_citest

ENV DEBIAN_FRONTEND noninteractive
ENV PACKAGES /tmp/bindep-fallback.txt

# Files required for python tests
ADD \
  https://bootstrap.pypa.io/get-pip.py \
  https://git.openstack.org/cgit/openstack-infra/project-config/plain/jenkins/data/bindep-fallback.txt \
  https://git.openstack.org/cgit/openstack-infra/project-config/plain/jenkins/scripts/install-distro-packages.sh \
  /tmp/

SHELL [ "/bin/bash",  "-xec" ]

RUN \
  set -o pipefail ; \
  echo 'APT::Install-Recommends "false";' >> /etc/apt/apt.conf.d/99local ; \
  echo 'APT::Install-Suggests "false";' >> /etc/apt/apt.conf.d/99local ; \
  echo 'APT::Get::Assume-Yes "true";' >> /etc/apt/apt.conf.d/99local ; \
  echo 'APT::Get::AllowUnauthenticated "true";' >> /etc/apt/apt.conf.d/99local ; \
  test "$MOS_VERSION" = 'master' && MOS_DEB_DIST='mos-master' || MOS_DEB_DIST="mos$MOS_VERSION" ; \
  echo "deb http://mirror.fuel-infra.org/mos-repos/ubuntu/$MOS_VERSION/ $MOS_DEB_DIST main" > /etc/apt/sources.list.d/$MOS_DEB_DIST.list ; \
  apt-get update ; \
  apt-get install lsb-release apt-transport-https ca-certificates curl git openssh-client python python3 python-yaml \
    sudo bridge-utils iproute2 iptables iputils-ping net-tools strace qemu-utils keepalived ; \
  \
  python2 /tmp/get-pip.py ; \
  python3 /tmp/get-pip.py ; \
  \
  pip2 install -U tox virtualenv ; \
  virtualenv /usr/bindep-env ; \
  /usr/bindep-env/bin/pip install bindep ; \
  sed -ri '/libjerasure/ d' /tmp/bindep-fallback.txt ; \
  bash -xe /tmp/install-distro-packages.sh ; \
  \
  groupadd -g $JENKINS_GID jenkins || : ; \
  useradd -g $JENKINS_GID -m -u $JENKINS_UID jenkins ; \
  echo 'jenkins ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/jenkins ; \
  chmod 0600 /etc/sudoers.d/jenkins ; \
  \
  install -d -m0755 -omysql -gmysql /var/run/mysqld ; \
  start-stop-daemon --start --background --user mysql --exec /usr/sbin/mysqld ; \
  sleep 5 ; \
  mysqladmin -u root password $DB_ROOT_PW ; \
  mysql -u root -p$DB_ROOT_PW -e " \
    DELETE FROM mysql.user WHERE User=''; \
    FLUSH PRIVILEGES; \
    GRANT ALL PRIVILEGES ON *.* TO '$DB_USER'@'%' identified by '$DB_PW' WITH GRANT OPTION; \
    SET default_storage_engine=MYISAM; \
    DROP DATABASE IF EXISTS $DB_NAME; \
    CREATE DATABASE $DB_NAME CHARACTER SET utf8; \
  " ; \
  mysqladmin -p$DB_ROOT_PW shutdown ; \
  \
  pg_lsclusters -h | ( read PG_VERSION PG_CLUSTER _OTHERS; pg_ctlcluster $PG_VERSION $PG_CLUSTER start ) ; \
  sudo -H -u postgres psql -c "ALTER ROLE $DB_USER WITH SUPERUSER LOGIN PASSWORD '$DB_PW'" \
  || sudo -H -u postgres psql -c "CREATE ROLE $DB_USER WITH SUPERUSER LOGIN PASSWORD '$DB_PW'" ; \
  sudo -H -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME" ; \
  sudo -H -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER TEMPLATE template0 ENCODING 'utf8'" ; \
  echo "*:*:*:$DB_USER:$DB_PW" > ~jenkins/.pgpass ; \
  chown $JENKINS_UID:$JENKINS_GID ~jenkins/.pgpass ; \
  chmod 0600 ~jenkins/.pgpass ; \
  pg_lsclusters -h | ( read PG_VERSION PG_CLUSTER _OTHERS; pg_ctlcluster $PG_VERSION $PG_CLUSTER stop )
EODockerfile
)

# Build docker image prepending prepared dockerfile content with the `FROM` instruction
docker build \
  --build-arg JENKINS_UID="$JENKINS_UID" \
  --build-arg JENKINS_GID="$JENKINS_GID" \
  --build-arg MOS_VERSION="$MOS_VERSION" \
  --no-cache \
  --tag "${DOCKER_IMAGE_TAG:-infra-ubuntu-$UBUNTU_DISTRO}" \
  - << EOF
FROM ubuntu:$UBUNTU_DISTRO
$dockerfile
EOF
