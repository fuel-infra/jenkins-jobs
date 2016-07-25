#!/bin/bash


set -ex
set -o pipefail

export LANG=C
RSYNC='/usr/bin/rsync'


function resolve_symlink() {
    local URL=$(echo "${1}" | sed -r 's[/+$[[')
    # disable because echo strips output
    # shellcheck disable=SC2005
    echo "$(${RSYNC} -l "${URL}" | awk '/^.+$/ {print $NF}' | sed -r 's[/+$[[')"
}


SAVE_LATEST_DAYS="${SAVE_LATEST_DAYS:-30}"
LOCAL_STORAGE="${LOCAL_STORAGE:-/var/www/mirror}"
TMP_PREFIX="${TMP_PREFIX:-/tmp}"

# get timestamp for current sync naming
TIMESTAMP=$(date -u +%F-%H%M%S)


if [ -z "${MIRROR_DIR}" ] || [ -z "${SOURCE_URL}" ] || [ -z "${LOCAL_STORAGE}" ] \
    || [ -z "${DEFAULT_URL}" ] || [ -z "${SYNC_LOCATIONS}" ]
then
  echo 'ERROR: Environment settings are not set!'
  exit 1
fi


BUILD_DESCRIPTION="[mirror]"

echo "${MIRROR_DIR}" | grep -q '%symlink_target%' \
    && SYMLINK_TARGET=$(resolve_symlink "${SOURCE_URL}") \
    || SYMLINK_TARGET=""

echo "${UPDATED_SYMLINKS}" | grep -q '%symlink_target%' \
    && SYMLINK_TARGET=${SYMLINK_TARGET:-$(resolve_symlink "${SOURCE_URL}")} \
    && UPDATED_SYMLINKS="${UPDATED_SYMLINKS//%symlink_target%/"${SYMLINK_TARGET}"}"

echo "${MIRROR_DIR}" | grep -qE '%timestamp%$' \
    || MIRROR_DIR+="%timestamp%"

# get prefix for MIRROR_DIR
MIRROR_NAME="$(echo ${MIRROR_DIR} \
                | sed -e 's[%timestamp%[[g' \
                      -e 's[%symlink_target%[-'${SYMLINK_TARGET}'[g')"
MIRROR_SNAPSHOT=$(echo "${MIRROR_DIR}" \
                    | sed -e 's[%timestamp%[-'"${TIMESTAMP}"'[g' \
                          -e 's[%symlink_target%[-'"${SYMLINK_TARGET}"'[g')
MIRROR_LATEST="${MIRROR_NAME}-latest"

# get rsync destination and link-dest parameters
RSYNC_DEST="${LOCAL_STORAGE}/${SNAPSHOTS_DIR}/${MIRROR_SNAPSHOT}"
LAST_DEST="${LOCAL_STORAGE}/${MIRROR_LATEST}"


# Sync options
RSYNC_OPTS=(-av --delete --link-dest=${LAST_DEST} ${RSYNC_EXTRA_PARAMS})
RSYNC_REMOTE_OPTS=(-aH --delete --no-perms --no-owner --no-group)

# make temporary directory for sync
TMP_DIR="${RSYNC_DEST}.tmp"
mkdir -p "${TMP_DIR}"


# set latest link
if [ -z "${FORCED_LINK}" ]
then
  LINK="${SNAPSHOTS_DIR}/${MIRROR_SNAPSHOT}"
else
  LINK="${SNAPSHOTS_DIR}/${MIRROR_NAME}-${FORCED_LINK}"
fi

STATUS=-1

# synchronize from upstream if not only setting the link
if [ -z "${FORCED_LINK}" ]
then
    # run rsync
    ${RSYNC} "${RSYNC_OPTS[@]}" "${SOURCE_URL}"/ "${TMP_DIR}"/ || STATUS=${?}
else
  echo 'Upstream synchronization skipped - setting link/htm files only!'
fi

# if sync is completed, move to destination directory and create latest link
if [ ${STATUS} -eq -1 ]
then
  # make directory and move temporary repo
  mv -T "${TMP_DIR}" "${RSYNC_DEST}"
  # enforce creation date if mirror was not changed
  touch "${RSYNC_DEST}"
  BUILD_DESCRIPTION+="<a href=${DEFAULT_URL}/${LINK}>${MIRROR_LATEST}</a><br>"
