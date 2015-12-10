#!/bin/bash

set -xe

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

make show-yum-urls-centos-full USE_MIRROR=none