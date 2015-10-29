#!/bin/bash

[ -f ".defaults" ] && source .defaults

set -ex

WORKSPACE="${WORKSPACE:-.}"

echo "PACKAGENAME=$GERRIT_PROJECT"

rm -f "${WORKSPACE}"/*.pipeline.params
specs_path="specs/"

tmpdir=$(mktemp -d)
git init "$tmpdir"
git -C "$tmpdir" fetch --tags "ssh://${GERRIT_USER}@${GERRIT_HOST}:${GERRIT_PORT}/$GERRIT_PROJECT" "$GERRIT_REFSPEC"
git -C "$tmpdir" checkout -f FETCH_HEAD

changed_files=$(git -C "$tmpdir" show --name-only --pretty=" %h" | egrep -v "^( |$)")
exist_targets=$(find "${tmpdir}/$specs_path" -maxdepth 1 -mindepth 1 -type d | awk -F'/' '{print $NF}' | fgrep -v "tests" || :)
changed_targets=$(echo "$changed_files" | grep "^$specs_path" | sed "s|^$specs_path||g" | awk -F'/' '{print $1}' | sort -u  | fgrep -v "tests" || :)
changed_source_files=$(echo "$changed_files" | grep -vc "^$specs_path" || :)
rm -rf "$tmpdir"

case ${GERRIT_PROJECT%/*} in
    "fuel-infra/backports" )
        REPO_ROLE=backports
        # Build changed targets only
        targets=$changed_targets
        ;;
    "fuel-infra/packages" )
        REPO_ROLE=packages
        # Build all existing targets in case of code chande
        # Otherwise build changed targets only
        targets=$exist_targets
        [ "$changed_source_files" -eq 0 ] && targets=$changed_targets
        ;;
esac
_code_project_prefix_name=${REPO_ROLE}_code_project_prefix

for target in $targets ; do
    # Do not process removed targets
    [ "${exist_targets/$target}" == "$exist_targets" ] && continue
    _dist_type_name=${target}_dist_type
    DIST_TYPE=${!_dist_type_name}
    _build_vote_user_name=${target}_build_vote_user
    _test_vote_user_name=${target}_test_vote_user

    cat > "${WORKSPACE}/${target}.pipeline.params" <<-EOF
		BUILD_VOTE_USER=${!_build_vote_user_name}
		TEST_VOTE_USER=${!_test_vote_user_name}
		SRC_PROJECT_PATH=${!_code_project_prefix_name}
		REMOTE_REPO_HOST=$REMOTE_REPO_HOST
		REPO_REQUEST_PATH_PREFIX=$REPO_REQUEST_PATH_PREFIX
		DIST=$target
		DIST_TYPE=$DIST_TYPE
		EOF
    case "$DIST_TYPE" in
        "rpm")
            _os_repo_path_name=${target}_${REPO_ROLE}_os_repo_path
            _proposed_repo_path_name=${target}_${REPO_ROLE}_proposed_repo_path
            _updates_repo_path_name=${target}_${REPO_ROLE}_updates_repo_path
            _security_repo_path_name=${target}_${REPO_ROLE}_security_repo_path
            _holdback_repo_path_name=${target}_${REPO_ROLE}_holdback_repo_path
            cat >> "${WORKSPACE}/${target}.pipeline.params" <<-EOF
				RPM_OS_REPO_PATH=${!_os_repo_path_name}
				RPM_PROPOSED_REPO_PATH=${!_proposed_repo_path_name}
				RPM_UPDATES_REPO_PATH=${!_updates_repo_path_name}
				RPM_SECURITY_REPO_PATH=${!_security_repo_path_name}
				RPM_HOLDBACK_REPO_PATH=${!_holdback_repo_path_name}
				EOF
            # Add backports as extra repository for packages/ role
            if [ "$REPO_ROLE" == "packages" ] ; then
                cat >> "${WORKSPACE}/${target}.pipeline.params" <<-EOF
					EXTRAREPO="backports,http://${REMOTE_REPO_HOST}/infra/backports/${target}/os/x86_64"
				EOF
            fi
            ;;
        "deb")
            _deb_repo_path_name=${target}_${REPO_ROLE}_repo_path
            _deb_dist_name_name=${target}_${REPO_ROLE}_dist_name
            _deb_proposed_dist_name_name=${target}_${REPO_ROLE}_proposed_dist_name
            _deb_updates_dist_name_name=${target}_${REPO_ROLE}_updates_dist_name
            _deb_security_dist_name_name=${target}_${REPO_ROLE}_security_dist_name
            _deb_holdback_dist_name_name=${target}_${REPO_ROLE}_holdback_dist_name
            cat >> "${WORKSPACE}/${target}.pipeline.params" <<-EOF
				ORIGIN=${ORIGIN}
				DEB_REPO_PATH=${!_deb_repo_path_name}
				DEB_DIST_NAME=${!_deb_dist_name_name}
				DEB_PROPOSED_DIST_NAME=${!_deb_proposed_dist_name_name}
				DEB_UPDATES_DIST_NAME=${!_deb_updates_dist_name_name}
				DEB_SECURITY_DIST_NAME=${!_deb_security_dist_name_name}
				DEB_HOLDBACK_DIST_NAME=${!_deb_holdback_dist_name_name}
				EOF
            # Add backports as extra repository for packages/ role
            if [ "$REPO_ROLE" == "packages" ] ; then
                cat >> "${WORKSPACE}/${target}.pipeline.params" <<-EOF
					EXTRAREPO="http://${REMOTE_REPO_HOST}/infra/backports/${target} $target main restricted"
				EOF
            fi
            ;;
    esac
done
