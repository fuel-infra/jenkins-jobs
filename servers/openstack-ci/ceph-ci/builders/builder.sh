#!/bin/bash -ex

########################################
#
# Initialize jenkins params
#

JOB_NAME=${JOB_NAME:-ceph-ci}
WORKSPACE=${WORKSPACE:-$(pwd)/$JOB_NAME}

SRC_PATH=${WORKSPACE}/sourcecode
GIT_BRANCH=${GIT_BRANCH:-jewel-xenial}

########################################
#
# Get package source
# In commont case it sould be cloned by
# jenkins.
#
if [ ! -d "$SRC_PATH" ]; then
    SRC_URL=https://github.com/asheplyakov/pkg-ceph
    git clone "$SRC_URL" "$SRC_PATH"
fi

########################################
#
# Initialize GnuPG params
#
gpg_home=$(mktemp -d)
chmod -R 700 "$gpg_home"
gpg_keyserver="pgp.mit.edu"
trustdb="
#asheplyakov
A3D53E274216C16687E298D78A8BD63F69514C18:6:
"
for line in $trustdb ; do
    fingerprint=${line%%:*}
    long_key_id=${fingerprint:24:16}
    [ -n "$long_key_id" ] \
        && LANG=C gpg --homedir "$gpg_home" --keyserver "$gpg_keyserver" \
             --recv-keys "$long_key_id"
done

echo "$trustdb" \
    | grep -v "^$" \
    | LANG=C gpg --homedir "$gpg_home" --import-ownertrust

########################################
#
# Verify tag signature and get build
# target according to branch name
#

GIT_TAG=$(git -C "$SRC_PATH" describe)
GNUPGHOME="$gpg_home" git -C "$SRC_PATH" tag -v "$GIT_TAG"

