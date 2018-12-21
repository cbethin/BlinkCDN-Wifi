tc qdisc del root dev br-lan
tc qdisc del root dev eth0
tc qdisc del root dev ifb0

# Adds prio qdisc to br-lan with label 1:
tc qdisc add dev br-lan root handle 1: prio

# Set low queue to all the ones that are in this script
tc qdisc add dev br-lan parent 1:3 handle 30: netem rate $1

for i in "$@"
do
    if [[ $i == *"bit"* ]]; then
        continue
    fi

    tc filter add dev br-lan protocol ip parent 1:0 prio 3 u32 \
        match ip dst $1/32 flowid 1:3
done