# Red Hat OpenStack Testlab
Deploy with director in a front to back howto, or at least a 'how i did it'. This document describes the deployment of a fully virtualized Red Hat OpenStack Platform. The director, controller(s) and compute(s) all run as virtual machines on a single host. This host needs to be bare-metal, it only needs one nic and one external IP.
This can be a rented host at Hetzner. It needs at least 64GB of ram, more is better.

The virt-host does not need to be RHEL. With Hetzner it makes sense to run the robot driven installation of CentOS.

Please mind the following additional chapters to this Readme
- [Tips and tools](tips-and-tools.md)
  - protect your ssh
  - tmux for when you may leave before done
  -
-


## Prerequisites

### Virtualbmc
In this case the virt-host is deployed in Hetzner as CentOS. There is a VBMC package that connects a IPMI interface to the Libvirt/KVM controlplane. The VBMC package can be found in the upstream Red Hat OpenStack repo; RDO.

```
yum install -y https://www.rdoproject.org/repos/rdo-release.rpm
yum install -y python2-virtualbmc ipmitool
systemctl start virtualbmc.service
systemctl enable virtualbmc.service
systemctl status virtualbmc.service -l
```

Adding packages used later on.
```
yum -y install screen vim
```

## Installing the libvirt/KVM packages
```
yum install -y qemu-kvm libvirt libvirt-python libguestfs-tools virt-install
systemctl enable libvirtd
systemctl start libvirtd
```

## Deploying skeleton virtual infrastructure
Starting point for this stage is an empty kvm/libvirt machine. If you already have some networks and vm's loaded on this machine you should consider reviewing the memory requirements, linux bridge numbers in the scripts (virbr). The scripts also remove virtual machines with the used names (controler1-3, compute1,2) before adding to have a rinse and repeat effect.

### Create overcloud, underlay network
Next to the libvirt nat network used as default we also use the following virtual networks for openstack
 - deployment
 - external
 - openstack-API
 - tenant

These networks need exist before we can create the virtual machines. These networks are used in most OpenStack setups as a bare minimum. There is a script here to just add the networks to this config, you only need to run this once ever. It will only create the layer 2, IP's are assigned where needed by director.

!Example do not run! -> this is what the scripts do:
```
virsh net-define osp-networks/external.xml
virsh net-autostart external
virsh net-start external
```
Where this is the contents of the external.xml
```
<network>
  <name>external</name>
  <bridge name="virbr6"/>
</network>
```

Run this on the virt host
```
cd scripts
./create_openstack_networks.sh
```


### Create Virtual Machines
Virtual machines as skeleton systems, no need to deploy a OS. The machines will receive their OS via PXE boot in director. They do need to hook up with the correct networks, in a coherent order across the landscape.
### Attaching IPMI translation between Libvirt/KVM and VBMC
```
vbmc add compute1 --address 192.168.122.1 --port 6230 --username admin --password password
vbmc add controller1 --address 192.168.122.1 --port 6231 --username admin --password password
vbmc start compute1
vbmc start controller1

ipmitool -I lanplus -U admin -P password -H 192.168.122.1 -p 6230 power start
ipmitool -I lanplus -U admin -P password -H 192.168.122.1 -p 6230 power on
```
This has been automated


## Undercloud

### Subscription manager, repos and users
```
subscription-manager register
subscription-manager attach --pool=8a85f98c60c2c2b40160c32447481b48

useradd stack
passwd stack #add a password for yourself

echo "stack ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/stack
chmod 0440 /etc/sudoers.d/stack
```

### Creating a ntp server (need to check this)
It is important, like every distributed system is to have synchronized time. You need to have a solid, reachable source for time accross the landscape. The controllers, Computes, Ceph all need to operate at the same time. In this test setup there is a lack of a authoritative time server, so lets create it now.

```
sudo yum install ntp
restrict 192.168.1.0 netmask 255.255.255.0 nomodify notrap




sudo systemctl enable ntpd
sudo systemctl start ntpd
```


### as user stack
```
mkdir ~/images
mkdir ~/templates

sudo subscription-manager repos --disable=*
sudo subscription-manager repos --enable=rhel-7-server-rpms --enable=rhel-7-server-extras-rpms --enable=rhel-7-server-rh-common-rpms --enable=rhel-ha-
for-rhel-7-server-rpms --enable=rhel-7-server-openstack-13-rpms

sudo yum install -y python-tripleoclient
```
Also enable the Ceph repo and install Ceph Ansible
```
sudo subscription-manager repos --enable=rhel-7-server-rhceph-3-tools-rpms
sudo yum install -y ceph-ansible
```

Copy the sample file or the last one used in notes/undercloud.conf
```
cp \
  /usr/share/instack-undercloud/undercloud.conf.sample \
  ~/undercloud.conf
```

