#!/bin/bash

set -x

DIST=`awk -F '[:=?]' '/^UBUNTU_RELEASE\>/ {print $NF}' config.mk`
OVERALL_STATUS=0

PRODUCT_VERSION=`awk -F '[:=?]' '/^PRODUCT_VERSION\>/ {print $NF}' config.mk`
REPO_NAME=ubuntu-fuel-$PRODUCT_VERSION-stable
PACKAGES=`git diff --word-diff=plain HEAD~ requirements-deb.txt | egrep '{+' | cut -d"+" -f2 | sed ':a;N;$!ba;s/\n/ /g'`

if [ X"${PACKAGES}" = X"" ]; then
	echo "MARK: no difference found, all requested packages exist in OBS and upstream repos."
	exit 0
fi

#check if requirements-deb.txt is sorted alphabetically
if git diff --name-only HEAD~ requirements-deb.txt >/dev/null; then
        sort -u requirements-deb.txt| diff requirements-deb.txt -;
        if [ $? -ne 0 ]; then
                echo "MARK: FAILURE. requirements-deb.txt is not sorted. Please sort it with sort -u";
                exit 1;
        fi
fi

echo "MARK: checking OBS and upstream repos..."
TEMPDIR=$(/bin/mktemp -d /tmp/test-requirements-deb-XXXXXXXX)
echo "MARK: workspace directory is ${TEMPDIR}"

if [ "${DIST}" = "precise" ]; then
    chdist --data-dir ${TEMPDIR} create ${REPO_NAME} http://mirror.fuel-infra.org/osci/${REPO_NAME}/ubuntu/ /

    cat >> ${TEMPDIR}/${REPO_NAME}/etc/apt/sources.list <<EOT
deb http://mirror.yandex.ru/ubuntu ${DIST} main universe multiverse restricted
deb http://mirror.yandex.ru/ubuntu ${DIST}-updates main universe multiverse restricted
deb http://mirror.yandex.ru/ubuntu ${DIST}-security main universe multiverse restricted
EOT
else
        chdist --data-dir ${TEMPDIR} create ${REPO_NAME} http://obs-1.mirantis.com/mos/ubuntu/ mos${PRODUCT_VERSION} main

        cat > ${TEMPDIR}/${REPO_NAME}/etc/apt/sources.list <<EOT
# FIXME(vparakhin): fix Perestroika mirror as soon as repo format for 7.0+ is defined
deb http://mirror.fuel-infra.org/mos-repos/7.0/cluster/base/trusty/ trusty main

#deb [arch=amd64] http://obs-1.mirantis.com/mos/ubuntu/ mos${PRODUCT_VERSION} main
#deb [arch=amd64] http://obs-1.mirantis.com/mos/ubuntu/ mos${PRODUCT_VERSION}-updates main
#deb [arch=amd64] http://obs-1.mirantis.com/mos/ubuntu/ mos${PRODUCT_VERSION}-security main
deb http://mirror.fuel-infra.org/pkgs/ubuntu/ ${DIST} main universe multiverse restricted
deb http://mirror.fuel-infra.org/pkgs/ubuntu/ ${DIST}-security main universe multiverse restricted
deb http://mirror.fuel-infra.org/pkgs/ubuntu/ ${DIST}-updates main universe multiverse restricted
EOT
fi

echo 'APT::Get::AllowUnauthenticated 1;' > ${TEMPDIR}/${REPO_NAME}/etc/apt/apt.conf.d/02unauthenticated

chdist --data-dir ${TEMPDIR} apt-get ${REPO_NAME} update
chdist --data-dir ${TEMPDIR} apt-get ${REPO_NAME} install --dry-run ${PACKAGES}
RES=${?}
if [ ${RES} -eq 0 ]; then
	echo "MARK: SUCCESS. The following packages are available in upstream repos: ${PACKAGES}"
else
	echo "MARK: FAILURE. Requested packages were not found in both OBS and upstream repos"
	OVERALL_STATUS=1
fi

rm -rf ${TEMPDIR}

exit ${OVERALL_STATUS}
