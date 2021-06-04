#!/bin/bash
VIRT_DIR=/var/lib/libvirt/images

VIRT_DOMAIN='simpletest.nl'


nodes="controller1 controller2 controller3"
NUM=1
for node in $nodes; do
    echo "Kicking $node into gear"
    virsh destroy $node
    virsh undefine $node
    virt-install --name=$node --ram=24576 --vcpus=2 \
                --disk path=$VIRT_DIR/$node.dsk,size=100,bus=virtio \
                --pxe --noautoconsole --graphics=vnc --hvm \
                --network network=deployment,model=virtio,mac=52:54:00:"$NUM"5:bd:2f \
                --network network=openstack-api,model=virtio \
                --os-variant=rhel7.0
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
                --network network=deployment,model=virtio,mac=52:54:00:"$NUM"5:bd:2f \
                --network network=openstack-api,model=virtio \
                --os-variant=rhel7.0
    NUM=$((NUM+1))
done