### Populating the local registry with container images
As the stack user on the undercloud node
```
openstack overcloud container image prepare   --namespace=registry.access.redhat.com/rhosp13   --push-destination=10.100.0.1:8787   --prefix=openstack-   --tag-from-label {version}-{release}   --output-env-file=/home/stack/templates/overcloud_images.yaml   --output-images-file /home/stack/local_registry_images.yaml

source ~/stackrc
openstack overcloud container image upload   --config-file  /home/stack/local_registry_images.yaml   --verbose
```
check images in the registry
```
curl -s -H "Accept: application/json" http://10.100.0.1:8787/v2/_catalog | python -m json.tool
```

Overcloud images
```
sudo yum -y install rhosp-director-images
tar -C images -xvf /usr/share/rhosp-director-images/overcloud-full.tar
tar -C images -xvf /usr/share/rhosp-director-images/ironic-python-agent.tar

source ~/stackrc
openstack overcloud image upload --image-path ~/images
```

### Adding the overcloud nodes

```
openstack overcloud node import instackenv.json

for node in `openstack baremetal node list -f value | grep manageable | cut -d' ' -f1`; do openstack overcloud node introspect $node --provide > /tmp/$node.log & sleep 5; done
```

Checking introspection data and tthat all nodes were correctly processed
```
openstack baremetal introspection list
openstack baremetal node show controller1 -f json -c driver_info
```

abort running introspection
```
openstack baremetal introspection abort overcloud-controller1
```

## Overcloud configuration

### Display and use introspection data of overcloud nodes
In this multi-node deployment scenario it is important to assign boot disks for systems that have more then one drive. In our case the Ceph nodes have a bunch of disks. We need to assign /dev/vda as the root disk.

See what disks are recognized during introspection
```
openstack baremetal introspection data save <UUID or Name> | jq ".inventory.disks"
```

Setting the root disk can be done in different ways:
- set a policy to assign the root disk from a prioritized list
- assign root devices per individual Machine

Pass the --root-device argument to the openstack overcloud node configure after a successful introspection. This argument can accept a device list in the order of preference, for example:
```
openstack overcloud node configure --all-manageable --root-device=vda,sda

```
It can also accept one of two strategies: smallest will pick the smallest device, largest will pick the largest one. By default only disk devices larger than 4 GiB are considered at all, set the --root-device-minimum-size argument to change.

Remove the setting first if this did not yield the correct result and you want to overwrite the setting.
```
openstack baremetal node unset <UUID or Name > --property root_device
```
Note: on testing this did not work, need to check.

It is possible that, for whatever reason, the disk naming is unique per reboot. Disks then need to be assigned based on other data, like their WWN or by_path value:
```
openstack baremetal node set <UUID or Name> --property root_device='{"wwn": "0x4000cca77fc4dba1"}'
```
or by name
```
openstack baremetal node set ceph1 --property root_device='{"name": "/dev/vda"}'
```

Check the results by showing the node data
```
openstack baremetal node show ceph1 -f json -c properties
{
  "properties": {
    "cpu_arch": "x86_64",
    "root_device": {
      "name": "/dev/vda"
    },
    "cpus": "2",
    "capabilities": "profile:ceph-storage,cpu_aes:true,boot_mode:bios,cpu_hugepages:true,boot_option:local",
    "memory_mb": "4096",
    "local_gb": "9"
  }

```

In our specific deployment we only have three ceph nodes with more then one disk:
```
openstack baremetal node set ceph1 --property root_device='{"name": "/dev/vda"}'
openstack baremetal node set ceph2 --property root_device='{"name": "/dev/vda"}'
openstack baremetal node set ceph3 --property root_device='{"name": "/dev/vda"}'
```
### Templates! Preparing then
This sequence is to be applied as the stack user, on the director node.

```
cat << EOF > /home/stack/templates/node-info.yaml
parameter_defaults:
  OvercloudControllerFlavor: control
  OvercloudComputeFlavor: compute
  OvercloudCephStorageFlavor: ceph-storage
  ControllerCount: 3
  ComputeCount: 2
  CephStorageCount: 3
EOF
```



### Running the deployment process

```
#!/bin/bash
source ~/stackrc
exec openstack overcloud deploy \
        --templates /usr/share/openstack-tripleo-heat-templates \
        --timeout 90  \
        --verbose \
        -n /home/stack/templates/network_data.yaml \
        -r /home/stack/templates/roles_data.yaml \
        -e /home/stack/templates/global-config.yaml \
        -e /usr/share/openstack-tripleo-heat-templates/environments/network-environment.yaml \
        -e /home/stack/templates/network-environment.yaml \
        -e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml \
        -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml \
        -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-rgw.yaml \
        -e /home/stack/templates/environments/50-ceph-config-datalookup.yaml \
        -e /home/stack/templates/environments/40-neutron-ovn-dvr-ha.yaml \
        -e /home/stack/templates/docker-registry.yaml \
        -e /home/stack/templates/first-boot-env.yaml \
        --log-file /home/stack/overcloud-deploy.log
```

notes:
http://tripleo.org/install/environments/virtualbmc.html
https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/13/html-single/director_installation_and_usage/index
https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/13/html/director_installation_and_usage/chap-troubleshooting_director_issues
https://docs.openstack.org/project-deploy-guide/tripleo-docs/latest/provisioning/root_device.html