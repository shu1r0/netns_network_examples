#!/usr/bin/env bash


# ref:
#    * https://wiki.fd.io/view/VPP/Progressive_VPP_Tutorial


if [[ $(id -u) -ne 0 ]]; then 
    echo "Require root privilege"
    exit 1
fi

current_script=$(realpath $0)
current_dir=$(dirname $current_script)
source $current_dir/../functions.sh

##### IOAM CONFIG #####
ns_id=100
ns_spec_data=0xbeefcafe
ns_spec_data_wide=0xbeefbeefcafecafe

echo_run () {
    echo "$@"
    $@ || exit 1
}


create_net() {
    grep -i IOAM /boot/config-$(uname -r)

    # create netns
    echo_run ip netns add h1
    echo_run ip netns add h2
    echo_run ip netns add r1
    echo_run ip netns add r2
    echo_run ip netns add r3
    echo_run ip netns add r4

    echo_run add_link r1 r1_h1 h1_r1 h1
    echo_run add_link r1 r1_r2 r2_r1 r2
    echo_run add_link r1 r1_r3 r3_r1 r3

    echo_run add_link r2 r2_r4 r4_r2 r4

    echo_run add_link r3 r3_r4 r4_r3 r4

    echo_run add_link r4 r4_h2 h2_r4 h2

    echo_run ip netns exec r1 $current_dir/../functions.sh enable_seg6
    echo_run ip netns exec r2 $current_dir/../functions.sh enable_seg6
    echo_run ip netns exec r3 $current_dir/../functions.sh enable_seg6
    echo_run ip netns exec r4 $current_dir/../functions.sh enable_seg6

    echo_run ip netns exec r1 ip addr add 192.168.10.1/24 dev r1_h1
    echo_run ip netns exec h1 ip addr add 192.168.10.2/24 dev h1_r1
    echo_run ip netns exec h1 ip route add default via 192.168.10.1 dev h1_r1
    echo_run ip netns exec r1 ip -6 addr add fd00:10::1/48 dev r1_h1
    echo_run ip netns exec h1 ip -6 addr add fd00:10::2/48 dev h1_r1
    echo_run ip netns exec h1 ip -6 route add default via fd00:10::1 dev h1_r1



    echo_run ip netns exec r4 ip addr add 192.168.20.1/24 dev r4_h2
    echo_run ip netns exec h2 ip addr add 192.168.20.2/24 dev h2_r4
    echo_run ip netns exec h2 ip route add default via 192.168.20.1 dev h2_r4
    echo_run ip netns exec r4 ip -6 addr add fd00:20::1/48 dev r4_h2
    echo_run ip netns exec h2 ip -6 addr add fd00:20::2/48 dev h2_r4
    echo_run ip netns exec h2 ip -6 route add default via fd00:20::1 dev h2_r4

    echo_run ip netns exec r1 ip -6 addr add fd00:12::1/48 dev r1_r2
    echo_run ip netns exec r2 ip -6 addr add fd00:12::2/48 dev r2_r1

    echo_run ip netns exec r1 ip -6 addr add fd00:13::1/48 dev r1_r3
    echo_run ip netns exec r3 ip -6 addr add fd00:13::2/48 dev r3_r1

    echo_run ip netns exec r2 ip -6 addr add fd00:24::1/48 dev r2_r4
    echo_run ip netns exec r4 ip -6 addr add fd00:24::2/48 dev r4_r2

    echo_run ip netns exec r3 ip -6 addr add fd00:34::1/48 dev r3_r4
    echo_run ip netns exec r4 ip -6 addr add fd00:34::2/48 dev r4_r3
}

