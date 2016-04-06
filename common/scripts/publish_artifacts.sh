#!/bin/bash

set -ex

process_artifacts() {
    local ARTIFACT="$1"
    test -f "${ARTIFACT}" || return 1

    local HOSTNAME=$(hostname -f)
    local LOCAL_STORAGE="$2"
    local TRACKER_URL="$3"
    local HTTP_ROOT="${4//@HOSTNAME@/${HOSTNAME}}"

    echo "MD5SUM is:"
    md5sum "${ARTIFACT}"

    echo "SHA1SUM is:"
    sha1sum "${ARTIFACT}"

    # seedclient.py comes from python-seed devops package
    case ${ISO_TYPE} in
        product|product-mos|custom)
            mkdir -p "${LOCAL_STORAGE}"
            mv "${ARTIFACT}" "${LOCAL_STORAGE}"
            local MAGNET_LINK=$(seedclient.py -v -u \
                                  -f "${LOCAL_STORAGE}/${ARTIFACT}"\
                                  --tracker-url="${TRACKER_URL}"\
                                  --http-root="${HTTP_ROOT}" || true)
            local STORAGES=($(echo "${HTTP_ROOT}" | tr ',' '\n'))
            local HTTP_LINK="${STORAGES[0]}/${ARTIFACT}"
            local HTTP_TORRENT="${HTTP_LINK}.torrent"
            ;;
        community)
            seedclient.py -v -p \
                -f "${ARTIFACT}"\
                --tracker-url="${TRACKER_URL}"\
                --http-root="${HTTP_ROOT}"\
                --seed-host="${SEED_HOST}" || true
            local HTTP_TORRENT="${FRONT_URL}/${ARTIFACT}.torrent"
            local MAGNET_LINK="${HTTP_TORRENT}"
            ;;
    esac

    cat > "${ARTIFACT}.data.txt" <<EOF
ARTIFACT=${ARTIFACT}
HTTP_LINK=${HTTP_LINK}
HTTP_TORRENT=${HTTP_TORRENT}
MAGNET_LINK=${MAGNET_LINK}
EOF

}

export ARTS_DIR="${ARTS_DIR:-${WORKSPACE}/artifacts}"
export LOCAL_STORAGE='/var/www/fuelweb-iso'

cd "${ARTS_DIR}"
for artifact in fuel-*
do
  begin=$(date +%s)
  process_artifacts "${artifact}" "${LOCAL_STORAGE}" \
                    "${TRACKER_URL}" "${HTTP_ROOT}"
  echo "Time taken: $(($(date +%s) - begin))"
done

grep MAGNET_LINK "${ARTS_DIR}"/*iso.data.txt > "${ARTS_DIR}/magnet_link.txt"

# Generate build description
ISO_MAGNET_LINK=$(grep MAGNET_LINK "${ARTS_DIR}"/*iso.data.txt |
                    sed 's/MAGNET_LINK=//')
ISO_HTTP_LINK=$(grep HTTP_LINK "${ARTS_DIR}"/*iso.data.txt |
                  sed 's/HTTP_LINK=//')
ISO_HTTP_TORRENT=$(grep HTTP_TORRENT "${ARTS_DIR}"/*iso.data.txt |
                    sed 's/HTTP_TORRENT=//')

echo "<a href=${ISO_HTTP_LINK}>ISO download link</a>"\
     "<a href=${ISO_HTTP_TORRENT}>ISO torrent link</a>"\
     "<br>${ISO_MAGNET_LINK}<br>"

