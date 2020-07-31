#!/bin/bash
VIRT_DIR=/local/virt

VIRT_DOMAIN='zokahn.local'


nodes="controller1 controller2 controller3"
for node in $nodes; do
    echo "Kicking $node into gear"
    virsh destroy $node
    virsh undefine $node
    virt-install --name=$node --ram=6144 --vcpus=2 \
                --disk path=$VIRT_DIR/$node.dsk,size=100,bus=virtio \
                --pxe --noautoconsole --graphics=vnc --hvm \
                --network bridge=br1_100,model=virtio #provisioning \
                --network bridge=br2_110,model=virtio #trunk4vlans \
                --network bridge=br0_1,model=virtio #external \
                --os-variant=rhel8.0
done

nodes="compute1 compute2"
for node in $nodes; do
    echo "Kicking $node into gear"
    virsh destroy $node
    virsh undefine $node
    virt-install --name=$node --ram=2048 --vcpus=2 \
                --disk path=$VIRT_DIR/$node.dsk,size=100,bus=virtio \
                --pxe --noautoconsole --graphics=vnc --hvm \
                --network bridge=br1_100,model=virtio #provisioning \
                --network bridge=br2_110,model=virtio #trunk4vlans \
                --os-variant=rhel8.0
done
