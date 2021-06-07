#!/bin/bash
### OpenStack internal API network
virsh net-define osp-networks/openstack-api.xml
virsh net-autostart openstack-api
virsh net-start openstack-api

### OpenStack deployment
virsh net-define osp-networks/deployment.xml
virsh net-autostart deployment
virsh net-start deployment

### OpenStack tenant
virsh net-define osp-networks/tenant.xml
virsh net-autostart tenant
virsh net-start tenant

### OpenStack external
virsh net-define osp-networks/external.xml
virsh net-autostart external
virsh net-start external

### storagemgmt
virsh net-define osp-networks/storagemgmt.xml
virsh net-autostart storagemgmt
virsh net-start storagemgmt

### storage
virsh net-define osp-networks/storage.xml
virsh net-autostart storage
virsh net-start storage

