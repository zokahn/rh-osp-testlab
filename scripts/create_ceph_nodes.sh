#!/bin/bash
VIRT_DIR=/local/virt

VIRT_DOMAIN='zokahn.local'


nodes="ceph1 ceph2 ceph3"
NUM=6
for node in $nodes; do
    echo "Kicking $node into gear"
    virsh destroy $node
    virsh undefine $node
    virt-install --name=$node --ram=6144 --vcpus=2 \
                --disk path=$VIRT_DIR/$node.dsk,size=100,bus=virtio \
                --disk path=$VIRT_DIR/$node-data.dsk,size=10,bus=virtio \
                --pxe --noautoconsole --graphics=vnc --hvm \
                --network bridge=br1_100,model=virtio,mac=52:54:00:"$NUM"5:bd:2f \
                --network bridge=br1_100,model=virtio \
                --os-variant=rhel8.0
    NUM=$((NUM+1))
done
