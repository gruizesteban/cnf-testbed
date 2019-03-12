#!/bin/bash

if [ $# -lt 4 ]; then
  echo "you need to pass three parameters:"
  echo " subnet start address (e.g. network address)"
  echo " subnet cidr (e.g. 24)"
  echo " gateway address (e.g. network address +1)"
  echo " internal vlan id (e.g. 1044)"
exit 1
fi

subnet=$1
cidr=$2
gateway=$3
vlan=$4

source ~/openrc
if [ !  "$( openstack network list | grep ${vlan} |  awk '{print $4}' )" == "vlan${vlan}" ] ;then
openstack network create --disable-port-security --provider-segment ${vlan} --provider-network-type vlan --provider-physical-network provider vlan${vlan}
(( vlan_subnet = $RANDOM % 254 ))
openstack subnet create --network vlan${vlan} --subnet-range 10.${vlan_subnet}.0.0/24 --no-dhcp --dns-nameserver 8.8.8.8 --dns-nameserver 8.8.4.4 subnet${vlan}
fi

if [ !  "$( openstack network list | awk '/netext/ {print $4}' )" == "netext" ] ;then
openstack network create --external --provider-network-type flat --provider-physical-network flat netext
openstack subnet create --network netext --subnet-range $subnet/$cidr --no-dhcp --gateway $gateway subnetext
fi

if [ ! "$( openstack router list | awk '/routerext/ {print $4}' )" == "routerext" ] ;then
openstack router create routerext
openstack router add subnet routerext subnet$vlan
openstack router set routerext --external-gateway netext --enable-snat
fi

if [ ! "$( ip a | grep ${gateway} | awk '{print $2}' )" == "${gateway}/${cidr}" ]; then
ip a a $gateway/$cidr dev uplink
ip l s up dev uplink
fi

if [ ! "$(grep net.ipv4.ip_forward=1 /etc/sysctl.conf | wc -l)" == "1" ]; then
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.default.forwarding=1' >> /etc/sysctl.conf
sysctl --system
iptables -t nat -A POSTROUTING -s 10.0.0.0/8 -o bond0 -j MASQUERADE
fi
