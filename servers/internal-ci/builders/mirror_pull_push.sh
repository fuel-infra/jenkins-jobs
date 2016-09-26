#!/bin/bash -xe

set -ex
set -o pipefail

export LANG=C

# ==============
# prepare report
export REPORT='<testsuite>'

function report() {
    local RESULT=$1
    shift
    if [ "${RESULT}" = "success" ]; then
        REPORT+='<testcase classname="'${1}'" name="'${2}'" />'
    else
        REPORT+='<testcase classname="'${1}'" name="'${2}'"><failure /></testcase>'
    fi
}

function save_report() {
    REPORT+='</testsuite>'
    echo "${REPORT}" > results.xml
}

# ==================================
# Resolve symlink on upstream mirror

function resolve_symlink() {
    local URL
    URL=$(echo "${1}" | sed -r 's[/+$[[')
    local RESULT=$?
    # disable because echo strips output
    # shellcheck disable=SC2005
    echo "$(rsync -l "${URL}" | awk '/^.+$/ {print $NF}' | sed -r 's[/+$[[')"
    return "${RESULT}"
}

# ===============================================
# check the options are set or use default values
if [ -z "${MIRROR_DIR}" ] || [ -z "${SOURCE_URL}" ] || [ -z "${SYNC_LOCATIONS}" ]
then
  echo 'ERROR: Environment settings are not set!'
  exit 1
fi
VENV=${VENV:-.venv}
TRSYNC_PIP_URL=${TRSYNC_PIP_URL:-git+ssh://openstack-ci-jenkins@review.fuel-infra.org:29418/infra/trsync@v0.8}
SNAPSHOT_LIFETIME=${SNAPSHOT_LIFETIME:-30}
UPDATED_SYMLINKS=${UPDATED_SYMLINKS:-}
LOCAL_DIR=${LOCAL_DIR:-./mirrors}
SNAPSHOTS_DIR=${SNAPSHOTS_DIR:-snapshots}

# =================================
# get timestamp for snapshot naming
TIMESTAMP=${TIMESTAMP:-$(date -u +%F-%H%M%S)}

# resolve SOURCE_URL symlink if MIRROR_DIR contains %symlink_target% macros
echo "${MIRROR_DIR}" | grep -q '%symlink_target%' \
    && SYMLINK_TARGET=$(resolve_symlink "${SOURCE_URL}") \
    && MIRROR_DIR="${MIRROR_DIR//%symlink_target%/-"${SYMLINK_TARGET}"}" \
    || SYMLINK_TARGET=""

echo "${UPDATED_SYMLINKS}" | grep -q '%symlink_target%' \
    && SYMLINK_TARGET=${SYMLINK_TARGET:-$(resolve_symlink "${SOURCE_URL}")} \
    && UPDATED_SYMLINKS="${UPDATED_SYMLINKS//%symlink_target%/"${SYMLINK_TARGET}"}"

# =====================================
# install and activate trsync "${VENV}"
[ -d "${VENV}" ] || virtualenv "${VENV}"
source "${VENV}"/bin/activate
pip install -U "${TRSYNC_PIP_URL}"

# =================
# store exit status
STATUS=-1

# =========================
# pull from source to local
trsync push \
        "${SOURCE_URL}" \
        "${MIRROR_DIR}" \
        --dest "${LOCAL_DIR}" \
        --symlinks "${MIRROR_DIR}" \
        --timestamp "${TIMESTAMP}" \
        --snapshot-lifetime=None \
        --init-directory-structure \
        --extra "${PULL_RSYNC_EXTRA_PARAMS}" \
    || STATUS=${?}

if [ ${STATUS} -eq -1 ]; then
    report success "Pull_from_upstream" "${SOURCE_URL}"
else
    report failure "Pull_from_upstream" "${SOURCE_URL}"
    save_report
    exit 1
fi

# ====================
# push to destinations
for D in ${SYNC_LOCATIONS}; do
    EXITCODE=-1
    trsync push \
            "${LOCAL_DIR}"/"${MIRROR_DIR}" \
            "${MIRROR_DIR}" \
            --dest "${D}" \
            --timestamp "${TIMESTAMP}" \
            --snapshot-lifetime="${SNAPSHOT_LIFETIME}" \
            --snapshots-dir "${SNAPSHOTS_DIR}" \
            --init-directory-structure \
        || EXITCODE=${?}

    if [ ${EXITCODE} -eq -1 ]; then
        report success "Push_to" "${D}"
    else
        report failure "Push_to" "${D}"
        save_report
        exit 1
    fi
done

# ===============
# update symlinks
for D in ${SYNC_LOCATIONS}; do
    EXITCODE=-1
    for symlink in $UPDATED_SYMLINKS ; do
        unset _prefix
        _slashcnt=$(echo "$symlink" | sed -r 's|[^/]||g')
        # it's ok to not use _cnt
        # shellcheck disable=SC2034
        for _cnt in $(seq "${#_slashcnt}") ; do
            _prefix="${_prefix}../"
        done
        trsync symlink \
                --dest "$D" \
                --symlinks "$symlink" \
                --target="${_prefix}${SNAPSHOTS_DIR}/${MIRROR_DIR}-${TIMESTAMP}" \
                --update \
            || EXITCODE="$?"
    done

    if [ ${EXITCODE} -eq -1 ]; then
        report success "Symlinks_update" "${D}"
    else
        report failure "Symlinks_update" "${D}"
        STATUS=1
    fi
done

# ======================
# store the xunit report
save_report
if [ ! ${STATUS} -eq -1 ]; then
    exit 1
fi
