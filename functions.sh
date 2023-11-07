#!/usr/bin/env bash


echo_run () {
    echo "$@"
    $@ || exit 1
}

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
    echo_run sysctl -w net.ipv4.ip_forward=1
    echo_run sysctl -w net.ipv6.conf.all.forwarding=1
}

enable_seg6(){
    enable_forwarding
    echo_run sysctl -w net.ipv6.conf.all.seg6_enabled=1
    echo_run sysctl -w net.ipv4.conf.default.rp_filter=0
    echo_run sysctl -w net.ipv4.conf.all.rp_filter=0

    for iface in $(echo_ip_links)
    do 
        attr=(${iface//@/ })
        iface_name=${attr[0]}
        # echo $iface_name
        echo_run sysctl -w net.ipv6.conf.$iface_name.seg6_enabled=1
        echo_run sysctl -w net.ipv4.conf.$iface_name.rp_filter=0
    done
}

setup_vpp(){
    vpp_name=$1
    vpp_sock=/run/vpp/cli-vpp-${vpp_name}.sock

    echo_run /usr/bin/vpp unix {cli-listen $vpp_sock} api-segment { prefix vpp-$vpp_name }
    sleep 1

    for iface in $(echo_ip_links)
    do 
        attr=(${iface//@/ })
        iface_name=${attr[0]}
        echo_run vppctl -s $vpp_sock create host-interface name $iface_name
        echo_run vppctl -s $vpp_sock  set interface state host-$iface_name up
    done
}

set_addr_vpp_hostinf(){
    vpp_name=$1
    intf=$2
    addr=$3
    vpp_sock=/run/vpp/cli-vpp-${vpp_name}.sock

    echo_run vppctl -s $vpp_sock set interface ip address host-$intf $addr
}

add_link(){
    node1=$1
    node1_intf=$2
    node2_intf=$3
    node2=$4
    echo_run ip link add name $node1_intf type veth peer name $node2_intf
    echo_run ip link set $node1_intf netns $node1
    echo_run ip link set $node2_intf netns $node2
    echo_run ip netns exec $node1 ip link set $node1_intf up
    echo_run ip netns exec $node2 ip link set $node2_intf up
}


enable_ioam(){
    enable_forwarding
    
    # for tunnel
    echo_run modprobe ip6_tunnel
    echo_run ip link set ip6tnl0 up

    echo_run sysctl -w net.ipv4.conf.default.rp_filter=0
    echo_run sysctl -w net.ipv4.conf.all.rp_filter=0

    for iface in $(echo_ip_links)
    do 
        attr=(${iface//@/ })
        iface_name=${attr[0]}
        echo $iface_name
        echo_run sysctl -w net.ipv4.conf.$iface_name.rp_filter=0
        echo_run sysctl -w net.ipv6.conf.$iface_name.ioam6_enabled=1
    done
}

setup_ioam_node(){
    ioam6_id=$1
    ioam6_id_wide=$2
    echo_run sysctl -w net.ipv6.ioam6_id=$ioam6_id
    echo_run sysctl -w net.ipv6.ioam6_id_wide=$ioam6_id_wide
}

setup_ioam_intf(){
    intf=$1
    ioam6_id=$2
    ioam6_id_wide=$3
    echo_run sysctl -w net.ipv6.conf.$intf.ioam6_id=$ioam6_id
    echo_run sysctl -w net.ipv6.conf.$intf.ioam6_id_wide=$ioam6_id_wide
}

$@
