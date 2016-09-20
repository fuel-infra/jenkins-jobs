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

# ===============================================
# check the options are set or use default values
if [ -z "${SOURCE_URL}" ] || [ -z "${MIRROR_NAME}" ] || [ -z "${SYNC_LOCATIONS}" ]
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

# =====================================
# install and activate trsync "${VENV}"
[ -d "${VENV}" ] || virtualenv "${VENV}"
source "${VENV}"/bin/activate
pip install -U "${TRSYNC_PIP_URL}"

report success "prepare_env" "virtualenv"

# =================
# store exit status
STATUS=-1

# =========================
# pull from source to local
trsync push \
        "${SOURCE_URL}" \
        "${MIRROR_NAME}" \
        --dest "${LOCAL_DIR}" \
        --symlinks "${MIRROR_NAME}" \
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
            "${LOCAL_DIR}"/"${MIRROR_NAME}" \
            "${MIRROR_NAME}" \
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
    # shellcheck disable=SC2086
    trsync symlink \
            --dest "${D}" \
            --symlinks ${UPDATED_SYMLINKS} \
            --target="${SNAPSHOTS_DIR}"/"${MIRROR_NAME}-${TIMESTAMP}" \
            --update \
        || EXITCODE=${?}

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
