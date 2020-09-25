NODE_NAME=test-node
IMAGES_DIR=/local/iso
VIRT_DIR=/local/virt
OFFICIAL_IMAGE=rhel-8.2-x86_64-kvm.qcow2
PASSWORD_FOR_VMS='r3dh4t1!'
VIRT_DOMAIN='zokahn.local'

virsh destroy $NODE_NAME  > /dev/null 2>&1
virsh undefine $NODE_NAME > /dev/null 2>&1
rm -f ${VIRT_DIR}/$NODE_NAME.qcow2 > /dev/null 2>&1


cd $VIRT_DIR
qemu-img create -f qcow2 $NODE_NAME.qcow2 20G
virt-resize --expand /dev/sda1 /$IMAGES_DIR/$OFFICIAL_IMAGE $NODE_NAME.qcow2

cat > /tmp/ifcfg-eth0 << EOF
DEVICE=eth0
BOOTPROTO=dhcp
ONBOOT=yes
MTU=9000
EOF

cat > /tmp/ifcfg-eth1 << EOF
DEVICE=eth1
BOOTPROTO=static
IPADDR=172.20.0.11
PREFIX=24
ONBOOT=yes
MTU=9000
EOF

cat > /tmp/ifcfg-eth2 << EOF
DEVICE=eth2
BOOTPROTO=none
ONBOOT=yes
MTU=9000
#trunk for osp vlan
EOF

virt-customize -a $NODE_NAME.qcow2 \
  --hostname $NODE_NAME.$VIRT_DOMAIN \
  --root-password password:r3dh4t1! \
  --uninstall cloud-init \
  --copy-in /tmp/ifcfg-eth0:/etc/sysconfig/network-scripts/ \
  --copy-in /tmp/ifcfg-eth1:/etc/sysconfig/network-scripts/ \
  --copy-in /tmp/ifcfg-eth2:/etc/sysconfig/network-scripts/ \
  --timezone Europe/Amsterdam \
  --selinux-relabel

virt-install --ram 4096 --vcpus 2 --os-variant rhel8.0\
  --disk path=$VIRT_DIR/test-node.qcow2,device=disk,bus=virtio,format=qcow2 \
  --import --noautoconsole --vnc \
  --network bridge=br0_1,model=virtio --name $NODE_NAME \
  --network bridge=br1_100,model=virtio \
  --network bridge=br2_110,model=virtio \
  --cpu host,+vmx \
  --dry-run --print-xml > /tmp/$NODE_NAME.xml

virsh define --file /tmp/$NODE_NAME.xml
virsh start $NODE_NAME
