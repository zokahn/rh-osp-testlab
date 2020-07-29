#!/bin/bash


nodes="controller1 controller2 controller3"
for node in $nodes; do
    echo "Kicking $node into gear"
    virsh destroy $node
    virsh undefine $node
    screen -d -m -S $node bash -c "virt-install --name=$node --ram=6144 --vcpus=2 \
                --disk path=/local/virt-machines/$node.dsk,size=100,bus=virtio \
                --pxe --noautoconsole --graphics=vnc --hvm \
                --network network=deployment,model=virtio \
                --network network=openstack-api,model=virtio \
                --network network=tenant,model=virtio \
                --network network=external,model=virtio \
                --os-variant=rhel7"
done

nodes="compute1 compute2"
for node in $nodes; do
    echo "Kicking $node into gear"
    virsh destroy $node
    virsh undefine $node
    screen -d -m -S $node bash -c "virt-install --name=$node --ram=2048 --vcpus=2 \
                --disk path=/local/virt-machines/$node.dsk,size=100,bus=virtio \
                --pxe --noautoconsole --graphics=vnc --hvm \
                --network network=deployment,model=virtio \
                --network network=openstack-api,model=virtio \
                --network network=tenant,model=virtio \
                --network network=external,model=virtio \
                --os-variant=rhel7"
done
