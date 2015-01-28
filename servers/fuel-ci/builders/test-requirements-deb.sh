#!/bin/bash

set -ex

DIST=precise
OVERALL_STATUS=0

REPO_NAME=ubuntu-fuel-`awk -F '[:=?]' '/^PRODUCT_VERSION\>/ {print $NF}' config.mk`-stable
PACKAGES=`git diff --word-diff=plain HEAD^ HEAD requirements-deb.txt | egrep '^{+' | cut -d"+" -f2 | sed ':a;N;$!ba;s/\n/ /g'`

if [ X"${PACKAGES}" = X"" ]; then
	echo "MARK: no difference found, all requested packages exist in OBS and upstream repos."
else
	echo "MARK: checking OBS and upstream repos..."
	TEMPDIR=$(/bin/mktemp -d /tmp/test-requirements-deb-XXXXXXXX)
	echo "MARK: workspace directory is ${TEMPDIR}"
	chdist --data-dir ${TEMPDIR} create ${REPO_NAME} http://mirror.fuel-infra.org/osci/${REPO_NAME}/ubuntu/ /

	cat >> ${TEMPDIR}/${REPO_NAME}/etc/apt/sources.list <<EOT
deb http://mirror.yandex.ru/ubuntu ${DIST} main universe multiverse restricted
deb http://mirror.yandex.ru/ubuntu ${DIST}-updates main universe multiverse restricted
deb http://mirror.yandex.ru/ubuntu ${DIST}-security main universe multiverse restricted
EOT

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
fi

exit ${OVERALL_STATUS}
