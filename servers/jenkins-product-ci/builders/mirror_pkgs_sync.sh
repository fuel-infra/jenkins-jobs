#!/bin/bash

set -ex
export LANG=C

DEBMIRROR=/usr/bin/debmirror
DEBMIRROR_OPTS=(-a amd64,i386 --di-arch=amd64 --method=rsync --no-check-gpg --progress \
                --nosource --rsync-extra=indices,trace \
                --exclude=i386.deb \
                --exclude-deb-section=games --checksums)

RSYNC=/usr/bin/rsync
RSYNC_OPTS=(-av --delete)
RSYNC_REMOTE_OPTS=(-aH --delete)

OUTPUT="[mirror]"
MAX_DAYS="${MAX_DAYS:-30}"

if [ -z "${DST_DIR}" ] || [ -z "${SRC_URL}" ] || [ -z "${DST_PREFIX}" ] \
    || [ -z "${TMP_PREFIX}" ] || [ -z "${DEFAULT_URL}" ] || [ -z "${MIRRORS}" ]
then
  echo 'ERROR: Environment settings are not set!'
  exit 1
fi

# check if just one parameter, add | if required
if [[ ! ${MIRRORS} == *"|"* ]]
then
  MIRRORS="${MIRRORS}|"
fi

# get date for current sync naming
DATE=$(date +%F-%H%M%S)

# make temporary directory for sync
TMP_DIR=$(mktemp -d -p "${TMP_PREFIX}")

# get prefix for DST_DIR
PREFIX_DIR=$(echo "${DST_DIR}" | cut -f 1 -d %)

# get rsync destination and link-dest parameters
RSYNC_DEST="${DST_PREFIX}/${DST_DIR//%version%/-${DATE}}"
LAST_DEST="${DST_PREFIX}/${DST_DIR//%version%/-latest}"

# set latest link
if [ -z "${FORCED_LINK}" ]
then
  LINK="${PREFIX_DIR}-${DATE}"
else
  LINK="${PREFIX_DIR}-${FORCED_LINK}"
fi

# if older version exists, use hardlink switch
if [ -d "${LAST_DEST}" ]
then
  # copy everything except project dir using hardlinks
  find -H "${LAST_DEST}" -mindepth 1 -maxdepth 1 -not -name project | while read -r line
  do
    cp -al "${line}" "${TMP_DIR}"
  done
fi

STATUS=-1

# synchronize from upstream if not only setting the link
if [ -z "${FORCED_LINK}" ]
then
  if [[ "${SRC_URL}" =~ mirror:// ]]
  then
    if [ -z "${DISTRIBUTIONS}" ] || [ -z "${INST_DISTRIBUTIONS}" ] || [ -z "${SECTIONS}" ]
    then
      echo 'ERROR: Missing debmirror settings!'
      exit 1
    fi
    # run debmirror
    HOST=$(echo "${SRC_URL}" | cut -f 3 -d '/')
    URL=$(echo "${SRC_URL}" | cut -f 4- -d '/')
    ${DEBMIRROR} "${DEBMIRROR_OPTS[@]}" -s "${SECTIONS}" -h "${HOST}" \
        -r /"${URL}" -d "${DISTRIBUTIONS}" --di-dist="${INST_DISTRIBUTIONS}" "${TMP_DIR}" \
        || STATUS=${?}
    # remove .temp directory
    rm -rf "${TMP_DIR}"/.temp
  else
    # run rsync
    ${RSYNC} "${RSYNC_OPTS[@]}" "${SRC_URL}" "${TMP_DIR}" || STATUS=${?}
  fi
else
  echo 'Upstream synchronization skipped - setting link/htm files only!'
fi

# if sync is completed, move to destination directory and create latest link
if [ ${STATUS} -eq -1 ]
then
  # make directory and move temporary repo
  mkdir -p "${RSYNC_DEST}"
  mv -T "${TMP_DIR}" "${RSYNC_DEST}"
  # enforce creation date if mirror was not changed
  touch "${RSYNC_DEST}"
  OUTPUT+="<a href=${DEFAULT_URL}/${LINK}>${DST_DIR//%version%/-latest}</a><br>"
else
  echo "ERROR: Mirroring of ${RSYNC_DEST} failed!"
  rm -rf "${TMP_DIR}"
  exit 1
fi

echo "${OUTPUT}"

# clean mirrors older then 30 days
find "${DST_PREFIX}" -maxdepth 1 -mindepth 1 -name "${PREFIX_DIR}-*" -type d | while read line
do
  # parse date from directory name
  snapshot_date=$(echo "$line" | tail -c 18 | cut -d - -f -3)
  snapshot_time_not_separated=$(echo "$line" | tail -c 7)
  snapshot_time="${snapshot_time_not_separated:0:2}:"
  snapshot_time+="${snapshot_time_not_separated:2:2}:"
  snapshot_time+="${snapshot_time_not_separated:4:2}"
  snapshot_fulltime="$snapshot_date $snapshot_time"
  snapshot_unix=$(date -d "$snapshot_fulltime" +%s)
  # check if snapshot should be removed
  current_unix=$(date +%s)
  age=$((current_unix - snapshot_unix))
  if [ ${age} -gt $((MAX_DAYS*24*60*60)) ]
  then
    echo "Removing snapshot: ${line}"
    rm -rf "${line}"
  fi
done

# prepare post-synchronization script
TMP_SYNC=$(mktemp -p "${TMP_PREFIX}")

# latest name
LATEST_NAME="${PREFIX_DIR}-latest"

# synchronize all mirrors
i=1
while [ ! -z "$(echo "${MIRRORS}" | cut -f ${i} -d '|')" ]
do
  # get mirror url
  MIRROR=$(echo "${MIRRORS}" | cut -f ${i} -d '|')
  i=$((i+1))
  TMPSYNC_DIR=$(mktemp -d -p "${TMP_PREFIX}")
  HOST=$(echo "${MIRROR}" | cut -f 3 -d '/')
  URL=$(echo "${MIRROR}" | cut -f 5- -d '/')
  # prepare symbolic link and htm file in temporary directory
  ln -s "${LINK}" "${TMPSYNC_DIR}"/"${LATEST_NAME}"
  echo "http://${HOST}/${URL}/${LINK}" > \
    "${TMPSYNC_DIR}"/"${PREFIX_DIR}"-latest.htm
  # synchronzie mirror without symlink and htm file
  # and add symbolic link and htm synchronization to queue
  ${RSYNC} -v "${RSYNC_REMOTE_OPTS[@]}" \
    --include "${PREFIX_DIR}-*/***" \
    --exclude "*" "${DST_PREFIX}"/ "${MIRROR}" && \
    echo "${RSYNC}" -av "${TMPSYNC_DIR}"/ "${MIRROR}" >> "${TMP_SYNC}" || STATUS=${?}
  echo rm -rf "${TMPSYNC_DIR}" >> "${TMP_SYNC}"
done

# update links on main node and all satellite mirrors
if [ ${STATUS} -eq -1 ]
then
  # update link on main mirror
  rm -f "${DST_PREFIX}"/"${LATEST_NAME}"
  ln -s "${LINK}" "${DST_PREFIX}"/"${LATEST_NAME}"
  # update index on main mirror
  echo "${DEFAULT_URL}/${LINK}" > "${DST_PREFIX}"/"${LATEST_NAME}".htm
  # update indexes and symlinks on satallite mirrors
  source "${TMP_SYNC}"
fi

# delete post-synchronization script
rm "${TMP_SYNC}"

if [ ${STATUS} -ne -1 ]
then
  exit 1
fi
