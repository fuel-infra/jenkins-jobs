#!/bin/bash

set -ex

OVERALL_STATUS=0

REPO_NAME=centos-fuel-`awk -F '[:=?]' '/^PRODUCT_VERSION\>/ {print $NF}' config.mk`-stable
PACKAGES="`git diff --word-diff=plain HEAD^ HEAD requirements-rpm.txt | egrep '^{+' | cut -d"+" -f2 | sed ':a;N;$!ba;s/\n/ /g'`"

if [ X"${PACKAGES}" = X"" ]; then
	echo "MARK: no difference found, all requested packages exist in OBS and upstream repos."
else
	echo "MARK: checking OBS and upstream repos..."
	rm -rf /var/tmp/yum-${USER}*/*
	RES=`repoquery --repofrompath=upstream,http://mirror.centos.org/centos/6/os/x86_64/ --repofrompath==obs,http://mirror.fuel-infra.org/osci/${REPO_NAME}/centos/ --nvr -q ${PACKAGES}`
	if [ X"${RES}" = X"" ]; then
		echo "MARK: FAILURE. Requested packages were not found in both OBS and upstream repos."
		OVERALL_STATUS=1
	else
		for PACKAGE in ${PACKAGES}; do
			if echo ${RES} | grep -q ${PACKAGE}; then
				echo "MARK: ${PACKAGE} found in upstream repo»"
			else
				echo "MARK: FAILURE: ${PACKAGE} not found in upstream repos"
				OVERALL_STATUS=1
			fi
		done
	fi
fi

exit ${OVERALL_STATUS}
