export MIRROR_DETECT=$(echo $FUEL_MAIN_BRANCH | grep '^stable\>/\<' | sed -e 's|^stable/||')
[ -z "$MIRROR_DETECT" ]  && [ -z "$MIRROR" ] && exit 1

export MIRROR=${MIRROR_DETECT:-$MIRROR}
export MIRROR_HOST=osci-mirror-srt.srt.mirantis.net
export MIRROR_VERSION=${MIRROR_VERSION:-$(rsync -l rsync://${MIRROR_HOST}/mirror/fwm/files/$MIRROR-staging | awk '/^l/ {print $NF}')}


PARAM_FILE=$WORKSPACE/mirror_staging.txt
rm -f $PARAM_FILE
echo "MIRROR = ${MIRROR}" >>$PARAM_FILE
echo "MIRROR_VERSION = ${MIRROR_VERSION}" >>$PARAM_FILE
echo "STABLE_VERSION = ${MIRROR_VERSION}" >>$PARAM_FILE
MIRROR_BASE=http://${MIRROR_HOST}/fwm/files/${MIRROR_VERSION}
echo "MIRROR_BASE = $MIRROR_BASE" >>$PARAM_FILE
echo "fuelmain_gerrit_commit = ${extra_commits}" >>$PARAM_FILE
if [ -n "$MIRROR_UBUNTU" ]; then
    echo "MIRROR_UBUNTU = $MIRROR_UBUNTU" >>$PARAM_FILE
fi
if [ "$MIRROR_UBUNTU_SECURITY" = "MIRROR_UBUNTU" ]; then
    echo "MIRROR_UBUNTU_SECURITY = $MIRROR_UBUNTU" >>$PARAM_FILE
elif [ -n "$MIRROR_UBUNTU_SECURITY" ]; then
    echo "MIRROR_UBUNTU_SECURITY = $MIRROR_UBUNTU_SECURITY" >>$PARAM_FILE
fi
if [ -n "$USE_MIRROR" ]; then
    echo "USE_MIRROR = $USE_MIRROR" >>$PARAM_FILE
fi

rm -f build_description.*
