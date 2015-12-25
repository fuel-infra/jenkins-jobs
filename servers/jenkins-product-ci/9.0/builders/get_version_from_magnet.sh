#!/bin/bash

ISO_VERSION=$(echo "${MAGNET_LINK##*dn=}" | cut -d \% -f 1)

echo "Description string: $ISO_VERSION"
