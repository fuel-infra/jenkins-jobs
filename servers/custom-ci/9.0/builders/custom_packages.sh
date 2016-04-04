#!/bin/bash

set -ex

# common part
# gpg --list-keys
export SIGKEYID=6DAFDD9D

# project related vars
export PROJECT_NAME=mos
export PROJECT_VERSION=9.0
export SOURCE_BRANCH='master'
# we need to set GERRIT_CHANGE_STATUS in order to increase package version:
# [ "$GERRIT_CHANGE_STATUS" == "NEW" ] && _rev=$(( $_rev + 1 ))
export GERRIT_CHANGE_STATUS=NEW

export REMOTE_REPO_HOST=perestroika-repo-tst.infra.mirantis.net
export DIST=centos7
# rpm part
export RPM_OS_REPO_PATH="/mos-repos/centos/${PROJECT_NAME}${PROJECT_VERSION}-${DIST}/os/"
# debian part
export DEB_REPO_PATH="/mos-repos/ubuntu/${PROJECT_VERSION}/"
export DEB_DIST_NAME="${PROJECT_NAME}${PROJECT_VERSION}"
export COMPONENTS='main restricted'
export ORIGIN=testing

# share local mirror
WEB_SHARE_ROOT=/var/www/packages/
WEB_SHARE_REPO=${JOB_NAME}/${BUILD_NUMBER}

#### Packaging section
LOCAL_REPO_PATH=${WORKSPACE}/packages
rm -rf "${LOCAL_REPO_PATH}"
mkdir "${LOCAL_REPO_PATH}"
####


# Checking gerrit commits for fuel-mirror
if [ "${fuelmirror_gerrit_commit}" != "none" ] ; then
  for commit in ${fuelmirror_gerrit_commit} ; do
    git fetch https://review.openstack.org/openstack/fuel-mirror "${commit}" && git cherry-pick FETCH_HEAD || false
  done
fi

echo "STEP 0. Clean before start"

# remove exited containers
docker rm $(docker ps -q -f status=exited) || true

echo "STEP 1. Prepare build phase"
# we don't need build packages in case:
#   - *_gerrit_commit=none
#   - *_COMMIT=master
# since such packages can be taken from original mirror.
# In this case make system will not create repos (directories)
REPOS=$(find "${WORKSPACE}"/build-fuel-packages/repos/ -maxdepth 1 -type d | wc -l)
if [ "${REPOS}" -eq 1 ]; then
  echo "At least one package should be built from exact commit or gerrit patch-set."
  exit 1
fi

echo "STEP 2. Build packages"

# create structure for future RPM repo
mkdir -p "${LOCAL_REPO_PATH}"/centos/os/{x86_64/Packages,Source/SPackages,x86_64/repodata}
LOCAL_REPO_CENTOS_PATH="${LOCAL_REPO_PATH}/centos/os/"
createrepo --pretty --database --update -o "${LOCAL_REPO_CENTOS_PATH}/x86_64" "${LOCAL_REPO_CENTOS_PATH}/x86_64"
createrepo --pretty --database --update -o "${LOCAL_REPO_CENTOS_PATH}/Source/" "${LOCAL_REPO_CENTOS_PATH}/Source"

