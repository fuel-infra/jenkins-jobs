#!/bin/bash -x
LAST_BUILD_NUMBER=$BUILD_NUMBER
export RELEASE=$mirror
SUFFIX="build_staging_mirror"

MYOUTDIR="$(mktemp -d ${WORKSPACE}/testworkdir-XXXXXXXXXX)"
pushd $MYOUTDIR

cp ${WORKSPACE}/ubuntu-packages.changelog $RELEASE-$LAST_BUILD_NUMBER-ubuntu-packages.changelog
cp ${WORKSPACE}/centos-packages.changelog $RELEASE-$LAST_BUILD_NUMBER-centos-packages.changelog

export JENKINS_PREVIOS_STABLE_URL="${HUDSON_URL}/job/${RELEASE}.test_staging_mirror/lastSuccessfulBuild/"

if curl -fsS $JENKINS_PREVIOS_STABLE_URL > /dev/null 2>&1 ; then
   PREVIOS_BUILD_URL=$(python -c '
import json, urllib2, urlparse, os
def geturl(url, suffix="api/json"):
    try:
        jenkins_data = urllib2.urlopen(urlparse.urljoin(url, suffix))
    except urllib2.HTTPError as e:
        raise Exception("{} {} when trying to "
                        "GET {}".format(e.code, e.msg, e.url))
    else:
        info = jenkins_data.read()

    try:
        info = json.loads(info)
    except:
        pass
    return info
jenkins_previos_stable_url = os.environ.get("JENKINS_PREVIOS_STABLE_URL")
obj = geturl(jenkins_previos_stable_url)
print [o.get("value") for o in obj["actions"][0]["parameters"] if "BUILD_MIRROR_URL" in o["name"]][0]')
export PREVIOS_BUILD_NUMBER=$(echo $PREVIOS_BUILD_URL | cut -d '/' -f6)

   wget ${HUDSON_URL}/job/$RELEASE."$SUFFIX"/$PREVIOS_BUILD_NUMBER/artifact/ubuntu-packages.changelog -O $RELEASE-$PREVIOS_BUILD_NUMBER-ubuntu-packages.changelog
   wget ${HUDSON_URL}/job/$RELEASE."$SUFFIX"/$PREVIOS_BUILD_NUMBER/artifact/centos-packages.changelog -O $RELEASE-$PREVIOS_BUILD_NUMBER-centos-packages.changelog

   #list ubuntu change-id
   cat "$RELEASE"-"$LAST_BUILD_NUMBER"-ubuntu-packages.changelog | grep -v "#" | grep -o -E -e "[A-Z][0-9a-f]{40}" | sort | uniq > "$RELEASE"-"$LAST_BUILD_NUMBER"_ubuntu_change-id
   cat "$RELEASE"-"$PREVIOS_BUILD_NUMBER"-ubuntu-packages.changelog | grep -v "#" | grep -o -E -e "[A-Z][0-9a-f]{40}" | sort | uniq  > "$RELEASE"-"$PREVIOS_BUILD_NUMBER"_ubuntu_change-id
   diff -u "$RELEASE"-"$LAST_BUILD_NUMBER"_ubuntu_change-id "$RELEASE"-"$PREVIOS_BUILD_NUMBER"_ubuntu_change-id | grep -o -E -e "[-][A-Z][0-9a-f]{40}" | sed -e 's/-//' > list_ubuntu_change-id.txt

   #list ubuntu commit-id
   cat "$RELEASE"-"$LAST_BUILD_NUMBER"-ubuntu-packages.changelog | grep -v "#" | grep -o -E -e "[*] [0-9a-f]{7}" | awk '{print $2}' | sort | uniq > "$RELEASE"-"$LAST_BUILD_NUMBER"_ubuntu_commit-id
   cat "$RELEASE"-"$PREVIOS_BUILD_NUMBER"-ubuntu-packages.changelog | grep -v "#" | grep -o -E -e "[*] [0-9a-f]{7}" | awk '{print $2}' | sort | uniq > "$RELEASE"-"$PREVIOS_BUILD_NUMBER"_ubuntu_commit-id
   diff -u "$RELEASE"-"$LAST_BUILD_NUMBER"_ubuntu_commit-id "$RELEASE"-"$PREVIOS_BUILD_NUMBER"_ubuntu_commit-id |  grep -o -E -e "[-][0-9a-f]{7}" | sed -e 's/-//' > list_ubuntu_commit-id.txt

   #list centos commit-id
   cat "$RELEASE"-"$LAST_BUILD_NUMBER"-centos-packages.changelog | grep -v "#" | grep -o -E -e "[-] [0-9a-f]{7}" | awk '{print $2}' | sort | uniq > "$RELEASE"-"$LAST_BUILD_NUMBER"_centos_commit-id
   cat "$RELEASE"-"$PREVIOS_BUILD_NUMBER"-centos-packages.changelog | grep -v "#" | grep -o -E -e "[-] [0-9a-f]{7}" | awk '{print $2}' | sort | uniq > "$RELEASE"-"$PREVIOS_BUILD_NUMBER"_centos_commit-id
   diff -u "$RELEASE"-"$LAST_BUILD_NUMBER"_centos_commit-id "$RELEASE"-"$PREVIOS_BUILD_NUMBER"_centos_commit-id | grep -o -E -e "[-][0-9a-f]{7}" | sed -e 's/-//' > list_centos_commit-id.txt
else
   cat "$RELEASE"-"$LAST_BUILD_NUMBER"-ubuntu-packages.changelog | grep -v "#" | grep -o -E -e "[A-Z][0-9a-f]{40}" | sort | uniq > list_ubuntu_change-id.txt
   cat "$RELEASE"-"$LAST_BUILD_NUMBER"-ubuntu-packages.changelog | grep -v "#" | grep -o -E -e "[*] [0-9a-f]{7}" | awk '{print $2}' | sort | uniq > list_ubuntu_commit-id.txt
   cat "$RELEASE"-"$LAST_BUILD_NUMBER"-centos-packages.changelog | grep -v "#" | grep -o -E -e "[-] [0-9a-f]{7}" | awk '{print $2}' | sort | uniq > list_centos_commit-id.txt
fi

if [ -e list_ubuntu_change-id.txt ] || [ -e list_*_commit-id.txt ] ; then
   BACKUP_DIR=changelog && mkdir -p $BACKUP_DIR
   cp list_*-id.txt $BACKUP_DIR
   tar -pczf $BACKUP_DIR.tar.gz $BACKUP_DIR && mv $BACKUP_DIR.tar.gz ${WORKSPACE}
fi

pushd ${WORKSPACE}
rm -rf ${MYOUTDIR}
exit 0
