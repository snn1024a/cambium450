#!/bin/bash
cambIP="169.254.1.1"
lockIP="169.254.1.21"
cambID="0A:00:3E"

ethInt="$1"
existIpIf=$(ifconfig |grep -B1 $lockIP|grep HWaddr|awk -F ' ' '{print $1}');

if [ -z "$existIpIf" ]; then
        sudo ifconfig "$ethInt:1" "$lockIP" netmask "255.255.255.0" up
        for (( ; ; )); do
                sleep 1
                now=$(date +%s-%F@%T);
                echo -n "$now ";
                ping -I $ethInt -c3 -i.3 -w0.3 $cambIP >/dev/null 2>&1
                if [ $? -eq 0 ]; then
                        echo -e "PING $cambIP \e[33mOK\e[0m"
                        sleep 1
                        arp -a| grep -i $cambIP;
                        sleep 1
                        arp -a| grep -v incomplete| grep $ethInt| grep $cambIP| grep -i $cambID >/dev/null 2>&1
                        if [ $? -eq 0 ]; then
                                mac=$(arp -a| grep -v incomplete| grep $ethInt| grep $cambIP| grep -i $cambID| grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}');
                                echo -e "ARP MACH $cambIP - $cambID \e[33mOK\e[0m"
                                sleep 1
                                curl "http://$cambIP/login.cgi?SNMPReadOnly=0&ok=Save%20Changes" >/dev/null 2>&1
                                if [ $? -eq 0 ]; then
                                        echo -e "CURL to switch SNMP write $cambIP \e[33mOK\e[0m"
                                        sleep 1
                                        snmpset -v2c -c Canopy $cambIP .1.3.6.1.4.1.161.19.3.3.2.50.0 i 1 >/dev/null 2>&1
                                        if [ $? -eq 0 ]; then
                                                echo -e "SNMP for DHCP client ON $cambIP \e[33mOK\e[0m"
                                                sleep 1
                                                snmpset -v2c -c Canopy $cambIP .1.3.6.1.4.1.161.19.3.3.3.2.0 i 1 >/dev/null 2>&1
                                                if [ $? -eq 0 ]; then
                                                        echo "$now $mac" >> "${0}.log"
                                                        echo -e "SNMP $cambIP REBOOT \e[32mOK\e[0m"
                                                        sleep 3
                                                        sudo ip -s -s neigh flush $cambIP dev $ethInt
                                                else
                                                        echo -e "SNMP $cambIP REBOOT \e[31mFAIL\e[0m"
                                                fi
                                        else
                                                echo -e "SNMP for DHCP client ON $cambIP \e[31mFAIL\e[0m"
                                                sudo ip -s -s neigh flush $cambIP dev $ethInt
                                        fi
                                else
                                        echo -e "CURL to switch SNMP write $cambIP \e[31mFAIL\e[0m"
                                        sudo ip -s -s neigh flush $cambIP dev $ethInt
                                fi
                        else
                                echo -e "ARP MACH $cambIP - $cambID \e[31mFAIL\e[0m"
                                sudo ip -s -s neigh flush $cambIP dev $ethInt
                        fi
                else
                        echo -ne "PING $cambIP \e[31mFAIL\e[0m "
                        sudo ip -s -s neigh flush $cambIP dev $ethInt
                fi
        done
else
        sudo ifconfig "$existIpIf" del "$lockIP"
        ${0} $1
fi
