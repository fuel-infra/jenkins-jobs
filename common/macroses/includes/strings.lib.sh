#!/bin/bash
function clean_url () {
    # shellcheck disable=SC2001
    # this is complicated case which hard to solve by ${1//..}
    echo "$1" | sed 's|"||g; s|/\+|/|g; s|:|:/|g; s|/ | |g'
}