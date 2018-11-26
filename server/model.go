package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"strings"
	"sync"
	"time"
)

// PacketData : structure containing a packet's information
type PacketData struct {
	data      []byte
	timestamp time.Time
}

// ConnectedDevice : struct containing information about a device connected to the router
type ConnectedDevice struct {
	name    string
	ip      string
	mac     string
	isAlive bool
}

// ARPItem : struct containing info about an ARP table item
type ARPItem struct {
	IP  string
	MAC string
}

// RouterData : a struct containing all data structures related to router's information
type RouterData struct {
	PublicIP                   string
	PublicARPList              map[string]ARPItem
	PublicConnectedDevicesList map[string]ConnectedDevice
	BlacklistedDevices         []ConnectedDevice
	ReceivedPackets            map[string][]PacketData
	TCPPackets                 map[string][]TCPData
	TCPRetransmissions         []TCPData
}

var routers = make(map[string]RouterData)
var routersMutex = make(map[string]*sync.Mutex)

var pcapWriteMutex = &sync.Mutex{}

var ouiLookup map[string]string

// MakeNewRouter : Initializes a router data object
func MakeNewRouter() RouterData {
	data := RouterData{}

	data.PublicARPList = make(map[string]ARPItem)
	data.PublicConnectedDevicesList = make(map[string]ConnectedDevice)
	data.BlacklistedDevices = make([]ConnectedDevice, 0)
	data.ReceivedPackets = make(map[string][]PacketData)
	data.TCPPackets = make(map[string][]TCPData)
	data.TCPRetransmissions = make([]TCPData, 0)

	return data
}

// arpItemToJSON converts a structure of type arpItem to a JSON object
func arpItemToJSON(a ARPItem) string {
	b, err := json.Marshal(&a)
	if err != nil {
		fmt.Println(err)
	}

	return string(b)
}

// Given the destination IP address, this function will add the packet to the list of packets received
// receivedPacket is used to keep track of those packets received in the last 5 seconds, to be used
// for things like bandwidth calculation
func addPacketToReceivedPacketList(ipAddr string, packet PacketData, routerID string) {
	removeOldPacketsFromPacketList(ipAddr, routerID)

	routersMutex[routerID].Lock()
	router := routers[routerID]

	if _, ok := router.ReceivedPackets[ipAddr]; !ok {
		router.ReceivedPackets[ipAddr] = make([]PacketData, 0)
	}

	router.ReceivedPackets[ipAddr] = append(router.ReceivedPackets[ipAddr], packet)
	routers[routerID] = router
	// fmt.Printf("Packets for: ")
	// for key, _ := range routers[routerID].ReceivedPackets {
	// 	fmt.Printf("%s ", key)
	// }
	// fmt.Printf("\n")
	// fmt.Println("Final:", router.ReceivedPackets)
	routersMutex[routerID].Unlock()
}

// removeOldPacketsFromPacketList updates the recieved packet list for a given ip address
// asuures that every packet in the window has been received in the past 5 seconds
func removeOldPacketsFromPacketList(ipAddr string, routerID string) {
	routersMutex[routerID].Lock()
	router := routers[routerID]

	if pktList, ok := router.ReceivedPackets[ipAddr]; ok {
		// Updated packet list to be added to map
		updatedPacketList := make([]PacketData, 0)

		// For every packet in the list, only keep it in the updated list
		// if it is less than 5 seconds old
		for i := range pktList {
			if time.Since(pktList[i].timestamp) <= 5*time.Second {
				updatedPacketList = append(updatedPacketList, pktList[i])
			}
		}

		// Set updated packet list as the default
		router.ReceivedPackets[ipAddr] = updatedPacketList
	}

	routers[routerID] = router
	routersMutex[routerID].Unlock()
}

// loadOUILookupDataset loads the OUI lookup table into memory for future usage
func loadOUILookupDataset() {
	filename := "files/convertcsv.json"
	jsonFile, err := os.Open(filename)
	defer jsonFile.Close()
	if err != nil {
		fmt.Println("Error opening OUI Lookup file:", err)
	}

	jsonBytes, _ := ioutil.ReadAll(jsonFile)
	json.Unmarshal(jsonBytes, &ouiLookup)
}

func lookupDeviceManufacturer(mac string) string {
	fmt.Println("Looking up:", strings.ToUpper(mac))
	return ouiLookup[strings.ToUpper(mac)]
}
