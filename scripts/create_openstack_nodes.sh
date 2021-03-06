#!/bin/bash
VIRT_DIR=/local/virt

VIRT_DOMAIN='zokahn.local'


nodes="controller1 controller2 controller3"
NUM=1
for node in $nodes; do
    echo "Kicking $node into gear"
    virsh destroy $node
    virsh undefine $node
    virt-install --name=$node --ram=24576 --vcpus=2 \
                --disk path=$VIRT_DIR/$node.dsk,size=100,bus=virtio \
                --pxe --noautoconsole --graphics=vnc --hvm \
                --network bridge=br1_100,model=virtio,mac=52:54:00:"$NUM"5:bd:2f \
                --network bridge=br1_100,model=virtio \
                --os-variant=rhel8.0
    NUM=$((NUM+1))
done

nodes="compute1 compute2"
NUM=4
for node in $nodes; do
    echo "Kicking $node into gear"
    virsh destroy $node
    virsh undefine $node
    virt-install --name=$node --ram=4096 --vcpus=2 \
                --disk path=$VIRT_DIR/$node.dsk,size=100,bus=virtio \
                --pxe --noautoconsole --graphics=vnc --hvm \
                --network bridge=br1_100,model=virtio,mac=52:54:00:"$NUM"5:bd:2f \
                --network bridge=br1_100,model=virtio \
                --os-variant=rhel8.0
    NUM=$((NUM+1))
done
