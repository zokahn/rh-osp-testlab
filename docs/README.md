# Red Hat OpenStack Testlab
Deploy with director in a front to back howto, or at least a 'how i did it'. This document describes the deployment of a fully virtualized Red Hat OpenStack Platform. The director, controller(s) and compute(s) all run as virtual machines on a single host. This host needs to be bare-metal, it only needs one nic and one external IP.
This can be a rented host at Hetzner. It needs at least 64GB of ram, more is better.

The virt-host does not need to be RHEL, same is possible with CentOS.

Update jul 2020: Updated to use RHEL8, OpenStack 16.

# Table of Contents
1. [Prerequisites](#prereq)
   - [Virthost](#virthost)
   - [VirtualBMC](#virtualbmc)
   - [Installing the libvirt/KVM packages](#virtpack)
2. [Deploying skeleton virtual infrastructure](#skeleton)
   - [Create Virtual Machines](#vms)
   - [Attaching IPMI translation](#hookvms)
3. [Undercloud](#undercloud)
   - [Subscription manager, repos and users](#subsrepos)
   - [Creating the 'stack' undercloud env](#stacking)
   - [Populating the local registry with container images](#containerreg)
   - [Adding the overcloud nodes](#addingnodes)
4. [Overcloud configuration](#overcloudconfig)
   - [Display and use introspection data](#spectiondata)
   - [Templates! Preparing them](#templates)
   - [Running the deployment process](#deployment)

Also see:
- [Tips and tools](tips-and-tools.md)

The current plan for this testlab project
- Have a coherent working director deployed testlab
   - includes multi controller
   - include ceph
   - include different types of provider and tenant networks
- Have it as a basis for OpenStack centric talks
   - Deployment itself
   - promoting having test environments
   - Monitoring of openstack
   - running OpenShift on OpenStack





## Prerequisites <a name="prereq">

### virthost  <a name="virthost">
The virt host is based on RHEL8 or CentOS8. This section describes which packages are installed and what configuration is in place. For clarity the bare, manual configuration is documented, in production environments the focus would be on pushing the configuration via automation.

The virt host will have:
- a capable CPU like Intel i7
- 64G+ memory
- 256GB or SSD where NVME is preferred.
- a single nic

#### single NIC, two VLAN's, two Bridges config
This virt-node will be able to run virtual machines with NIC's in different networks. For that we need to strip the IPv4 config from the original ifcfg file. Then we create the sub-interfaces to connect to the VLAN network, then we create the linux bridges with the local IPv4 addresses.
Virtual machines will then be able to add the vNIC into the bridges. This can be extended to include Ceph Networks, or other specific workload networks.
This configuration is quite specific for a network setup. No need for a 'managed' switch, unless you want to patch specific ports into a VLAN. If you have managed switch make sure you put the port used into 'trunk' mode, moving it from end-node mode.


Name | VLAN | Subnet | Gateway IP | lives on | Description
------------ | ------------- | ------------- | ------------- | ------------- | -------------
External | 1 | 192.168.178.0/24 | 10.0.0.1 | Switch | Overcloud external API and floating IP
Provisioning | 100 | 10.100.0.0/24 | 10.100.0.254 | Switch | Undercloud control plane and PXE boot
osp_trunk | 110 | NA | NA | Switch | VLAN functioning as trunk to carry the VLANs below
InternalApi | 20 | 172.17.0.0/24 | NA | Trunk, VLAN 101 | Overcloud internal API endpoints
Storage | 30 | 172.18.0.0/24 | NA | Trunk, VLAN 101 | Storage access network
StorageMgmt | 40 | 172.19.0.0/24 | NA | Trunk, VLAN 101 | Internal storage cluster network
Tenant | 50 | 172.16.0.0/24 | NA | Trunk, VLAN 101 | Network for tenant tunnels


```
NIC=enp1s0

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-$NIC
TYPE=Ethernet
BOOTPROTO=none
NAME=$NIC
DEVICE=$NIC
ONBOOT=yes
MTU=9000
EOF

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-$NIC.1
DEVICE=$NIC.1
BOOTPROTO=none
ONBOOT=yes
MTU=9000
VLAN=yes
BRIDGE=br0_1
EOF

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-$NIC.100
DEVICE=$NIC.100
BOOTPROTO=none
ONBOOT=yes
MTU=9000
VLAN=yes
BRIDGE=br1_100
EOF

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-$NIC.110
DEVICE=$NIC.110
BOOTPROTO=none
ONBOOT=yes
MTU=9000
VLAN=yes
BRIDGE=br2_110
EOF

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-br0_1
DEVICE=br0_1
TYPE=Bridge
IPADDR=192.168.178.113
NETMASK=255.255.255.0
GATEWAY=192.168.178.1
DNS1=8.8.8.8
ONBOOT=yes
MTU=9000
BOOTPROTO=static
DELAY=0
EOF

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-br1_100
DEVICE=br1_100
TYPE=Bridge
IPADDR=172.20.0.113
NETMASK=255.255.255.0
ONBOOT=yes
MTU=9000
BOOTPROTO=static
DELAY=0
EOF

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-br2_110
DEVICE=br2_110
TYPE=Bridge
ONBOOT=yes
MTU=9000
BOOTPROTO=none
DELAY=0
EOF
```

#### Subscription and attachment
RHEL8 works on a subscription based access to repos and package channels.
```
RHN_USR=<rhn user>
RHN_PASS=<passwd>
subscription-manager register --username=$RHN_USR --password=$RHN_PASS --auto-attach
subscription-manager repos --disable=*
subscription-manager repos --enable=rhel-8-for-x86_64-baseos-rpms   --enable=rhel-8-for-x86_64-appstream-rpms
```

### Installing the libvirt/KVM packages <a name="virtpack">
```
yum install -y qemu-kvm libvirt libguestfs-tools virt-install
systemctl enable libvirtd
systemctl start libvirtd
```

### VirtualBMC <a name="virtualbmc">
There is a VBMC package that connects a IPMI interface to the Libvirt/KVM controlplane. The VBMC package can be found in the upstream Red Hat OpenStack repo; RDO. In this case the virt-host is deployed with RHEL8, however the VirtualBMC program is not in any Red Hat managed repository. This is why we add the RDO repo.

Taken from: https://cloudnull.io/2019/05/vbmc/ (Thank you for posting Kevin )

```
yum install -y python3-virtualenv libvirt-devel gcc
python3 -m virtualenv --system-site-packages --download /opt/vbmc
/opt/vbmc/bin/pip install virtualbmc


cat << EOF > /etc/systemd/system/vbmcd.service
[Install]
WantedBy = multi-user.target

[Service]
BlockIOAccounting = True
CPUAccounting = True
ExecReload = /bin/kill -HUP $MAINPID
ExecStart = /opt/vbmc/bin/vbmcd --foreground
Group = root
MemoryAccounting = True
PrivateDevices = False
PrivateNetwork = False
PrivateTmp = False
PrivateUsers = False
Restart = on-failure
RestartSec = 2
Slice = vbmc.slice
TasksAccounting = True
TimeoutSec = 120
Type = simple
User = root

[Unit]
After = libvirtd.service
After = syslog.target
After = network.target
Description = vbmc service
EOF

systemctl daemon-reload
systemctl enable vbmcd.service
systemctl start vbmcd.service

# Check the service is in fact running
systemctl status vbmcd.service
```




Adding packages used later on.
```
yum -y install screen vim
```
## Deploying skeleton virtual infrastructure <a name="skeleton">
Starting point for this stage is an empty kvm/libvirt machine. If you already have some networks and vm's loaded on this machine you should consider reviewing the memory requirements. The scripts also remove virtual machines with the used names (controler1-3, compute1,2) before adding to have a rinse and repeat effect.


### Create Virtual Machines <a name="vms">
Virtual machines as skeleton systems, no need to deploy a OS. The machines will receive their OS via PXE boot in director. They do need to hook up with the correct networks, in a coherent order across the landscape.

Run the script to create the skeleton systems:
```
./create_openstack_nodes.sh
Kicking controller1 into gear
Domain controller1 destroyed

Domain controller1 has been undefined


Starting install...
Domain installation still in progress. You can reconnect to
the console to complete the installation process.
Kicking controller2 into gear
Domain controller2 destroyed

Domain controller2 has been undefined


Starting install...
Domain installation still in progress. You can reconnect to
the console to complete the installation process.
Kicking controller3 into gear
Domain controller3 destroyed

Domain controller3 has been undefined


Starting install...
Domain installation still in progress. You can reconnect to
the console to complete the installation process.
Kicking compute1 into gear
Domain compute1 destroyed

Domain compute1 has been undefined


Starting install...
Domain installation still in progress. You can reconnect to
the console to complete the installation process.
Kicking compute2 into gear
Domain compute2 destroyed

Domain compute2 has been undefined


Starting install...
Domain installation still in progress. You can reconnect to
the console to complete the installation process.
```
Check if they are running

```
[root@shuttle scripts]# virsh list
setlocale: No such file or directory
Id    Name                           State
----------------------------------------------------
10    controller1                    running
11    controller2                    running
12    controller3                    running
13    compute1                       running
14    compute2                       running
```

### Attaching IPMI translation between Libvirt/KVM and VBMC <a name="hookvbmc">

Run the script to add the virtual machines to vbmc.
```
./connect_dom_vbmc.sh
Kicking controller1 into gear in VirtualBMC with port 6230
Kicking controller2 into gear in VirtualBMC with port 6231
Kicking controller3 into gear in VirtualBMC with port 6232
Kicking compute1 into gear in VirtualBMC with port 6233
Kicking compute2 into gear in VirtualBMC with port 6234
```

Test the IPMI tools and connections
```
yum -y install ipmitool

ipmitool -I lanplus -U admin -P Wond3rfulWorld -H 192.168.122.1 -p 6230 power status
```
If things are working you can use the ipmitool to switch the VMs off to save resources for now

```
ipmitool -I lanplus -U admin -P Wond3rfulWorld -H 192.168.178.113 -p 6230 power off
ipmitool -I lanplus -U admin -P Wond3rfulWorld -H 192.168.178.113 -p 6231 power off
ipmitool -I lanplus -U admin -P Wond3rfulWorld -H 192.168.178.113 -p 6232 power off
ipmitool -I lanplus -U admin -P Wond3rfulWorld -H 192.168.178.113 -p 6233 power off
ipmitool -I lanplus -U admin -P Wond3rfulWorld -H 192.168.178.113 -p 6234 power off
ipmitool -I lanplus -U admin -P Wond3rfulWorld -H 192.168.178.113 -p 6235 power off
ipmitool -I lanplus -U admin -P Wond3rfulWorld -H 192.168.178.113 -p 6236 power off
ipmitool -I lanplus -U admin -P Wond3rfulWorld -H 192.168.178.113 -p 6237 power off
```


## Undercloud <a name="undercloud">
The following should be executed on the undercloud node.

### Subscription manager, repos and users <a name="subsrepos">
```
RHN_USR=<rhn username>
RHN_PASS=<password>
subscription-manager register --username=$RHN_USR --password=$RHN_PASS
subscription-manager attach --pool=<poolid>
subscription-manager release --set=8.2
subscription-manager repos --disable=*
subscription-manager repos --enable=rhel-8-for-x86_64-baseos-eus-rpms --enable=rhel-8-for-x86_64-appstream-eus-rpms --enable=rhel-8-for-x86_64-highavailability-eus-rpms --enable=ansible-2.9-for-rhel-8-x86_64-rpms --enable=openstack-16.1-for-rhel-8-x86_64-rpms --enable=fast-datapath-for-rhel-8-x86_64-rpms

yum update -y && reboot

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


### Creating the 'stack' undercloud env <a name="stacking">
as user stack
```
mkdir ~/images
mkdir ~/templates

sudo yum install -y python3-tripleoclient
```
Also enable the Ceph repo and install Ceph Ansible
```
sudo subscription-manager repos --enable=rhel-7-server-rhceph-3-tools-rpms
sudo yum install -y ceph-ansible
```

Copy the sample file or the last one used in notes/undercloud.conf
```
cp \
  /usr/share/python-tripleoclient/undercloud.conf.sample \
  ~/undercloud.conf
```


### Populating the local registry with container images <a name="containerreg">
As the stack user on the undercloud node

```
openstack tripleo container image prepare default \
  --local-push-destination \
  --output-env-file containers-prepare-parameter.yaml
```
Make sure you add your access.redhat.com credentials to the containers-prepare-parameter.yaml:
(replace my_username and my_password with a valid account and password, same as you use to register systems to rhn)
```
ContainerImageRegistryCredentials:
   registry.redhat.io:
     my_username: my_password
```

Some examples to show how to push to a local registry for container images
```
openstack overcloud container image prepare   --namespace=registry.access.redhat.com/rhosp13   --push-destination=10.100.0.1:8787   --prefix=openstack-   --tag-from-label {version}-{release}   --output-env-file=/home/stack/templates/overcloud_images.yaml   --output-images-file /home/stack/local_registry_images.yaml

source ~/stackrc
openstack overcloud container image upload   --config-file  /home/stack/local_registry_images.yaml   --verbose
```
check images in the registry
```
curl -s -H "Accept: application/json" http://10.100.0.1:8787/v2/_catalog | python -m json.tool
```

Kick off the undercloud deployment process
```
openstack undercloud install
```


Overcloud images
```
sudo yum -y install rhosp-director-images
tar -C images -xvf /usr/share/rhosp-director-images/overcloud-full.tar
tar -C images -xvf /usr/share/rhosp-director-images/ironic-python-agent.tar

source ~/stackrc
openstack overcloud image upload --image-path ~/images
```

### Adding the overcloud nodes <a name="addingnodes">

```
openstack overcloud node import instackenv.json

for node in `openstack baremetal node list -f value | grep manageable | cut -d' ' -f1`; do openstack overcloud node introspect $node --provide > /tmp/$node.log & sleep 5; done
```
Or check an individual node
```
openstack overcloud node introspect compute1 --provide
```

Checking introspection data and that all nodes were correctly processed
```
openstack baremetal introspection list
openstack baremetal node show controller1 -f json -c driver_info
```
Make sure there are no duplicate ip's on the VLANs https://access.redhat.com/solutions/3799151


abort running introspection
```
openstack baremetal introspection abort overcloud-controller1
```

## Overcloud configuration <a name="overcloudconfig">

### Display and use introspection data <a name="spectiondata">
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
### Templates! Preparing then <a name="templates">
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

Gathering important and frequently used Templates

```
THT=/usr/share/openstack-tripleo-heat-templates
cp $THT/roles_data.yaml ~/templates
cp $THT/network_data.yaml ~/templates
```

Change network_data.yaml to reflect the network details. Meaning so much as to change the vlan information and IPv4 networks. Remove IPv6 if not needed or change this to your needs.

With the roles and the updated network data we process the templates into something useful
```
mkdir ~/workplace
mkdir ~/output
cp -rp /usr/share/openstack-tripleo-heat-templates/* workplace

cd workplace/
tools/process-templates.py -r ../templates/roles_data.yaml -n ../templates/network_data.yaml -o ../output
```

Out of the processed templates we take the network config
```
cd output/
cp environments/network-environment.yaml ~/templates/environments

mkdir -p ~/templates/network/config/multiple-nics/
cp ~/output/network/config/multiple-nics/*.yaml ~/templates/network/config/multiple-nics/

sed -i 's#../../scripts/run-os-net-config.sh#/usr/share/openstack-tripleo-heat-templates/network/scripts/run-os-net-config.sh#' -i templates/network/config/multiple-nics/*.yaml



### Running the deployment process <a name="deployment">

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
