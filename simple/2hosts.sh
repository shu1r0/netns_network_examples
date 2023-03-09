#!/usr/bin/env bash

## install ovs
# apt install -y openvswitch-switch
# systemctl start openvswitch-switch

if [[ $(id -u) -ne 0 ]] ; then echo "Please run with sudo" ; exit 1 ; fi


echo_run () {
    echo "$@"
    $@ || exit 1
}

create_net() {
    echo_run ip netns add ns1
    echo_run ip netns add ns2

    echo_run ip link add name ns1_veth1 type veth peer name ns2_veth1
    echo_run ip link add name ns1_veth2 type veth peer name ns2_veth2
    echo_run ip link set ns1_veth1 netns ns1
    echo_run ip link set ns2_veth1 netns ns2
    echo_run ip link set ns1_veth2 netns ns1
    echo_run ip link set ns2_veth2 netns ns2

    echo_run ip netns exec ns1 ip link set ns1_veth1 up
    echo_run ip netns exec ns2 ip link set ns2_veth1 up
    echo_run ip netns exec ns1 ip link set ns1_veth2 up
    echo_run ip netns exec ns2 ip link set ns2_veth2 up
    echo_run ip netns exec ns1 ip link set lo up
    echo_run ip netns exec ns2 ip link set lo up

    echo_run ip netns exec ns1 ip addr add 192.168.10.1/24 dev ns1_veth1
    echo_run ip netns exec ns2 ip addr add 192.168.10.2/24 dev ns2_veth1
    echo_run ip netns exec ns1 ip -6 addr add 2001:db8:10::1/48 dev ns1_veth1
    echo_run ip netns exec ns2 ip -6 addr add 2001:db8:10::2/48 dev ns2_veth1
    echo_run ip netns exec ns1 ip addr add 192.168.20.1/24 dev ns1_veth2
    echo_run ip netns exec ns2 ip addr add 192.168.20.2/24 dev ns2_veth2
    echo_run ip netns exec ns1 ip -6 addr add 2001:db8:20::1/48 dev ns1_veth2
    echo_run ip netns exec ns2 ip -6 addr add 2001:db8:20::2/48 dev ns2_veth2
}


destroy_net() {
    echo_run ip netns delete ns1
    echo_run ip netns delete ns2
}

while getopts "cd" opt; do
    case "${opt}" in
        d)
            destroy_net
            ;;
        c)
            create_net
            ;;
        *)
            exit 1
            ;;
    esac
done