configure_ioam(){
    echo "# Enable ioam ip tunnel"
    echo_run ip netns exec r1 $current_dir/../functions.sh enable_ioam
    echo_run ip netns exec r2 $current_dir/../functions.sh enable_ioam
    echo_run ip netns exec r3 $current_dir/../functions.sh enable_ioam
    echo_run ip netns exec r4 $current_dir/../functions.sh enable_ioam

    echo "# Set Node id"
    echo_run ip netns exec r1 $current_dir/../functions.sh setup_ioam_node 1 0x11111111
    echo_run ip netns exec r2 $current_dir/../functions.sh setup_ioam_node 2 0x22222222
    echo_run ip netns exec r3 $current_dir/../functions.sh setup_ioam_node 3 0x33333333
    echo_run ip netns exec r4 $current_dir/../functions.sh setup_ioam_node 4 0x44444444

    echo "# Set Interface id"
    echo_run ip netns exec r1 $current_dir/../functions.sh setup_ioam_intf r1_r2 0x0102 0x01020102
    echo_run ip netns exec r1 $current_dir/../functions.sh setup_ioam_intf r1_r3 0x0103 0x01030103

    echo_run ip netns exec r2 $current_dir/../functions.sh setup_ioam_intf r2_r1 0x0201 0x02010201
    echo_run ip netns exec r2 $current_dir/../functions.sh setup_ioam_intf r2_r4 0x0204 0x02020204

    echo_run ip netns exec r3 $current_dir/../functions.sh setup_ioam_intf r3_r1 0x0301 0x03010301
    echo_run ip netns exec r3 $current_dir/../functions.sh setup_ioam_intf r3_r4 0x0304 0x03020304

    echo_run ip netns exec r4 $current_dir/../functions.sh setup_ioam_intf r4_r2 0x0202 0x02020202
    echo_run ip netns exec r4 $current_dir/../functions.sh setup_ioam_intf r4_r3 0x0203 0x02030203

    echo "# Set Namespase id"
    echo_run ip netns exec r1 ip ioam namespace add $ns_id data $ns_spec_data wide $ns_spec_data_wide
    echo_run ip netns exec r2 ip ioam namespace add $ns_id data $ns_spec_data wide $ns_spec_data_wide
    echo_run ip netns exec r3 ip ioam namespace add $ns_id data $ns_spec_data wide $ns_spec_data_wide
    echo_run ip netns exec r4 ip ioam namespace add $ns_id data $ns_spec_data wide $ns_spec_data_wide
}


