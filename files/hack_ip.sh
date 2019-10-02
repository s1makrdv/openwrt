#!/bin/sh

DEFAULT_GATEWAY='172.25.9.1'
DEFAULT_IP='172.25.9.51'
DNS_IP='8.8.8.8'

#--------------------------Ping Google DNS from current ip-------------------#
if ping -c 1 -w 1 -W 1 "$DNS_IP" >/dev/null; then
	exit 0
else
	logger "Internet troubles, Start script"
fi
#----------------------------------------------------------------------------#

#-------------------------------Set IP to Default----------------------------#
uci set network.wan.ipaddr="$DEFAULT_IP"
uci commit network
ifconfig eth0.2 down && /etc/init.d/network reload
while [ "up" != "$(cat /sys/class/net/eth0.2/operstate)" ] ; do : ; done #wait until interface setup
#----------------------------------------------------------------------------#

#-------------------------Ping DEfault Getaway-------------------------------#
if ping -c 1 -w 1 -W 1 $DEFAULT_GATEWAY
then
	logger "DEFAULT_GATEWAY available"
else
	logger "DEFAULT_GATEWAY connection error"
	exit 1
fi
#----------------------------------------------------------------------------#

#------------------------------Async Ping BroadCast/24-----------------------#
tmpdir=$(mktemp -d)
for i in  $(seq 2 254); 
do
(
  if ! ping -c 1 -i 1 -w 1 -W 1 "172.25.9.$i" >/dev/null; then
	   #touch "$tmpdir"/"$i"
	   echo "172.25.9.$i" >> "$tmpdir"/"multi_ip_dead.log"
   fi 
) &
done
wait
#-----------------------------------------------------------------------------#

#-------------------------CHECK DNS CONNECTION on every IP--------------------#
file="$tmpdir"/"multi_ip_dead.log"
while IFS= read -r line
do
	logger "Set LAN to $line"
	uci set network.wan.ipaddr="$line"
	uci commit network
	ifconfig eth0.2 down && /etc/init.d/network reload
	#wait until interface setup
    while [ "up" != "$(cat /sys/class/net/eth0.2/operstate)" ] ; do : ; done
	#Check Google DNS connection
	if ping -c 1 -w 1 -W 1 "$DNS_IP" >/dev/null; then
		logger "$line connected to Google DNS"
		break
	else
		logger "$line Failed connect to Google DNS"
	fi
done < "$file"
#------------------------------FINISH CHECKING--------------------------------#

rm -r "$tmpdir"
exit 0
