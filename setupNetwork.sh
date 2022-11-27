#!/bin/bash

# part of https://github.com/TCAO-2/linux-utilities

# Copyright (c) 2022 Raphaël MARTIN
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# this script is used to set up connections via nmcli
# you can build a ragular internet connection or a bridge connection, with or without static ip
# be careful, all connections and virtual devices are removed on init
# bridge interfaces take less than a minute to activate after the program ends, no restart needed





####################################################################################################
# cleaning
####################################################################################################

echo "cleaning connections..."
connectionsList=$(nmcli connection show | tail -n+2 | grep -Po '^(\S+\s)*\S+' | sed -s 's/\s/:/g')
for connection in $connectionsList; do
	connection=$(echo $connection | sed -s 's/:/ /g')
	nmcli connection delete "${connection}"
done

echo "cleaning devices..."
devicesList=$(nmcli device show | grep -E 'GENERAL\.DEVICE' | grep -Eo '\S*$')
for device in $devicesList; do
	nmcli device delete $device
done

connectionsList=$(nmcli connection show | tail -n+2 | grep -Po '^(\S+\s)*\S+')
echo "connections left:"
echo $connectionsList
devicesList=$(nmcli device show | grep -E 'GENERAL\.DEVICE' | grep -Eo '\S*$')
echo "devices left:"
echo $devicesList





####################################################################################################
# set up static ip function called when new connection is created
####################################################################################################

function setupIP () { # $1=connection
	while true; do
		read -r -p "set up static ip for $1? [Y/n] " input
		case $input in
			[yY][eE][sS]|[yY])
				while true; do
					read -r -p "ipv4.addresses/netmask " addresses
					echo $addresses | grep -E '/[0-9]{1,2}$' > /dev/null
					if [ $? -ne 0 ]; then echo "invalid input, must contain netmask"; continue; fi
					nmcli con mod $1 ipv4.addresses "${addresses}"
					if [ $? -ne 0 ]; then continue; fi
					read -r -p "ipv4.gateway " gateway
					nmcli con mod $1 ipv4.gateway "${gateway}"
					if [ $? -ne 0 ]; then continue; fi
					read -r -p "ipv4.dns " dns
					if [ $? -ne 0 ]; then continue; fi
					nmcli con mod $1 ipv4.dns "${dns}"
					nmcli con mod $1 ipv4.method manual
					nmcli con up $1
					break
				done
				break
				;;
			[nN][oO]|[nN])
				break
				;;
			*)
				echo "invalid input..."
				;;
		esac
	done	
}





####################################################################################################
# recreating connections
####################################################################################################

bridgeNumber=0
for device in $devicesList; do
	while true; do
		read -r -p "set up bridge connection for ${device} device? [Y/n] " input
		case $input in
			[yY][eE][sS]|[yY]|[oO][uU][iI]|[oO])
				# bridge connection set up
				nmcli connection add type bridge con-name br${bridgeNumber} ifname br${bridgeNumber}
				nmcli connection add type ethernet slave-type bridge con-name bridge-br${bridgeNumber} ifname $device master br${bridgeNumber}
				nmcli connection up br${bridgeNumber}
				currentConnectionsList=$(nmcli conn show --active | grep $device | grep -Po '^(\S+\s)*\S+' | grep -v bridge | sed -s 's/\s/:/g')
				for currentConnection in $currentConnectionsList; do
					currentConnection=$(echo $currentConnection | sed -s 's/:/ /g')
					nmcli connection down "${currentConnection}"
				done
				# bridge with static ip for the host case
				setupIP "br${bridgeNumber}"
				bridgeNumber=$((bridgeNumber + 1))
				break
			  	;;
			[nN][oO]|[nN]|[nN][oO][nN])
				while true; do
			                read -r -p "set up regular ethernet connection for $1? [Y/n] " input
			                case $input in
                        			[yY][eE][sS]|[yY])
							# regular ethernet connection set up
							nmcli connection add type ethernet con-name $device ifname $device
							nmcli connection up $device
							# regular ethernet connection with static ip for the host case
							setupIP $device
							break
							;;
			                        [nN][oO]|[nN])
			                                break
                        			        ;;
			                        *)
                        			        echo "invalid input..."
			                                ;;
					esac
				done
				break
				;;
			*)
				echo "invalid input..."
				;;
		esac
	done
done
