package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"
)

// HTTPResponse is a generic response to an http request
type HTTPResponse struct {
	Response string      // success or fail
	Data     interface{} // if success, is data requested, if fail it is reason for failure
}

// ConnectedDeviceResponse structures information regarding a connected device
type ConnectedDeviceResponse struct {
	IP        string
	MAC       string
	Name      string
	IsAlive   bool
	IsEnabled bool
}

// DeviceTypeResponse structures information regarding a device's type
type DeviceTypeResponse struct {
	Maker      string
	DeviceType string
}

// BandwidthResponse structures information regarding a device's bandwidth
type BandwidthResponse struct {
	IP        string
	Bandwidth int
}

// TCPFailureResponse structures number of tcp failures for device
type TCPFailureResponse struct {
	IP       string
	Failures int
}

func startHTTPListening() {
	http.HandleFunc("/", handleHTTPResponse)
	if err := http.ListenAndServe(":8080", nil); err != nil {
		fmt.Println("Error setting up http connection.", err)
	}
}

func handleHTTPResponse(w http.ResponseWriter, r *http.Request) {
	fmt.Println(r.URL)

	id := "1234"
	if _, ok := routers[id]; !ok {
		response := HTTPResponse{Response: "fail", Data: "Router does not exist"}
		b, _ := json.Marshal(response)
		w.Write(b)
		return
	}

	if r.Method == "GET" {
		if r.URL.Path == "/publicapi/publicip" {
			response := HTTPResponse{Response: "success"}
			if len(routers[id].PublicIP) > 0 {
				response.Data = routers[id].PublicIP
			} else {
				response.Data = "Not found"
			}

			b, _ := json.Marshal(response)
			w.Write(b)
			return

		} else if r.URL.Path == "/publicapi/publiccondev" {
			connDevResponses := make([]ConnectedDeviceResponse, 0)

			for _, connDevItem := range routers[id].PublicConnectedDevicesList {
				connDevResponses = append(connDevResponses, ConnectedDeviceResponse{IP: connDevItem.ip, MAC: connDevItem.mac, Name: connDevItem.name, IsAlive: connDevItem.isAlive, IsEnabled: true})
			}

			response := HTTPResponse{Response: "success", Data: connDevResponses}
			b, _ := json.Marshal(response)
			w.Write(b)
			return

		} else if r.URL.Path == "/publicapi/setupwifi" {
			addCommandToStack(Command{name: "setupwifi", field: ""})

			didSendSuccessfully := <-commandStackChannel["setupwifi"]
			delete(commandStackChannel, "setupwifi")

			if didSendSuccessfully {
				w.Write([]byte("Success"))
			} else {
				w.Write([]byte("Fail"))
			}

		} else if r.URL.Path == "/publicapi/turnoffwifi" {
			addCommandToStack(Command{name: "turnoffwifi", field: ""})

			didSendSuccessfully := <-commandStackChannel["turnoffwifi"]
			delete(commandStackChannel, "turnoffwifi")

			if didSendSuccessfully {
				w.Write([]byte("Success"))
			} else {
				w.Write([]byte("Fail"))
			}
		} else if r.URL.Path == "/publicapi/setwifiStatus" {
			query := r.URL.Query()
			mac := query.Get("mac")
			status := query.Get("status")
			fmt.Println("Setting status: ", mac, status)

			if _, ok := routers[id].PublicConnectedDevicesList[mac]; !ok {
				w.Write([]byte("Fail."))
				return
			}

			router := routers[id]

			device := routers[id].PublicConnectedDevicesList[mac]
			if status == "off" {
				// Add device to list
				if indexOfDevice(device, router.BlacklistedDevices) == -1 {
					router.BlacklistedDevices = append(router.BlacklistedDevices, device)
				}

			} else if status == "on" {
				// Remove device from list
				index := indexOfDevice(device, router.BlacklistedDevices)
				if index != -1 {
					router.BlacklistedDevices = removeIndex(index, router.BlacklistedDevices)
				}
			}

			routers[id] = router

			blacklistedDevicesString := " "
			for i := range routers[id].BlacklistedDevices {
				blacklistedDevicesString += routers[id].BlacklistedDevices[i].mac + " "
			}

			fmt.Println("Blacklist:", routers[id].BlacklistedDevices)
			blacklistedMacAddresses := ""
			for i := range routers[id].BlacklistedDevices {
				blacklistedMacAddresses += routers[id].BlacklistedDevices[i].mac + " "
			}
			fmt.Println("Updating Blacklist: \"", blacklistedMacAddresses, "\"")
			command := Command{name: "updateblacklist", field: blacklistedMacAddresses}

			didSendSuccessfully := addCommandAndWaitToSendWithTimeout(command, 5000*time.Millisecond)

			if didSendSuccessfully {
				w.Write([]byte("Success"))
			} else {
				w.Write([]byte("Fail"))
			}
		} else if r.URL.Path == "/publicapi/bandwidths" {
			bandwidths := getBandwidthArray(id)

			bandwidthResponses := make([]BandwidthResponse, 0)
			for addr, bwidth := range bandwidths {
				bandwidthResponses = append(bandwidthResponses, BandwidthResponse{IP: addr, Bandwidth: bwidth})
			}

			response := HTTPResponse{Response: "success", Data: bandwidthResponses}
			b, _ := json.Marshal(response)
			w.Write(b)
			return

		} else if r.URL.Path == "/publicapi/numtcpfails" {
			retransmits := countTCPFailuresInTime(id, 3)

			tcpFails := make([]TCPFailureResponse, 0)
			for addr, fails := range retransmits {
				tcpFails = append(tcpFails, TCPFailureResponse{IP: addr, Failures: fails})
			}
			response := HTTPResponse{Response: "success", Data: tcpFails}
			b, _ := json.Marshal(response)
			w.Write(b)
			return

		} else if r.URL.Path == "/publicapi/doesrouterexist" {
			query := r.URL.Query()
			id := query["id"][0]
			response := HTTPResponse{Response: "success"}

			if _, ok := routers[id]; ok {
				response.Data = true
			} else {
				response.Data = false
			}

			b, _ := json.Marshal(response)
			w.Write(b)
			return

		} else if r.URL.Path == "/publicapi/getdevicetype" {
			query := r.URL.Query()
			mac := query["mac"][0]
			macLetters := strings.Split(mac, ":")

			firstThreePairs := macLetters[0] + macLetters[1] + macLetters[2]
			deviceType := DeviceTypeResponse{
				Maker:      lookupDeviceManufacturer(firstThreePairs),
				DeviceType: "idk",
			}

			response := HTTPResponse{Response: "success", Data: deviceType}
			b, err := json.Marshal(response)
			if err != nil {
				fmt.Println("Could not marshal device type response")
			}

			w.Write(b)
			return
		}
	}
}

func indexOfDevice(val ConnectedDevice, slice []ConnectedDevice) int {
	for i := range slice {
		if slice[i].mac == val.mac {
			return i
		}
	}

	return -1
}

func removeIndex(index int, slice []ConnectedDevice) []ConnectedDevice {
	return append(slice[:index], slice[index+1:]...)
}
