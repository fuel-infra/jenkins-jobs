export mirror=$(awk -F '[:=?]' '/^PRODUCT_VERSION\>/ {print $NF}' config.mk)
export mirror=5.0.3
export MIRROR_DOCKER=http://osci-mirror-srt.srt.mirantis.net/fwm/5.0.2/docker
osci-mirrors/fuel_master_mirror_vc.sh
