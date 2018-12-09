package main

import (
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/google/gopacket"
	"github.com/google/gopacket/layers"

	"github.com/google/gopacket/pcapgo"
)

const ethernetFrameSize int = 14

func getBandwidthArray(id string) map[string]int {

	routersMutex[id].Lock()
	if _, ok := routers[id]; !ok {
		return nil
	}

	ipBandwidths := make(map[string]int)

	for _, dev := range routers[id].PublicConnectedDevicesList {
		bytesReceived := 0

		// If the device has received packets, then sum up the bytes received
		// in the last 5 seconds
		if pktList, ok := routers[id].ReceivedPackets[dev.ip]; ok {
			fmt.Println(dev.ip, "--", len(pktList))
			for _, pkt := range pktList {
				if time.Since(pkt.timestamp) <= time.Duration(OLD_PACKET_TIMEOUT_TIME*int(time.Second)) {
					bytesReceived += getBandwidthFromPacket(pkt.data)
				}
			}
		}

		ipBandwidths[dev.ip] = bytesReceived / OLD_PACKET_TIMEOUT_TIME
	}

	// For all packets, loop through and add in the ones from 192.168
	// USE FOR TESTING ON LOCALHOST
	// for addr, pktList := range routers[id].ReceivedPackets {
	// 	if strings.Contains(addr, "10.1.") {
	// 		bytesReceived := 0
	// 		for _, pkt := range pktList {
	// 			if time.Since(pkt.timestamp) <= 5*time.Second {
	// 				bytesReceived += getBandwidthFromPacket(pkt.data)
	// 			}
	// 		}

	// 		ipBandwidths[addr] = bytesReceived / 5
	// 	}
	// }

	routersMutex[id].Unlock()

	return ipBandwidths
}

func writePacketToFile(packetdata []byte) {
	if _, err := os.Stat("packetCap.pcapng"); os.IsNotExist(err) {
		pcapWriteMutex.Lock()
		f, _ := os.Create("packetCap.pcapng")

		w := pcapgo.NewWriter(f)
		w.WriteFileHeader(65536, layers.LinkTypeEthernet)
		w.WritePacket(gopacket.CaptureInfo{Timestamp: time.Now(), Length: len(packetdata), CaptureLength: len(packetdata)}, packetdata)
		f.Close()
		pcapWriteMutex.Unlock()
	} else {
		// fmt.Println("Appending")
		pcapWriteMutex.Lock()
		f, err := os.OpenFile("packetCap.pcapng", os.O_APPEND|os.O_WRONLY, 0700)
		if err != nil {
			fmt.Println("Error appending to file:", err)
		}

		w := pcapgo.NewWriter(f)
		err = w.WritePacket(gopacket.CaptureInfo{Timestamp: time.Now(), Length: len(packetdata), CaptureLength: len(packetdata)}, packetdata)
		if err != nil {
			fmt.Println("Error writing packet:", err)
		}
		f.Close()
		pcapWriteMutex.Unlock()
	}
}

func getBandwidthFromPacket(packetData []byte) int {

	packet := gopacket.NewPacket(packetData, layers.LayerTypeEthernet, gopacket.Default)

	if ipLayer := packet.Layer(layers.LayerTypeIPv6); ipLayer != nil {

		ip, _ := ipLayer.(*layers.IPv6)
		packetLength := int(ip.Length) + ethernetFrameSize
		return packetLength

	} else if ipLayer := packet.Layer(layers.LayerTypeIPv4); ipLayer != nil {

		ip, _ := ipLayer.(*layers.IPv4)
		packetLength := int(ip.Length) + ethernetFrameSize
		return packetLength

	} else {

	}

	return len(packetData)
}

// TCPData : Features for testing TCP failures
type TCPData struct {
	SrcAddr   string
	DstAddr   string
	Seq       uint32
	Timestamp time.Time
}

func countTCPFailuresInTime(id string, n int) map[string]int {
	if _, ok := routers[id]; !ok {
		return nil
	}

	// if _, ok := routersMutex[id]; !ok {
	// 	routersMutex[id] = &sync.Mutex{}
	// }

	var retransmitsForDevice = make(map[string]int)

	routersMutex[id].Lock()
	for _, pktData := range routers[id].TCPRetransmissions {
		// If packet is newer than n seconds, count it
		if time.Since(pktData.Timestamp) < (time.Duration(3) * time.Second) {
			addr := strings.Split(pktData.DstAddr, ":")[0]
			if _, ok := retransmitsForDevice[addr]; !ok {
				retransmitsForDevice[addr] = 0
			}

			retransmitsForDevice[addr]++
		}
	}
	routersMutex[id].Unlock()

	return retransmitsForDevice
}

func testTCPFailure(packet gopacket.Packet, routerID string) {
	routersMutex[routerID].Lock()

	srcAddr := ""
	dstAddr := ""

	if ipLayer := packet.Layer(layers.LayerTypeIPv6); ipLayer != nil {
		ip, _ := ipLayer.(*layers.IPv6)
		dstAddr = ip.DstIP.String()
		srcAddr = ip.SrcIP.String()
	} else if ipLayer := packet.Layer(layers.LayerTypeIPv4); ipLayer != nil {
		ip, _ := ipLayer.(*layers.IPv4)
		dstAddr = ip.DstIP.String()
		srcAddr = ip.SrcIP.String()
	}

	// Add TCP packets to list if they have a IP src/dst addr
	if srcAddr != "" && dstAddr != "" {
		if tcpLayer := packet.Layer(layers.LayerTypeTCP); tcpLayer != nil {
			tcp, _ := tcpLayer.(*layers.TCP)
			srcAddr += ":" + tcp.SrcPort.String()
			dstAddr += ":" + tcp.DstPort.String()

			tcpData := TCPData{SrcAddr: srcAddr, DstAddr: dstAddr, Seq: tcp.Seq, Timestamp: time.Now()}

			router := routers[routerID]

			if _, ok := router.TCPPackets[dstAddr]; !ok {
				router.TCPPackets[dstAddr] = make([]TCPData, 0)
			}

			// If another packet has the same src/dst addr, tcp seq #, and occured less than 3 ms ago, it's a retransmission probably

			for _, pktData := range router.TCPPackets[dstAddr] {
				if pktData.SrcAddr == srcAddr && pktData.Seq == tcp.Seq && time.Since(pktData.Timestamp) < (3*time.Millisecond) {
					router.TCPRetransmissions = append(router.TCPRetransmissions, tcpData) // add to our tcpRetransmissions array
					break
				}
			}

			router.TCPPackets[dstAddr] = append(router.TCPPackets[dstAddr], TCPData{SrcAddr: srcAddr, DstAddr: dstAddr, Seq: tcp.Seq, Timestamp: time.Now()})

			routers[routerID] = router
		}
	}

	routersMutex[routerID].Unlock()
}