GIT_BRANCH=$(git -C "$SRC_PATH" branch --remotes --contains "tags/$GIT_TAG" | head -n 1 | awk '{print $NF}')
GIT_REMOTE=$(git -C "$SRC_PATH" remote)
GIT_BRANCH=${GIT_BRANCH/$GIT_REMOTE\//}
git -C "$SRC_PATH" checkout -B "$GIT_BRANCH"

# Clean up GnuPG params
[ -d "$gpg_home" ] && rm -rfv "$gpg_home"

########################################
#
# Initialize build params
#
[ "$GIT_BRANCH" == "master" ] && DIST=xenial

DIST=${DIST:-${GIT_BRANCH##*-}}
CONTAINER_NAME=$JOB_NAME
CACHE_DIR=${WORKSPACE}/../.${JOB_NAME}-cache/sbuild-cache
CCACHE_DIR=${WORKSPACE}/../.${JOB_NAME}-cache/ccache-$GIT_BRANCH
BUILD_DIR=${WORKSPACE}/../.${JOB_NAME}-cache/build
mkdir -p "${WORKSPACE}/../.${JOB_NAME}-cache"

RESULT_DIR=${WORKSPACE}/buildresult/${GIT_TAG##*/}
mkdir -p "${WORKSPACE}/buildresult"

########################################
#
# Generate apt sources for selected
# distro
#
case "$DIST" in
    jessie)
        MIRROR="http://httpredir.debian.org/debian"
        SUITES="main"
        ;;
    *)
        MIRROR="http://archive.ubuntu.com/ubuntu"
        SUITES="main universe multiverse restricted"
        ;;
esac
APT_SOURCES_CONTENT="
deb $MIRROR ${DIST} ${SUITES}
deb $MIRROR ${DIST}-updates ${SUITES}"

create-docker-image() {
    local tmpdir=$(mktemp -d)
    cat > "${tmpdir}/Dockerfile" <<-HERE
		FROM ubuntu:trusty
		ENV DEBIAN_FRONTEND noninteractive
		ENV DEBCONF_NONINTERACTIVE_SEEN true
		RUN rm -f /etc/apt/sources.list.d/proposed.list && \\
		    apt-get update && apt-get -y install rng-tools sbuild debhelper ccache && \\
		    apt-get -y install git-buildpackage javahelper dh-autoreconf dh-systemd && \\
		    apt-get clean && \\
		    rngd -r /dev/urandom && \\
		    sbuild-update --keygen && \\
		    mkdir -p /srv/build && \\
		    sed -i '/^1/d' /etc/sbuild/sbuild.conf && \\
		    echo "\\\$build_arch_all = 1;" >> /etc/sbuild/sbuild.conf && \\
		    echo "\\\$log_colour = 0;" >> /etc/sbuild/sbuild.conf && \\
		    echo "\\\$apt_allow_unauthenticated = 0;" >> /etc/sbuild/sbuild.conf && \\
		    echo "\\\$apt_update = 0;" >> /etc/sbuild/sbuild.conf && \\
		    echo "\\\$apt_clean = 1;" >> /etc/sbuild/sbuild.conf && \\
		    echo "\\\$build_source = 1;" >> /etc/sbuild/sbuild.conf && \\
		    echo "\\\$build_dir = '/srv/build';" >> /etc/sbuild/sbuild.conf && \\
		    echo "\\\$log_dir = '/srv/build';" >> /etc/sbuild/sbuild.conf && \\
		    echo "\\\$stats_dir = '/srv/build';" >> /etc/sbuild/sbuild.conf && \\
		    echo "\\\$verbose = 100;" >> /etc/sbuild/sbuild.conf && \\
		    echo "\\\$mailprog = '/bin/true';" >> /etc/sbuild/sbuild.conf && \\
		    echo "\\\$purge_build_deps = 'always';" >> /etc/sbuild/sbuild.conf && \\
		    echo "1;" >> /etc/sbuild/sbuild.conf
	HERE
    docker build -t "$CONTAINER_NAME" "${tmpdir}/"
    [ -d "$tmpdir" ] && rm -rf "$tmpdir"
}

create-chroot() {
   # Allow word splitting
   #shellcheck disable=SC2046
   [ $(docker images -q "$CONTAINER_NAME" | wc -l) -eq 0 ] \
        && create-docker-image
    docker run --privileged --rm \
        -v "$CACHE_DIR":/srv/images \
        "$CONTAINER_NAME" \
        bash -c "
            mkdir -p /srv/images/chroot.d
            rm -rf /etc/schroot/chroot.d
            ln -s /srv/images/chroot.d /etc/schroot/chroot.d
            rm -rf /srv/images/$DIST
            rm -f /etc/schroot/chroot.d/${DIST}*
            sbuild-createchroot $DIST /srv/images/$DIST $MIRROR \
                --include=ccache
            mv /etc/schroot/chroot.d/${DIST}* /etc/schroot/chroot.d/$DIST"
}

update-chroot() {
    # Allow word splitting
    #shellcheck disable=SC2046
    [ $(docker images -q "$CONTAINER_NAME" | wc -l) -eq 0 ] \
        && create-docker-image
    [ ! -d "${CACHE_DIR}/$DIST" ] && create-chroot
    APT_SOURCES_CONTENT_BASE64=$(echo "$APT_SOURCES_CONTENT" | base64 -w0)
    docker run --privileged --rm \
        -v "$CACHE_DIR":/srv/images \
        "$CONTAINER_NAME" \
        bash -c "
            rm -rf /etc/schroot/chroot.d
            ln -s /srv/images/chroot.d /etc/schroot/chroot.d
            echo $APT_SOURCES_CONTENT_BASE64 | base64 -d \
                > /srv/images/${DIST}/etc/apt/sources.list
            sbuild-update -udcar $DIST"
}

update-chroot

if [ -z "$JENKINS_URL" ] ; then
    # Add timestamp to console log for debug puprose
    STARTTIME=$(date +%s)
    # Allow word splitting
    # Do not expand variables
    #shellcheck disable=SC2016,SC2086
    exec 1> >(exec perl -e '$|=1;while(<STDIN>){my $p=sprintf("[%5ds] ", time()-'$STARTTIME');print STDOUT $p.$_}') 2>&1
fi

########################################
#
# Build source
#

docker run --privileged --rm \
    -v "$CACHE_DIR":/srv/images \
    -v "$CCACHE_DIR":/srv/ccache \
    -v "$BUILD_DIR":/srv/build \
    -v "$SRC_PATH":/srv/git:ro \
    "$CONTAINER_NAME" \
    bash -c "
        rm -rf /srv/build/*
        cp /srv/images/chroot.d/$DIST /etc/schroot/chroot.d/
        echo '/srv/ccache /srv/ccache none rw,bind 0 0' >> /etc/schroot/sbuild/fstab
        echo 'command-prefix=/srv/ccache/sbuild-setup' \
             >> /etc/schroot/chroot.d/$DIST
        cat > /srv/ccache/sbuild-setup <<-HERE
			#!/bin/sh
			export CCACHE_DIR=/srv/ccache
			export CCACHE_UMASK=002
			export CCACHE_COMPRESS=1
			unset CCACHE_HARDLINK
			export PATH=\"/usr/lib/ccache:\\\$PATH\"
            export CC='ccache gcc'
            export CXX='ccache g++'
			exec \"\\\$@\"
			HERE
        chmod +x /srv/ccache/sbuild-setup
        cp -R /srv/git /srv/source
        cd /srv/source
        DEB_BUILD_OPTIONS='parallel=$(nproc) nocheck'
        export DEB_BUILD_OPTIONS
        gbp buildpackage \
            --git-ignore-new \
            --git-pristine-tar \
            --git-cleaner='git clean -dfx' \
            --git-export-dir='/srv/build' \
            --git-builder='sbuild -v --dist=$DIST'
        echo \$? > /srv/build/exitstatus
        env CCACHE_DIR=/srv/ccache ccache --show-stats
        chown -R $(id -u):$(id -g) /srv/build"

EXIT_STATUS=$(cat "${BUILD_DIR}/exitstatus" || echo 1)
[ -f "${BUILD_DIR}/exitstatus" ] && rm -v "${BUILD_DIR}/exitstatus"

########################################
#
# Move build result to the job workspace
# in order to archive it as artifact
# Remove broken symlinks
#

[ -d "$RESULT_DIR" ] && rm -rf "$RESULT_DIR"
[ -d "$BUILD_DIR" ] && mv "$BUILD_DIR" "$RESULT_DIR"
find "$RESULT_DIR/" -maxdepth 1 -type l -exec rm {} \;
exit "$EXIT_STATUS"
