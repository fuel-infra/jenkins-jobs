#!/bin/bash

set -x

# get values:
#   - MIRROR_MOS_UBUNTU_HOST=mirror.fuel-infra.org
#   - MIRROR_MOS_UBUNTU_HTTPDIR="mos-repos/ubuntu/8.0"
source "${WORKSPACE}/config/common.cfg"

# extract version from MIRROR_MOS_UBUNTU_HTTPDIR
PRODUCT_VERSION=${MIRROR_MOS_UBUNTU_HTTPDIR##*/}
DIST=trusty

OVERALL_STATUS=0

PACKAGES=`git diff --word-diff=plain HEAD~ config/requirements-deb.txt | egrep '{+' | cut -d"+" -f2 | sed ':a;N;$!ba;s/\n/ /g'`

if [ X"${PACKAGES}" = X"" ]; then
	echo "MARK: no difference found, all requested packages exist in Perestroika and upstream repos."
	exit 0
fi

#check if requirements-deb.txt is sorted alphabetically
if git diff --name-only HEAD~ config/requirements-deb.txt >/dev/null; then
        sort -u config/requirements-deb.txt| diff config/requirements-deb.txt -;
        if [ $? -ne 0 ]; then
                echo "MARK: FAILURE. /config/requirements-deb.txt is not sorted. Please sort it with sort -u";
                exit 1;
        fi
fi

echo "MARK: checking Perestroika and upstream repos..."
TEMPDIR=$(/bin/mktemp -d /tmp/test-requirements-deb-XXXXXXXX)
echo "MARK: workspace directory is ${TEMPDIR}"

chdist --data-dir ${TEMPDIR} create ubuntu http://${MIRROR_MOS_UBUNTU_HOST}/${MIRROR_MOS_UBUNTU_HTTPDIR}/ mos${PRODUCT_VERSION} main restricted

cat > ${TEMPDIR}/ubuntu/etc/apt/sources.list <<EOT
deb http://${MIRROR_MOS_UBUNTU_HOST}/${MIRROR_MOS_UBUNTU_HTTPDIR}/ mos${PRODUCT_VERSION} main restricted
deb http://${MIRROR_MOS_UBUNTU_HOST}/${MIRROR_MOS_UBUNTU_HTTPDIR}/ mos${PRODUCT_VERSION}-updates main restricted
deb http://${MIRROR_MOS_UBUNTU_HOST}/${MIRROR_MOS_UBUNTU_HTTPDIR}/ mos${PRODUCT_VERSION}-security main restricted
deb http://${MIRROR_MOS_UBUNTU_HOST}/pkgs/ubuntu/ ${DIST} main universe multiverse restricted
deb http://${MIRROR_MOS_UBUNTU_HOST}/pkgs/ubuntu/ ${DIST}-security main universe multiverse restricted
deb http://${MIRROR_MOS_UBUNTU_HOST}/pkgs/ubuntu/ ${DIST}-updates main universe multiverse restricted
EOT

echo 'APT::Get::AllowUnauthenticated 1;' > ${TEMPDIR}/ubuntu/etc/apt/apt.conf.d/02unauthenticated

chdist --data-dir ${TEMPDIR} apt-get ubuntu update
chdist --data-dir ${TEMPDIR} apt-get ubuntu install --dry-run ${PACKAGES}
RES=${?}
if [ ${RES} -eq 0 ]; then
	echo "MARK: SUCCESS. The following packages are available in Perestroika or upstream repos: ${PACKAGES}"
else
	echo "MARK: FAILURE. Requested packages were not found in both Perestroika and upstream repos"
	OVERALL_STATUS=1
fi

rm -rf ${TEMPDIR}

exit ${OVERALL_STATUS}
