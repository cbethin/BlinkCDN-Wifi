modprobe ifb numifbs=1

ip link set dev ifb0 up
echo "ifb0"

tc qdisc del root dev ifb0
echo "Delete qdisc for ifb0 -- May Return No Such File or Directory (Its OK if it does)"
tc qdisc del root dev br-lan
echo "delete br-lan"
tc qdisc del root dev eth0
echo "delete eth0"

tc qdisc del dev br-lan handle ffff: ingress
echo "delete ingress"
tc qdisc add dev br-lan handle ffff: ingress
echo "Add ingress"
tc filter add dev br-lan parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev ifb0
echo "Link eth0 & ifb0"
echo "------------------------------------------"
tc qdisc add dev br-lan root handle 1: htb default 30
echo "added br-lan htb default"
tc class add dev br-lan parent 1:3 classid 1:3 htb rate 5000kbit
echo "added first htb limit"
echo "------------------------------------------"
tc qdisc add dev ifb0 root handle 1: htb default 30
echo "added ifb htb default"
tc class add dev ifb0 parent 1:3 classid 1:3 htb rate 5000kbit
echo "added first ifb rate"
echo "------------------------------------------"
tc filter add dev br-lan protocol ip parent 1:0 prio 3 u32 \
    match ip dst 192.168.8.229/32 flowid 1:3

    echo "appended ip to br-lan htb rate"

tc filter add dev ifb0 protocol ip parent 1:0 prio 3 u32 \
    match ip dst 192.168.8.229/32 flowid 1:3
    echo "appended ip to ifb0 htb rate"
