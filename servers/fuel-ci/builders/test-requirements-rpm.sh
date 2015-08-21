#!/bin/bash

set -xe

PRODUCT_VERSION=`awk -F '[:=?]' '/^PRODUCT_VERSION\>/ {print $NF}' config.mk`
CENTOS_MAJOR=`awk -F '[:=?]' '/^CENTOS_MAJOR\>/ {print $NF}' config.mk`
CENTOS_MINOR=`awk -F '[:=?]' '/^CENTOS_MINOR\>/ {print $NF}' config.mk`
CENTOS_RELEASE=${CENTOS_MAJOR}.${CENTOS_MINOR}
CENTOS_ARCH=`awk -F '[:=?]' '/^CENTOS_ARCH\>/ {print $NF}' config.mk`
PACKAGES=$(git diff --word-diff=plain HEAD~ requirements-rpm.txt | egrep '{+' | egrep -v "@Base|@Core" | cut -d"+" -f2 | sed ':a;N;$!ba;s/\n/ /g')

export MIRROR_CENTOS=http://vault.centos.org/${CENTOS_RELEASE}/
export MIRROR_FUEL=http://mirror.fuel-infra.org/mos-repos/centos/mos${PRODUCT_VERSION}-centos${CENTOS_MAJOR}-fuel/os/${CENTOS_ARCH}/

if [ X"${PACKAGES}" = X"" ]; then
	echo "MARK: no difference found, all requested packages exist in Perestroika and upstream repos."
	exit 0
fi

#check if requirements-rpm.txt is sorted alphabetically
if git diff --name-only HEAD~ requirements-rpm.txt >/dev/null; then
        ( sort -u requirements-rpm.txt | diff requirements-rpm.txt - ) || ( echo "MARK: FAILURE. requirements-rpm.txt is not sorted. Please sort it with sort -u"; exit 1 )
fi

echo "MARK: checking Perestroika and upstream repos..."

make show-yum-urls-centos USE_MIRROR=none