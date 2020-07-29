IMAGES_DIR=/local/iso
VIRT_DIR=/local/virt
OFFICIAL_IMAGE=rhel-8.1-x86_64-kvm.qcow2
PASSWORD_FOR_VMS='r3dh4t1!'
VIRT_DOMAIN='hero.zokahn.com'

virsh destroy test-node  > /dev/null 2>&1
virsh undefine test-node > /dev/null 2>&1
rm -f ${VIRT_DIR}/test-node.qcow2 > /dev/null 2>&1


cd $VIRT_DIR
qemu-img create -f qcow2 test-node.qcow2 20G
virt-resize --expand /dev/sda1 /$IMAGES_DIR/$OFFICIAL_IMAGE test-node.qcow2

cat > /tmp/ifcfg-eth0 << EOF
DEVICE=eth0
BOOTPROTO=dhcp
ONBOOT=yes
MTU=9000
EOF

cat > /tmp/ifcfg-eth1 << EOF
DEVICE=eth1
BOOTPROTO=static
IPADDR=172.20.0.10
PREFIX=24
ONBOOT=yes
MTU=9000
EOF


virt-customize -a test-node.qcow2 \
  --hostname test-node.zokahn.local \
  --root-password password:r3dh4t1! \
  --uninstall cloud-init \
  --copy-in /tmp/ifcfg-eth0:/etc/sysconfig/network-scripts/ \
  --copy-in /tmp/ifcfg-eth1:/etc/sysconfig/network-scripts/ \
  --timezone Europe/Amsterdam \
  --selinux-relabel

virt-install --ram 4096 --vcpus 2 --os-variant rhel8.0\
  --disk path=$VIRT_DIR/test-node.qcow2,device=disk,bus=virtio,format=qcow2 \
  --import --noautoconsole --vnc \
  --network bridge=br0_1,model=virtio --name test-node \
  --network bridge=br1_100,model=virtio \
  --cpu host,+vmx \
  --dry-run --print-xml > /tmp/test-node.xml

virsh define --file /tmp/test-node.xml
virsh start test-node