# if user deines EXTRA_RPM_REPOS let's pass it to build root
[ -n "${EXTRA_RPM_REPOS}" ] && export EXTRAREPO="${EXTRA_RPM_REPOS}"
# build packages and inject rpm in future mirror
for repo in ${WORKSPACE}/build-fuel-packages/repos/*/; do
  pushd "${repo}"
  PACKAGE=$(echo "${repo%/}" | awk -F/ '{print $NF}')
  export PACKAGENAME="openstack/${PACKAGE}"
  export SRC_PROJECT="${PACKAGENAME}"
  export CUSTOM_SRC_PATH="${repo}"
  bash -x "${WORKSPACE}/perestroika/build-fuel-rpm.sh"
  find "${repo}/wrk-build/src-to-build/build/" -type f -name '*.rpm' -not -name "*.src.rpm" -exec cp -v {} "${LOCAL_REPO_CENTOS_PATH}/x86_64/Packages" \;
  find "${repo}/wrk-build/src-to-build/build/" -type f -name '*src.rpm' -exec cp -v {} "${LOCAL_REPO_CENTOS_PATH}/Source/SPackages" \;
  popd
done
# unset EXTRAREPO, since EXTRAREPO is also used for deb packages
unset EXTRAREPO

########################## Sign RPM packages in repo #######
if [ -n "${SIGKEYID}" ] ; then

  gpg --export -a "${SIGKEYID}" > RPM-GPG-KEY
  if [ $(rpm -qa | grep gpg-pubkey | grep -ci "${SIGKEYID}") -eq 0 ]; then
    rpm --import RPM-GPG-KEY
  fi

  # Sign rpm binaries
  for binary in ${LOCAL_REPO_CENTOS_PATH}/x86_64/Packages/*; do
    # rpmsign requires pass phrase. use `expect` to skip it
    LANG=C expect <<EOL
spawn rpmsign --define "%__gpg_check_password_cmd /bin/true" --define "%_signature gpg" --define "%_gpg_name ${SIGKEYID}" --resign ${binary}
expect -exact "Enter pass phrase:"
send -- "Doesn't matter\r"
expect eof
lassign [wait] pid spawnid os_error_flag value
puts "exit status: \$value"
exit \$value
EOL

  done
fi
############################################################

# let's generate repo
[ -z "${DEFAULTCOMPSXML}" ] && DEFAULTCOMPSXML=http://mirror.fuel-infra.org/fwm/6.0/centos/os/x86_64/comps.xml
# Update repository metadata
[ ! -e "${LOCAL_REPO_CENTOS_PATH}/comps.xml" ] && wget "${DEFAULTCOMPSXML}" -O "${LOCAL_REPO_CENTOS_PATH}/comps.xml"
createrepo --pretty --database --update -g "${LOCAL_REPO_CENTOS_PATH}/comps.xml" -o "${LOCAL_REPO_CENTOS_PATH}/x86_64/" "${LOCAL_REPO_CENTOS_PATH}/x86_64"
createrepo --pretty --database --update -o "${LOCAL_REPO_CENTOS_PATH}/Source/" "${LOCAL_REPO_CENTOS_PATH}/Source"
# And sign repo
if [ -n "${SIGKEYID}" ] ; then
  rm -f "${LOCAL_REPO_CENTOS_PATH}/x86_64/repodata/repomd.xml.asc"
  gpg --armor --local-user "${SIGKEYID}" --detach-sign "${LOCAL_REPO_CENTOS_PATH}/x86_64/repodata/repomd.xml"
  gpg --armor --local-user "${SIGKEYID}" --detach-sign "${LOCAL_REPO_CENTOS_PATH}/Source/repodata/repomd.xml"
  [ -f "RPM-GPG-KEY" ] && cp RPM-GPG-KEY "${LOCAL_REPO_CENTOS_PATH}/RPM-GPG-KEY-${PROJECT_NAME}${PROJECT_VERSION}"
fi

############################### Build Debian Packages ################

# create structure for deb
LOCAL_REPO_UBUNTU_PATH="${LOCAL_REPO_PATH}/ubuntu/"
mkdir -p "${LOCAL_REPO_UBUNTU_PATH}"

# if user deines EXTRA_DEB_REPOS let's pass it to build root
[ -n "${EXTRA_DEB_REPOS}" ] && export EXTRAREPO="${EXTRA_DEB_REPOS}"
# build packages and inject deb in future mirror
for repo in ${WORKSPACE}/build-fuel-packages/repos/*/; do
  pushd "${repo}"
  PACKAGE=$(echo "${repo%/}" | awk -F/ '{print $NF}')
  export PACKAGENAME="openstack/${PACKAGE}"
  export SRC_PROJECT="${PACKAGENAME}"
  export CUSTOM_SRC_PATH="${repo}"
  # we have debian specs, so let's build deb package
  if [ -d "${repo}/debian" ]; then
    DIST=trusty bash -x "${WORKSPACE}/perestroika/build-fuel-deb.sh"
    cp -rv "${repo}"/wrk-build/src-to-build/buildresult/* "${LOCAL_REPO_UBUNTU_PATH}"
  fi
  popd
done
# unset EXTRAREPO, since EXTRAREPO is also used for rpm packages
unset EXTRAREPO

#######################################################################

DEB_COMPONENT=main

DBDIR="+b/db"
CONFIGDIR="${LOCAL_REPO_UBUNTU_PATH}/conf"
DISTDIR="${LOCAL_REPO_UBUNTU_PATH}/public/dists/"
OUTDIR="+b/public/"
if [ ! -d "${CONFIGDIR}" ] ; then
  mkdir -p "${CONFIGDIR}"
  for dist_name in ${DEB_DIST_NAME}; do
    cat >> "${CONFIGDIR}/distributions" << EOF
Origin: ${ORIGIN}
Label: ${DEB_DIST_NAME}
Suite: ${dist_name}
Codename: ${dist_name}
Version: ${PROJECT_VERSION}
Architectures: amd64 i386 source
Components: main restricted
UDebComponents: main restricted
Contents: . .gz .bz2

EOF

    reprepro --basedir "${LOCAL_REPO_UBUNTU_PATH}" --dbdir "${DBDIR}" \
        --outdir "${OUTDIR}" --distdir "${DISTDIR}" --confdir "${CONFIGDIR}" \
        export "${dist_name}"
    # Fix Codename field
    release_file="${DISTDIR}/${dist_name}/Release"
    sed "s|^Codename:.*$|Codename: ${DEB_DIST_NAME}|" \
        -i "${release_file}"
    rm -f "${release_file}.gpg"
    # ReSign Release file
    [ -n "${SIGKEYID}" ] \
        && gpg --sign --local-user "${SIGKEYID}" -ba \
        -o "${release_file}.gpg" "${release_file}"
  done

fi

OUTDIR="${LOCAL_REPO_UBUNTU_PATH}/public/"

REPREPRO_OPTS="--verbose --basedir ${LOCAL_REPO_PATH} --dbdir ${DBDIR} \
    --outdir ${OUTDIR} --distdir ${DISTDIR} --confdir ${CONFIGDIR}"
REPREPRO_COMP_OPTS="${REPREPRO_OPTS} --component ${DEB_COMPONENT}"

# Parse incoming files
BINDEBLIST=""
BINDEBNAMES=""
BINUDEBLIST=""
BINSRCLIST=""
for binary in ${LOCAL_REPO_UBUNTU_PATH}/* ; do
  case ${binary##*.} in
      deb) BINDEBLIST="${BINDEBLIST} ${binary}"
           BINDEBNAMES="${BINDEBNAMES} ${binary##*/}"
           ;;
     udeb) BINUDEBLIST="${BINUDEBLIST} ${binary}" ;;
      dsc) BINSRCLIST="${binary}" ;;
  esac
