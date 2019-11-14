#version=DEVEL
# System authorization information
auth --enableshadow --passalgo=sha512
# Use CDROM installation media
cdrom
# Use text mode install
text
# Run the Setup Agent on first boot
firstboot --enable
ignoredisk --only-use=vda
# Keyboard layouts
keyboard --vckeymap=us --xlayouts=''
# System language
lang en_US.UTF-8

# Network information
firewall --disabled
network --bootproto=static --device=eth0 --ip=10.100.0.14 --netmask=255.255.255.0
network  --hostname=compute1.zokahn.local

# Root password
rootpw --iscrypted $6$0Q&VxT5Pbb^g&tX9$ybGAwxu1ZK/zJbzS.X9Tte..IdRmzmxKPPXDQEsj/5pz/Nr1zLka1YFnbNLrNjobXtmwgMg7sg9yfGKYOp5HD0
# System services
services --enabled="chronyd"
# Do not configure the X Window System
skipx
# System timezone
timezone Europe/Amsterdam --isUtc
user --groups=wheel --name=bvandenh --password=$6$0Q&VxT5Pbb^g&tX9$ybGAwxu1ZK/zJbzS.X9Tte..IdRmzmxKPPXDQEsj/5pz/Nr1zLka1YFnbNLrNjobXtmwgMg7sg9yfGKYOp5HD0 --iscrypted --gecos="Bart van den Heuvel"
# System bootloader configuration
bootloader --append=" crashkernel=auto" --location=mbr --boot-drive=vda
autopart --type=thinp
# Partition clearing information
clearpart --all --initlabel --drives=vda

%packages
@core
chrony
kexec-tools
net-tools
bind-utils
wget


%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end

%anaconda
#pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
#pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
#pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end
