
#include <iostream>
#include <unistd.h>
#include <vector>
#include <time.h>
#include "tins/tins.h"
#include "router.hh"
#include "pthread.h"
#include <chrono>

#include "datastream.hh"
#include "packetcap.hh"

using namespace std;

string destinationAddr;
int destPort;
Router r;

int main(int argc, const char *argv[]) {
    Datastream d;
    destinationAddr = (argc>1) ? argv[1] : "127.0.0.1";
    destPort = 9000;

    PacketCap packetCap("en0", &r, destinationAddr, destPort);
    // Tins::Sniffer sniffer("en0");

    int packetCount = 0;

    chrono::time_point<std::chrono::system_clock> thisTime, nextTime;
    thisTime = chrono::system_clock::now();
    nextTime = thisTime;

    while(1) {
        if (thisTime >= nextTime) {
            d.pushNamedField("id", r.getId());
            cout << "ID:" << r.getId() << endl;

            cout << "Getting info\n";
            string routerIP = r.updatePublicIP();
            d.pushNamedField("ip", routerIP);

            r.updateDevicesList();

            vector<string> ipList = r.updateActiveIPList();
            cout << "Active IP's: ";
            for (auto i = ipList.begin(); i != ipList.end(); i++) {
                cout << *i << " ";
            }
            cout << endl;

            map<string, Device> devices = r.getDevices();
            d.pushField("devcon-reset");
            for(auto i = devices.begin(); i != devices.end(); i++) {
                d.pushField("devcon");
                d.pushField(i->second.getName());
                d.pushField(i->second.getIP());
                d.pushField(i->second.getMac());
                d.pushField(i->second.getIsAlive() ? "true" : "false"); // Add whether the device is alive
            }

            Datastream response = d.sendTo(destinationAddr, destPort);
            cout << "Response: " << response << endl;
            d.clear();
            usleep(200000);

            d.pushNamedField("id", r.getId());
            d.pushField("req");
            response = d.sendTo(destinationAddr, destPort);
            cout << "Response to Req: " << response << endl;
            d.clear();
            usleep(200000);

            nextTime += chrono::seconds(30);

        } else {
            // Tins::PDU *pdu = sniffer.next_packet();
            // callback(*pdu);
            // packetCount++;
            packetCap.processNextPacket();
        }
        
        thisTime = chrono::system_clock::now();
    }

    // cout << "Devices updated: " << r.getDevices() << endl;

    return 0;
}