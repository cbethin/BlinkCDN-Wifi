package main

import (
	"fmt"
	"net"
	"os"
	"strconv"
	"sync"
	"time"

	"github.com/google/gopacket"
	"github.com/google/gopacket/layers"
)

var packetCount = 0

func main() {
	commandStackChannel = make(map[string]chan bool)
	commandStack = make([]Command, 0)

	if len(os.Args) < 2 {
		fmt.Println("Wrong number of inputs.")
		os.Exit(1)
	}

	go startHTTPListening()
	go loadOUILookupDataset()

	ln, err := net.Listen("tcp", os.Args[1])
	if err != nil {
		fmt.Println("Error making connection.")
	}
	defer ln.Close()
	fmt.Println("Listening.")

	for {
		conn, err := ln.Accept()
		if err != nil {
			fmt.Println("Error accepting connection.")
		}

		go handleConnection(conn)
	}
}

func handleConnection(conn net.Conn) {
	buf := make([]byte, 10000)

	_, err := conn.Read(buf)
	if err != nil {
		fmt.Println("Read error:", err)
	}

	// Convert buffer to DataList
	datastream := ExtractDatastreamFromBuffer(buf)

	// ANALYZE DATA ------
	idForDatastream := ""
	for i := 0; i < len(datastream); i++ {
		if datastream[i] == "id" {
			i++
			if i >= len(datastream) {
				fmt.Println("Datastream terminated early when looking for id")
			}

			idForDatastream = string(datastream[i])
			if _, ok := routersMutex[idForDatastream]; !ok {
				routersMutex[idForDatastream] = &sync.Mutex{}
			}

			routersMutex[idForDatastream].Lock()
			if _, ok := routers[idForDatastream]; !ok {
				routers[idForDatastream] = MakeNewRouter()
			}
			routersMutex[idForDatastream].Unlock()

		} else if datastream[i] == "ip" {
			i++

			routersMutex[idForDatastream].Lock()
			router := routers[idForDatastream]
			router.PublicIP = string(datastream[i])

			err = sendMessage(conn, "Success")
			if err != nil {
				fmt.Println("Could not respond to router.")
			}
			routers[idForDatastream] = router
			routersMutex[idForDatastream].Unlock()

			fmt.Println("Updated Router IP to:", routers[idForDatastream].PublicIP)
			fmt.Println("------")

		} else if datastream[i] == "ip-mac" {
			routersMutex[idForDatastream].Lock()
			router := routers[idForDatastream]

			newArpItem := ARPItem{IP: string(datastream[i+1]), MAC: string(datastream[i+2])}
			router.PublicARPList[newArpItem.MAC] = newArpItem
			i += 2
			err := sendMessage(conn, "Success")
			if err != nil {
				fmt.Println("Could not respond to router.")
			}

			routers[idForDatastream] = router
			routersMutex[idForDatastream].Unlock()

			fmt.Println("Updated ARP List")
			fmt.Println("------")

		} else if datastream[i] == "devcon-reset" {
			routersMutex[idForDatastream].Lock()
			router := routers[idForDatastream]
			router.PublicConnectedDevicesList = make(map[string]ConnectedDevice)
			routers[idForDatastream] = router
			routersMutex[idForDatastream].Unlock()

			fmt.Println("Reset Devcon list.")
			fmt.Println("------")

		} else if datastream[i] == "devcon" {
			routersMutex[idForDatastream].Lock()
			router := routers[idForDatastream]

			isAlive, _ := strconv.ParseBool(string(datastream[i+4]))
			newConnectedDevice := ConnectedDevice{name: string(datastream[i+1]), ip: string(datastream[i+2]), mac: string(datastream[i+3]), isAlive: isAlive}
			router.PublicConnectedDevicesList[newConnectedDevice.mac] = newConnectedDevice

			i += 4
			err := sendMessage(conn, "Success")
			if err != nil {
				fmt.Println("Could not respond to router devcon")
			}

			routers[idForDatastream] = router
			routersMutex[idForDatastream].Unlock()

			fmt.Println("Updated Devcon List", routers[idForDatastream].PublicConnectedDevicesList)
			fmt.Println("------")

		} else if datastream[i] == "req" {
			sendNextCommand(conn)
			fmt.Println("Handled request.")
			fmt.Println("------")

		} else if datastream[i] == "packet" {
			handleIncomingPacket(datastream[i+1], conn, idForDatastream)
			// fmt.Println("Handled incoming packet")
			i++

		} else {
			fmt.Println("Unkown field:", len(datastream[i]), "\""+datastream[i][:5]+"\"")
			fmt.Printf("Field: ")
			for j := range datastream[i] {
				fmt.Printf("%02x-", datastream[i][j])
			}
			fmt.Printf("\n-----\n")
		}
	}

	// fmt.Println("------")

	conn.SetWriteDeadline(time.Now().Add(time.Second * 2))
	conn.Close()
}

func handleIncomingPacket(field Field, conn net.Conn, routerID string) {
	packetCount++
	if packetCount%1000 == 0 {
		fmt.Println(packetCount)
	}

	if len(field) >= 262144 {
		fmt.Println("Err. Received packet of size:", len(field))
		return
	}
	packet := gopacket.NewPacket([]byte(field), layers.LayerTypeEthernet, gopacket.Default)
	packetData := PacketData{data: []byte(field), timestamp: time.Now()}

	// Get addresss
	toAddr := ""
	if ipLayer := packet.Layer(layers.LayerTypeIPv6); ipLayer != nil {
		ip, _ := ipLayer.(*layers.IPv6)
		toAddr = ip.DstIP.String()

	} else if ipLayer := packet.Layer(layers.LayerTypeIPv4); ipLayer != nil {
		ip, _ := ipLayer.(*layers.IPv4)
		toAddr = ip.DstIP.String()

	} else {
		// If it is not an IP packet we aren't concerned about it right now
		err := sendMessage(conn, "Success")
		if err != nil {
			fmt.Println("Could not respond to router.")
		}

		writePacketToFile([]byte(field))
		return
	}

	err := sendMessage(conn, "Success")
	if err != nil {
		fmt.Println("Could not respond to router.")
	}

	// Add packet to our list of receivedPackets
	addPacketToReceivedPacketList(toAddr, packetData, routerID)

	if ethernetLayer := packet.Layer(layers.LayerTypeEthernet); ethernetLayer != nil {
		writePacketToFile([]byte(field))
	}

	testTCPFailure(packet, routerID)
}

func sendMessage(conn net.Conn, message string) error {
	// return sendMessageArray(conn, []string{message})
	newDs := Datastream{Field(message)}
	err := sendByteArray(conn, DatastreamToByteArray(newDs))
	return err
}

func sendByteArray(conn net.Conn, message []byte) error {
	_, err := conn.Write(message)
	return err
}
