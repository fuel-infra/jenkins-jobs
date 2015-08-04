#!/bin/bash

set -xe

OVERALL_STATUS=0

PRODUCT_VERSION=`awk -F '[:=?]' '/^PRODUCT_VERSION\>/ {print $NF}' config.mk`
CENTOS_MAJOR=`awk -F '[:=?]' '/^CENTOS_MAJOR\>/ {print $NF}' config.mk`
CENTOS_ARCH=`awk -F '[:=?]' '/^CENTOS_ARCH\>/ {print $NF}' config.mk`
PACKAGES=$(git diff --word-diff=plain HEAD~ requirements-rpm.txt | egrep '{+' | egrep -v "@Base|@Core" | cut -d"+" -f2 | sed ':a;N;$!ba;s/\n/ /g')

if [ X"${PACKAGES}" = X"" ]; then
	echo "MARK: no difference found, all requested packages exist in Perestroika and upstream repos."
	exit 0
fi

#check if requirements-rpm.txt is sorted alphabetically
if git diff --name-only HEAD~ requirements-rpm.txt >/dev/null; then
        ( sort -u requirements-rpm.txt | diff requirements-rpm.txt - ) || ( echo "MARK: FAILURE. requirements-rpm.txt is not sorted. Please sort it with sort -u"; exit 1 )
fi

echo "MARK: checking Perestroika and upstream repos..."
rm -rf /var/tmp/yum-"${USER}"*/*

RES=$(repoquery --repofrompath=upstream-base,http://mirror.centos.org/centos/${CENTOS_MAJOR}/os/${CENTOS_ARCH}/ \
--repofrompath=upstream-updates,http://mirror.centos.org/centos/${CENTOS_MAJOR}/updates/${CENTOS_ARCH}/ \
--repofrompath==perestroika,http://mirror.fuel-infra.org/mos-repos/centos/mos${PRODUCT_VERSION}-centos${CENTOS_MAJOR}-fuel/os/${CENTOS_ARCH}/ \
--repofrompath==perestroika-security,http://mirror.fuel-infra.org/mos-repos/centos/mos${PRODUCT_VERSION}-centos${CENTOS_MAJOR}-fuel/security/${CENTOS_ARCH}/ \
--repofrompath==perestroika-updates,http://mirror.fuel-infra.org/mos-repos/centos/mos${PRODUCT_VERSION}-centos${CENTOS_MAJOR}-fuel/updates/${CENTOS_ARCH}/ \
--whatprovides --nvr -q ${PACKAGES})

if [ X"${RES}" = X"" ]; then
	echo "MARK: FAILURE. Requested packages were not found in both Perestroika and upstream repos."
	OVERALL_STATUS=1
else
	for PACKAGE in ${PACKAGES}; do
		if echo "${RES}" | grep -q "${PACKAGE}"; then
			echo "MARK: ${PACKAGE} found in Perestroika or upstream repos"
		else
			echo "MARK: FAILURE: ${PACKAGE} not found in both Perestroika and upstream repos"
			OVERALL_STATUS=1
		fi
	done
fi

exit ${OVERALL_STATUS}