test_net() {
    echo_run ip netns exec r1 ip -6 route replace fd00:24::/48 via fd00:12::2 dev r1_r2
    echo_run ip netns exec r1 ip -6 route replace fd00:34::/48 via fd00:13::2 dev r1_r3
    echo_run ip netns exec r2 ip -6 route replace fd00:13::/48 via fd00:12::1 dev r2_r1
    echo_run ip netns exec r2 ip -6 route replace fd00:34::/48 via fd00:24::2 dev r2_r4
    echo_run ip netns exec r3 ip -6 route replace fd00:12::/48 via fd00:13::1 dev r3_r1
    echo_run ip netns exec r3 ip -6 route replace fd00:24::/48 via fd00:34::2 dev r3_r4
    echo_run ip netns exec r4 ip -6 route replace fd00:12::/48 via fd00:24::1 dev r4_r2
    echo_run ip netns exec r4 ip -6 route replace fd00:13::/48 via fd00:34::1 dev r4_r3

    sudo ip netns exec r1 ip ioam namespace show
    sudo ip netns exec r1 ip ioam schema show

    # Trace Type
    # IOAM Option size = DataSize(n-octet) + TraceHeader(8-octet)
    # size = 4 * 2
    trace_type=0x800000  # 0b1000 0000 0000 0000 0000 0000
    echo_run ip netns exec r1 ip -6 route replace fd00:20::/48 encap ioam6 mode encap tundst fd00:24::2 trace prealloc type $trace_type ns $ns_id size 8 dev r1_r2
    echo_run ip netns exec r4 ip -6 route replace fd00:10::/48 encap ioam6 mode encap tundst fd00:12::1 trace prealloc type $trace_type ns $ns_id size 8 dev r4_r2
    echo_run ip netns exec h1 ping -c 2 fd00:20::2

    trace_type=0x820000  # 0b1000 0010 0000 0000 0000 0000
    # size = (4 + 4)* 2
    echo_run ip netns exec r1 ip -6 route replace fd00:20::/48 encap ioam6 mode encap tundst fd00:24::2 trace prealloc type $trace_type ns $ns_id size 16 dev r1_r2
    echo_run ip netns exec r4 ip -6 route replace fd00:10::/48 encap ioam6 mode encap tundst fd00:12::1 trace prealloc type $trace_type ns $ns_id size 16 dev r4_r2
    echo_run ip netns exec h1 ping -c 2 fd00:20::2

    trace_type=0x00c000  # 0b1000 0000 0000 0000 0000 0000
    # size = (8 + 8)* 2
    echo_run ip netns exec r1 ip -6 route replace fd00:20::/48 encap ioam6 mode encap tundst fd00:24::2 trace prealloc type $trace_type ns $ns_id size 32 dev r1_r2
    echo_run ip netns exec r4 ip -6 route replace fd00:10::/48 encap ioam6 mode encap tundst fd00:12::1 trace prealloc type $trace_type ns $ns_id size 32 dev r4_r2
    echo_run ip netns exec h1 ping -c 2 fd00:20::2

    trace_type=0xf00000
    # size = (4 + 4 + 4 + 4)* 2
    echo_run ip netns exec r1 ip -6 route replace fd00:20::/48 encap ioam6 mode encap tundst fd00:24::2 trace prealloc type $trace_type ns $ns_id size 32 dev r1_r2
    echo_run ip netns exec r4 ip -6 route replace fd00:10::/48 encap ioam6 mode encap tundst fd00:12::1 trace prealloc type $trace_type ns $ns_id size 32 dev r4_r2
    echo_run ip netns exec h1 ping -c 2 fd00:20::2

    trace_type=0x420000
    # size = (4 + 4)* 2
    echo_run ip netns exec r1 ip -6 route replace fd00:20::/48 encap ioam6 mode encap tundst fd00:24::2 trace prealloc type $trace_type ns $ns_id size 16 dev r1_r2
    echo_run ip netns exec r4 ip -6 route replace fd00:10::/48 encap ioam6 mode encap tundst fd00:12::1 trace prealloc type $trace_type ns $ns_id size 16 dev r4_r2
    echo_run ip netns exec h1 ping -c 2 fd00:20::2

    trace_type=0x440000
    # size = (4 + 4)* 2
    echo_run ip netns exec r1 ip -6 route replace fd00:20::/48 encap ioam6 mode encap tundst fd00:24::2 trace prealloc type $trace_type ns $ns_id size 24 dev r1_r2
    echo_run ip netns exec r4 ip -6 route replace fd00:10::/48 encap ioam6 mode encap tundst fd00:12::1 trace prealloc type $trace_type ns $ns_id size 24 dev r4_r2
    echo_run ip netns exec h1 ping -c 2 fd00:20::2

    trace_type=0x840000
    # size = (4 + 4)* 2
    echo_run ip netns exec r1 ip -6 route replace fd00:20::/48 encap ioam6 mode encap tundst fd00:24::2 trace prealloc type $trace_type ns $ns_id size 24 dev r1_r2
    echo_run ip netns exec r4 ip -6 route replace fd00:10::/48 encap ioam6 mode encap tundst fd00:12::1 trace prealloc type $trace_type ns $ns_id size 24 dev r4_r2
    echo_run ip netns exec h1 ping -c 2 fd00:20::2

    trace_type=0x800002
    # size = (4 + (4+4))* 2
    echo_run ip netns exec r1 ip -6 route replace fd00:20::/48 encap ioam6 mode encap tundst fd00:24::2 trace prealloc type $trace_type ns $ns_id size 24 dev r1_r2
    echo_run ip netns exec r4 ip -6 route replace fd00:10::/48 encap ioam6 mode encap tundst fd00:12::1 trace prealloc type $trace_type ns $ns_id size 24 dev r4_r2
    echo_run ip netns exec r1 ip ioam schema add 0x111 "oam1"
    echo_run ip netns exec r1 ip ioam namespace set $ns_id schema 0x111
    echo_run ip netns exec r2 ip ioam schema add 0x222 "oam2"
    echo_run ip netns exec r2 ip ioam namespace set $ns_id schema 0x222
    echo_run ip netns exec r2 ip netns exec r2 ip ioam namespace show
    echo_run ip netns exec h1 ping -c 2 fd00:20::2
}


destroy_net() {
    echo_run ip netns delete h1
    echo_run ip netns delete h2
    echo_run ip netns delete r1
    echo_run ip netns delete r2
    echo_run ip netns delete r3
    echo_run ip netns delete r4
}

while getopts "cdt" opt; do
    case "${opt}" in
        d)
            destroy_net
            ;;
        c)
            create_net
            configure_ioam
            ;;
        t)
            test_net
            ;;
        *)
            exit 1
            ;;
    esac
done
