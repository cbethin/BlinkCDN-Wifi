
#include <iostream>
#include <unistd.h>
#include <vector>
#include <time.h>
#include "datastream.hh"
#include "tins/tins.h"
#include "router.hh"
#include "pthread.h"
#include <chrono>

using namespace std;

string destinationAddr;
int destPort;
Router r;

Buffer pduToBuffer(Tins::PDU &pdu, int n) {
        Buffer packetBuffer;
        uint8_t *buf = new uint8_t[2000];

        Tins::PDU::serialization_type buffer;
        try {
            buffer = pdu.serialize();
        } catch (Tins::serialization_error err) {
            std::cout << "Error serializing packet.\n";
            return Buffer();
        }

        int packetSize = 0;
        for (auto i = buffer.begin(); i != buffer.end() && packetSize <= n+1; i++) {
            packetBuffer.append((unsigned char) *i);
            packetSize++;
        }

        // Add a null char cuz we're expecting null terminated strings? (well we used to i think)
        packetBuffer.append((unsigned char) '\00');
        packetSize++;

        Buffer outbuf;
        outbuf.append(Buffer(Field("id")));
        outbuf.append(Buffer(Field(r.getId())));

        outbuf.append(Buffer(Field("packet")));
        outbuf.append(Buffer(packetSize));
        outbuf.append(packetBuffer);

        delete[] buf;
        return outbuf;
}

int someCount = 0;

bool callback(Tins::PDU &pdu) {

    int headerSize = 0;
    try {
        const Tins::IP &ip = pdu.rfind_pdu<Tins::IP>();
        const Tins::TCP &tcp = pdu.rfind_pdu<Tins::TCP>();
        
        // Filter out other
        headerSize += 14 + ip.header_size() + tcp.header_size(); // 14 = ethernet header size

        // Skip if the packet is being sent to our processing server
        if (ip.dst_addr().to_string() == destinationAddr) {
            return true;
        }
    } catch (Tins::pdu_not_found err) {
        // Catch PDU_not_found error if there's no IP
    }

    if (headerSize == 0) {
        headerSize = 15000;
    }

    Buffer outbuf = pduToBuffer(pdu, headerSize);
    if (outbuf.size() <= 0) {
        return true;
    }

    

    Datastream::sendToAddress(outbuf, destinationAddr, destPort);

    usleep(500);
    someCount++;
    cout << someCount << endl;
    return true;
}

int main(int argc, const char *argv[]) {
    Datastream d;
    destinationAddr = (argc>1) ? argv[1] : "127.0.0.1";
    destPort = 9000;

    Tins::Sniffer sniffer("br-lan");
    // Tins::Sniffer sniffer("en0");

    clock_t this_time = clock();
    clock_t next_time = this_time;

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

            nextTime += chrono::seconds(15);

        } else {
            Tins::PDU *pdu = sniffer.next_packet();
            callback(*pdu);
            packetCount++;
        }
        
        thisTime = chrono::system_clock::now();
    }

    // cout << "Devices updated: " << r.getDevices() << endl;

    return 0;
}