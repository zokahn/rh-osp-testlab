#!/bin/bash
virsh destroy director
virsh undefine director

virt-install --name director --ram 8192 \
--disk path=/local/virt-machines/director.dsk,size=50 \
--vcpus 4 --os-type linux --os-variant rhel7 \
--network network=default \
--network network=deployment \
--network network=external \
--graphics none  --console pty,target_type=serial \
--location '/local/iso/rhel-server-7.6-x86_64-dvd.iso' \
--initrd-inject '/local/kickstarts/director.ks' --extra-args 'console=ttyS0,115200n8 serial' \
--extra-args 'ks=file:/director.ks' --accelerate