done


SRC_NAME=$(awk '/^Source:/ {print $2}' ${BINSRCLIST})

# Add .deb binaries
if [ "${BINDEBLIST}" != "" ]; then
    reprepro ${REPREPRO_COMP_OPTS} includedeb ${DEB_DIST_NAME} ${BINDEBLIST} \
        || error "Can't include packages"
fi
# Add .udeb binaries
if [ "${BINUDEBLIST}" != "" ]; then
    reprepro ${REPREPRO_COMP_OPTS} includeudeb ${DEB_DIST_NAME} ${BINUDEBLIST} \
        || error "Can't include packages"
fi

# Replace sources
# TODO: Get rid of replacing. Just increase version properly
if [ "${BINSRCLIST}" != "" ]; then
    reprepro "${REPREPRO_COMP_OPTS}" --architecture source \
        remove ${DEB_DIST_NAME} ${SRC_NAME} || :
    reprepro ${REPREPRO_COMP_OPTS} includedsc ${DEB_DIST_NAME} ${BINSRCLIST} \
        || error "Can't include packages"
fi

# Fix Codename field
release_file="${DISTDIR}/${DEB_DIST_NAME}/Release"
sed "s|^Codename:.*$|Codename: ${DEB_BASE_DIST_NAME}|" -i "${release_file}"

# Resign Release file
rm -f "${release_file}.gpg"
pub_key_file="${LOCAL_REPO_UBUNTU_PATH}/public/archive-${PROJECT_NAME}${PROJECT_VERSION}.key"
if [ -n "${SIGKEYID}" ] ; then
    gpg --sign --local-user "${SIGKEYID}" -ba -o "${release_file}.gpg" "${release_file}"
    [ ! -f "${pub_key_file}" ] && touch "${pub_key_file}"
    gpg -o "${pub_key_file}.tmp" --armor --export "${SIGKEYID}"
    if diff -q "${pub_key_file}" "${pub_key_file}.tmp" &>/dev/null ; then
        rm "${pub_key_file}.tmp"
    else
        mv "${pub_key_file}.tmp" "${pub_key_file}"
    fi
else
    rm -f "${pub_key_file}"
fi


##########################################################################################
# publish everything to web-share
mkdir -p "${WEB_SHARE_ROOT}/${WEB_SHARE_REPO}/ubuntu/${PROJECT_NAME}${PROJECT_VERSION}"

rsync -av "${LOCAL_REPO_PATH}/centos/" "${WEB_SHARE_ROOT}/${WEB_SHARE_REPO}/centos"
rsync -av "${LOCAL_REPO_PATH}/ubuntu/public/" "${WEB_SHARE_ROOT}/${WEB_SHARE_REPO}/ubuntu/${PROJECT_NAME}${PROJECT_VERSION}"

echo "http://$(hostname)/packages/${WEB_SHARE_REPO}" > "${WORKSPACE}/mirror.txt"
