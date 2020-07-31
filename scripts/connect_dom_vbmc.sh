#!/bin/bash
## Connect the OSP overcloud nodes to vmbc

servers="controller1 controller2 controller3 compute1 compute2"
binpath="/opt/vbmc/bin"
vbmc_port=6230
ipmi_username=admin
ipmi_password=Wond3rfulWorld
impi_bindaddr=192.168.122.1

for server in $servers; do
    echo "Kicking $server into gear in VirtualBMC with port $vbmc_port"
    $binpath/vbmc add $server --address $impi_bindaddr --port $vbmc_port --username $ipmi_username --password $ipmi_password
    $binpath/vbmc start $server
    ((vbmc_port=vbmc_port+1))
done
