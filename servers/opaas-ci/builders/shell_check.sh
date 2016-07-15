#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WORKSPACE="${WORKSPACE:-${DIR}}"

cat << EOF
********************************************************************************
*
*   Starting shellcheck
*
********************************************************************************
EOF

find "${WORKSPACE}" -name '*.sh' -print0 | while read -d '' -r script; do
    shellcheck "${script}" -e SC2034,SC2046
done


cat << EOF
********************************************************************************
*
*   shellcheck finished
*
********************************************************************************
EOF
