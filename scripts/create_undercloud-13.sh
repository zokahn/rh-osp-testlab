#!/bin/bash

#
# undercloud creation script
# Optimized for OSP13. This means a vm based on RHEL7, 16Gb of mem
#

VIRT_HOSTNAME=director
IMAGES_DIR=/var/lib/libvirt/images
VIRT_DIR=/var/lib/libvirt/images
OFFICIAL_IMAGE=rhel-server-7.8-x86_64-kvm.qcow2
PASSWORD_FOR_VMS='r3dh4t1!'
VIRT_DOMAIN='simpletest.nl'

virsh destroy $VIRT_HOSTNAME  > /dev/null 2>&1
virsh undefine $VIRT_HOSTNAME > /dev/null 2>&1
rm -f ${VIRT_DIR}/$VIRT_HOSTNAME.qcow2 > /dev/null 2>&1


cd $VIRT_DIR
#create root disk
qemu-img create -f qcow2 $VIRT_HOSTNAME.qcow2 100G
virt-resize --expand /dev/sda3 /$IMAGES_DIR/$OFFICIAL_IMAGE $VIRT_HOSTNAME.qcow2


cat > /tmp/ifcfg-eth0 << EOF
DEVICE=eth0
BOOTPROTO=dhcp
ONBOOT=yes
MTU=1500
EOF

cat > /tmp/ifcfg-eth1 << EOF
#libvirt network deployment is defined in the scripts.
#since all the vm's for this openstack are on a sinlge hv,
#this will work on a internal network to libvirt
#In the example undercloud.conf this is 10.100.0.0/24
DEVICE=eth1
BOOTPROTO=none
ONBOOT=yes
MTU=1500
EOF


virt-customize -a $VIRT_HOSTNAME.qcow2 \
  --hostname $VIRT_HOSTNAME.zokahn.local \
  --root-password password:r3dh4t1! \
  --uninstall cloud-init \
  --copy-in /tmp/ifcfg-eth0:/etc/sysconfig/network-scripts/ \
  --copy-in /tmp/ifcfg-eth1:/etc/sysconfig/network-scripts/ \
  --timezone Europe/Amsterdam \
  --selinux-relabel

virt-install --ram 16384 --vcpus 4 --os-variant rhel7 --accelerate \
  --disk path=$VIRT_DIR/$VIRT_HOSTNAME.qcow2,device=disk,bus=virtio,format=qcow2 \
  --import --graphics none  --console pty,target_type=serial --graphics=vnc \
  --network bridge=br0_phys,model=virtio,mac=52:54:00:b4:a0:20 --name $VIRT_HOSTNAME \
  --network network=deployment,model=virtio \
  --cpu host,+vmx \
  --dry-run --print-xml > /tmp/$VIRT_HOSTNAME.xml

virsh define --file /tmp/$VIRT_HOSTNAME.xml
virsh start $VIRT_HOSTNAME
