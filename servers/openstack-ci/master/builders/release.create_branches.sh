#!/bin/bash -xe

function fail() {
    echo -e "ERROR: $@"
    exit 1
}

echo "=========================================PREPARE========================================="

export LANG=C

if [ "${CHANGE_BRANCH_CHANGEID}" != "" ]; then
    echo "WARNING: Setting DRY_RUN=true because CHANGE_BRANCH_CHANGEID=${CHANGE_BRANCH_CHANGEID} (is not empty)"
    DRY_RUN="true"
fi

if [ "${DRY_RUN}" = "false" ] && [ "${MARK_BUILD_BY_TAG}" = "" ]; then
    fail "Please specify MARK_BUILD_BY_TAG parameter for build with DRY_RUN=false"
fi

pushd release_scripts

    REMOTE="origin"
    ORIGIN_HOST="$(git remote -v | awk -F '[:/]' '/^'${REMOTE}'.+fetch/ {print $4}')"
    ORIGIN_PORT="$(git remote -v | awk -F '[:/]' '/^'${REMOTE}'.+fetch/ {print $5}')"

    if [ -n "${CHANGE_BRANCH_CHANGEID}" ]; then
        CHANIGEID_INFO="$(ssh -p ${ORIGIN_PORT} ${ORIGIN_HOST} gerrit query --format TEXT --current-patch-set ${CHANGE_BRANCH_CHANGEID})"

        # check that CHANGE_BRANCH_CHANGEID's project is equals to release_scripts project
        ORIGIN_PROJECT="$(git remote -v | awk '/^'${REMOTE}'.+fetch/ {print $2}' | sed -r 's|^.+://[^/]+/||')"
        echo -e "${CHANIGEID_INFO}" | awk '/project:/ {print $NF}' | grep ${ORIGIN_PROJECT} \
            || fail "Wrong CHANGE_REQUEST's project. Should be ${ORIGIN_PROJECT}. Wrong CHANGE_BRANCH_CHANGEID==${CHANGE_BRANCH_CHANGEID}?"

        # checkout to revision specified by CHANGE_BRANCH_CHANGEID
        CR_REF="$(echo -e "${CHANIGEID_INFO}" | awk '/ref:/ {print $NF}')"
        git fetch ${REMOTE} ${CR_REF} && git checkout FETCH_HEAD
    fi

    # check that tag specified by MARK_BUILD_BY_TAG doesn't exists
    if [ -n "${MARK_BUILD_BY_TAG}" ]; then
        git fetch --all --tags
        git tag | grep -E "${MARK_BUILD_BY_TAG}-mark" \
            && git log -n1 --decorate ${MARK_BUILD_BY_TAG}-mark \
            && fail "Tag ${MARK_BUILD_BY_TAG}-mark already exists." \
            || :
    fi

    # disable recreation of existing branches if needed
    if [ "${FORCE_RECREATE}" != "true" ]; then
        echo "Disable recreation of existent branches because FORCE_RECREATE=${FORCE_RECREATE}"
        sed -r 's|^( +)(if_branch_exists:)( +recreate_new)$|\1#\2\3\n\1\2 use_existent|' -i create_branch/create_branch.yaml
    fi
    git diff

    # prepare venv for python
    if [ ! -d "${WORKSPACE:-.}/venv_release_scripts" ]; then
        virtualenv ${WORKSPACE:-.}/venv_release_scripts
    fi
    source ${WORKSPACE:-.}/venv_release_scripts/bin/activate
    pip install -r create_branch/requirements.txt

popd

echo "=========================================PROCESS========================================="
release_scripts/create_branch/create_branch.py

echo "=========================================FINALIZING========================================="
if [ -n "${MARK_BUILD_BY_TAG}" ];then
    pushd release_scripts
        git tag -a -m "Tagged by ${BUILD_URL}" ${MARK_BUILD_BY_TAG}-mark
        if [ "${DRY_RUN}" != 'true' ]; then
            git push ${REMOTE} ${MARK_BUILD_BY_TAG}-mark
        fi
    popd
else
    MARK_BUILD_BY_TAG="${CR_REF}"
fi
if [ "${DRY_RUN}" = 'true' ]; then
    DRY_RUN_MSG='DRY-RUN:'
fi
echo Description string: ${DRY_RUN_MSG}${MARK_BUILD_BY_TAG}
