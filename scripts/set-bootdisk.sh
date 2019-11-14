#For multiple disks set up make sure the first disk is being used and set at 60G
for i in `ironic node-list | awk 'NR>2' |awk '{print $2;}'`;
  do openstack baremetal node set --property root_device='{"name": "/dev/vda"}'  $i;
done

for i in `ironic node-list | awk 'NR>2' |awk '{print $2;}'`;
  do openstack baremetal node set  --property local_gb=60  $i;
done

#####
for i in `openstack baremetal node list | awk 'NR>2' |awk '{print $4;}'`;
  do openstack baremetal node set --property root_device='{"name": "/dev/vda"}'  $i;
done

for i in `openstack image list | awk 'NR>2' |awk '{print $2;}'`;
  do openstack image delete $i;
done

####set boot device for ceph nodes #####
for i in $(openstack overcloud profiles list | grep ceph | awk '{print $2}');
  do openstack baremetal node set --property root_device='{"name": "/dev/sda"}'  $i;
done

for i in `openstack overcloud profiles list | grep ceph | awk '{print $4}'`;
  do openstack baremetal node set --property root_device='{"name": "/dev/sda"}'  $i;
done
