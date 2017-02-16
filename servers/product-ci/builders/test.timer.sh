#!/bin/bash

set -ex

ISO_BUILD_URL=$(awk -F '[ =]' '{print $2}' iso_build_url.txt)
ISO_VERSION=${ISO_BUILD_URL%/*}
ISO_VERSION=${ISO_VERSION##*/}

echo "Description string: ISO <a href=\"$ISO_BUILD_URL\">#${ISO_VERSION}</a>"
