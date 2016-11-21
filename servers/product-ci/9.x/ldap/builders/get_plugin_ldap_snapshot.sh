#!/bin/bash -ex

# get path to plugin snapshot
if [[ -z "${LDAP_PLUGIN_SNAPSHOT_PATH}" ]]; then
    LDAP_PLUGIN_SNAPSHOT_PATH=$(curl -s \
    "${PLUGINS_URL}/ldap/${PLUGIN_BRANCH}.target.txt" \
    | head -1)
fi

cat >> snapshots.params <<PLUGIN_SNAPSHOTS_PARAMS
LDAP_PLUGIN_URL=${PLUGINS_URL}/${LDAP_PLUGIN_SNAPSHOT_PATH:3}/
PLUGIN_SNAPSHOTS_PARAMS
