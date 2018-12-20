#include <tins/tins.h>
#include <iostream>
#include <thread>
#include <unistd.h>
#include "external/curl-client.hpp"

#include "models.hh"
#include "packetcap.hh"

using namespace std;

int main(int argc, char*argv[]) {
    // Setup router
    Router r;
    string destAddr = (argc>1) ? argv[1] : "127.0.0.1:8080";
    HttpClient client("http://" + destAddr + "/router_update");
    HttpClient requestClient("http://" + destAddr + "/router_request");

    // Start capturing packets
    PacketCap packetProcessor((argc >2) ? argv[2] : "en0");
    packetProcessor.processPacketsAsThread();

    auto thisTime = std::chrono::system_clock::now();
    chrono::system_clock::time_point nextTime = thisTime;
    while(true) {
        if (thisTime > nextTime) {
            // Update server
            JSON output;
            output["bandwidth"] = packetProcessor.pullAndClearBandwidthJson();
            r.updateDevicesList();
            r.updateActiveIPList();
            output["devices"] = r.getDevicesAsJsonArray();

            client.sendData(output.dump());
            nextTime += std::chrono::milliseconds(1000);

            JSON j;
            j["Data"] = "request";
            requestClient.sendData("");
            r.handleResponseToRequest(requestClient.getResponse());
        }

        thisTime = std::chrono::system_clock::now();
        sleep(1);
    }
}