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
