#!/usr/bin/env bash

echo_ip_links(){
    array_test=()
    for iface in $(ip l | awk -F ":" '/^[0-9]+:/{dev=$2 ; if ( dev !~ /^ lo$/) {print $2}}')
    do
        # printf "$iface\n"
        array_test+=("$iface")
    done
    echo ${array_test[@]}
}

enable_forwarding(){
    sysctl -w net.ipv4.ip_forward=1
    sysctl -w net.ipv6.conf.all.forwarding=1
}

enable_seg6(){
    sysctl -w net.ipv6.conf.all.seg6_enabled=1
    sysctl -w net.ipv4.conf.default.rp_filter=0
    sysctl -w net.ipv4.conf.all.rp_filter=0

    for iface in $(echo_ip_links)
    do 
        attr=(${iface//@/ })
        iface_name=${attr[0]}
        echo $iface_name
        sysctl -w net.ipv6.conf.$iface_name.seg6_enabled=1
        sysctl -w net.ipv4.conf.$iface_name.rp_filter=0
    done
}


$1
