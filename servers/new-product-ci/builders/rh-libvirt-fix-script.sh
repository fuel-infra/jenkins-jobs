# Workaround to properly remove the environment
sudo chown -R root:root /var/lib/libvirt/images
for i in $(LANG=C virsh vol-list --pool default | grep -v -e "Name.*Path" -e "-----" | awk '{print $1}'); do
    virsh vol-info "$i" --pool default > /dev/null
done
sudo systemctl restart libvirtd
