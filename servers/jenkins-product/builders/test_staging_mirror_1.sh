export MIRROR_DETECT=$(echo $FUEL_MAIN_BRANCH | grep '^stable\>/\<' | sed -e 's|^stable/||')
[ -z "$MIRROR_DETECT" ]  && [ -z "$MIRROR" ] && exit 1:w

export MIRROR=${MIRROR_DETECT:-$MIRROR}
export MIRROR_HOST=osci-mirror-srt.srt.mirantis.net
export MIRROR_VERSION=${MIRROR_VERSION:-$(rsync -l rsync://${MIRROR_HOST}/mirror/fwm/files/$MIRROR-staging | awk '/^l/ {print $NF}')}


echo "MIRROR = ${MIRROR}" > $WORKSPACE/mirror_staging.txt
echo "MIRROR_VERSION = ${MIRROR_VERSION}" >> $WORKSPACE/mirror_staging.txt
echo "STABLE_VERSION = ${MIRROR_VERSION}" >> $WORKSPACE/mirror_staging.txt
echo "MIRROR_BASE = http://${MIRROR_HOST}/fwm/files/${MIRROR_VERSION}" >> $WORKSPACE/mirror_staging.txt

rm -f build_description.*
