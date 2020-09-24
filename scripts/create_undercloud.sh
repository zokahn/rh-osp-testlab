#!/bin/bash
VIRT_HOSTNAME=director
IMAGES_DIR=/mnt/utility/iso
VIRT_DIR=/local/virt
OFFICIAL_IMAGE=rhel-8.2-x86_64-kvm.qcow2
PASSWORD_FOR_VMS='r3dh4t1!'
VIRT_DOMAIN='zokahn.local'

virsh destroy $VIRT_HOSTNAME  > /dev/null 2>&1
virsh undefine $VIRT_HOSTNAME > /dev/null 2>&1
rm -f ${VIRT_DIR}/$VIRT_HOSTNAME.qcow2 > /dev/null 2>&1


cd $VIRT_DIR
#create root disk
qemu-img create -f qcow2 $VIRT_HOSTNAME.qcow2 50G
virt-resize --expand /dev/sda1 /$IMAGES_DIR/$OFFICIAL_IMAGE $VIRT_HOSTNAME.qcow2


cat > /tmp/ifcfg-eth0 << EOF
DEVICE=eth0
BOOTPROTO=dhcp
ONBOOT=yes
MTU=1500
EOF

cat > /tmp/ifcfg-eth1 << EOF
DEVICE=eth1
BOOTPROTO=static
IPADDR=172.20.0.100
PREFIX=24
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

virt-install --ram 8192 --vcpus 2 --os-variant rhel8.0 --accelerate \
  --disk path=$VIRT_DIR/$VIRT_HOSTNAME.qcow2,device=disk,bus=virtio,format=qcow2 \
  --import --graphics none  --console pty,target_type=serial --graphics=vnc \
  --network bridge=br0_1,model=virtio --name $VIRT_HOSTNAME \
  --network bridge=br1_100,model=virtio \
  --cpu host,+vmx \
  --dry-run --print-xml > /tmp/$VIRT_HOSTNAME.xml

virsh define --file /tmp/$VIRT_HOSTNAME.xml
virsh start $VIRT_HOSTNAME
