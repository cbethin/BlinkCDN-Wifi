#!/bin/sh

tc qdisc del dev br-lan root
tc qdisc add dev br-lan root handle 1: prio
tc filter add dev br-lan protocol ip parent 1: prio 1 u32 match ip dst 192.168.8.194
#tc filter add dev br-lan protocol ip parent 1: prio 50 u32 match ip dst 192.168.8.0/24