else
  echo "ERROR: Mirroring of ${RSYNC_DEST} failed!"
  rm -rf "${TMP_DIR}"
  exit 1
fi

echo "${BUILD_DESCRIPTION}"

# clean mirrors older then 30 days
find "${LOCAL_STORAGE}/${SNAPSHOTS_DIR}" -maxdepth 1 -mindepth 1 -name "${MIRROR_NAME}-*" -type d \
    | while read line
do
  echo "${line}" \
      | grep -E '.*/'"${MIRROR_NAME}"'-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}$' \
      || continue

  # parse date from directory name
  snapshot_date=$(echo "$line" | tail -c 18 | cut -d - -f -3)
  snapshot_time_not_separated=$(echo "$line" | tail -c 7)
  snapshot_time="${snapshot_time_not_separated:0:2}:"
  snapshot_time+="${snapshot_time_not_separated:2:2}:"
  snapshot_time+="${snapshot_time_not_separated:4:2}"
  snapshot_fulltime="$snapshot_date $snapshot_time"
  snapshot_unix=$(date -d "$snapshot_fulltime" +%s)
  # check if snapshot should be removed
  current_unix=$(date -u +%s)
  age=$((current_unix - snapshot_unix))
  if [ ${age} -gt $((SAVE_LATEST_DAYS*24*60*60)) ]
  then
    echo "Removing snapshot: ${line}"
    rm -rf "${line}"
  fi
done

# prepare post-synchronization script
TMP_SYNC=$(mktemp -p "${TMP_PREFIX:-.}")

# prepare symlinks and info files to sync
TMPSYNC_DIR=$(mktemp -d -p "${TMP_PREFIX:-.}")
# prepare symbolic link in temporary directory
for L in ${MIRROR_LATEST} ${UPDATED_SYMLINKS}; do
  LINK_PATH=$(dirname "${L}")
  LINK_NAME=$(basename "${L}")
  # Disabe because Regex used
  # shellcheck disable=SC2001
  PATH_TO_ROOT=$(echo "${LINK_PATH}" | sed -e 's|[^/\.]\+|..|g')
  mkdir -p "${TMPSYNC_DIR}/${LINK_PATH}"
  ln -sf "${PATH_TO_ROOT}/${LINK}" "${TMPSYNC_DIR}/${LINK_PATH}/${LINK_NAME}"
done

# synchronize all mirrors
for MIRROR in ${SYNC_LOCATIONS}; do
  # get mirror url
  HOST=$(echo "${MIRROR}" | cut -f 3 -d '/')
  URL=$(echo "${MIRROR}" | cut -f 5- -d '/')
  # prepare htm file in temporary directory
  # synchronzie mirror without symlink and htm file
  # and add symbolic link and htm synchronization to queue
  ${RSYNC} -v "${RSYNC_REMOTE_OPTS[@]}" \
    --exclude "${MIRROR_NAME}-*.tmp/***" \
    --include "${MIRROR_NAME}-*/***" \
    --exclude "*" \
    "${LOCAL_STORAGE}/${SNAPSHOTS_DIR}"/ "${MIRROR}/${SNAPSHOTS_DIR}"/ \
        && echo 'echo http://'"${HOST}"/"${URL}"/"${LINK}"' > '"${TMPSYNC_DIR}"/"${MIRROR_NAME}"'-latest.htm' >> "${TMP_SYNC}" \
        && echo "${RSYNC}" -alv "${TMPSYNC_DIR}"/ "${MIRROR}"/ >> "${TMP_SYNC}" \
        || STATUS=${?}
done
echo rm -rf "${TMPSYNC_DIR}" >> "${TMP_SYNC}"


# update links on main node and all satellite mirrors
if [ ${STATUS} -eq -1 ]
then
  # update link on main mirror
  ${RSYNC} -alv --no-times --no-perms --no-owner --no-group \
        "${TMPSYNC_DIR}/" "${LOCAL_STORAGE}/"
  # update index on main mirror
  echo "${DEFAULT_URL}/${LINK}" > "${LOCAL_STORAGE}/${MIRROR_LATEST}".htm
  # update indexes and symlinks on satallite mirrors
  source "${TMP_SYNC}"
fi

# delete post-synchronization script
rm "${TMP_SYNC}"

if [ ${STATUS} -ne -1 ]
then
  exit 1
fi
