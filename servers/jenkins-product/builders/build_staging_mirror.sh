export mirror=$(awk -F '[:=?]' /^PRODUCT_VERSION\>/ '{print $NF}' config.mk)
osci-mirrors/fuel_master_mirror_vc.shß