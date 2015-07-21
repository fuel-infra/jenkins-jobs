#!/bin/bash

set -xe

OVERALL_STATUS=0

REPO_NAME=centos-fuel-$(awk -F '[:=?]' '/^PRODUCT_VERSION\>/ {print $NF}' config.mk)-stable
PACKAGES=$(git diff --word-diff=plain HEAD~ requirements-rpm.txt | egrep '{+' | egrep -v "@Base|@Core" | cut -d"+" -f2 | sed ':a;N;$!ba;s/\n/ /g')

if [ X"${PACKAGES}" = X"" ]; then
	echo "MARK: no difference found, all requested packages exist in OBS and upstream repos."
	exit 0
fi

#check if requirements-rpm.txt is sorted alphabetically
if git diff --name-only HEAD~ requirements-rpm.txt >/dev/null; then
        ( sort -u requirements-rpm.txt | diff requirements-rpm.txt - ) || ( echo "MARK: FAILURE. requirements-rpm.txt is not sorted. Please sort it with sort -u"; exit 1 )
fi

echo "MARK: checking OBS and upstream repos..."
rm -rf /var/tmp/yum-"${USER}"*/*

# FIXME(vparakhin): fix Perestroika mirror as soon as repo format for 7.0+ is defined

RES=$(repoquery --repofrompath=upstream,http://mirror.centos.org/centos/6/os/x86_64/ --repofrompath==perestroika,http://mirror.fuel-infra.org/mos-repos/7.0/fuel/base/centos6/ --whatprovides --nvr -q ${PACKAGES})
if [ X"${RES}" = X"" ]; then
	echo "MARK: FAILURE. Requested packages were not found in both OBS and upstream repos."
	OVERALL_STATUS=1
else
	for PACKAGE in ${PACKAGES}; do
		if echo "${RES}" | grep -q "${PACKAGE}"; then
			echo "MARK: ${PACKAGE} found in upstream repo»"
		else
			echo "MARK: FAILURE: ${PACKAGE} not found in upstream repos"
			OVERALL_STATUS=1
		fi
	done
fi

exit ${OVERALL_STATUS}
