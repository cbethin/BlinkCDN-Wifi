#pragma once
#include <string>
#include "tins/tins.h"
#include "datastream.hh"
#include "router.hh"

class PacketCap {
private: 
    Tins::Sniffer sniffer;
    Router *router;
    std::string destinationAddr;
    int destPort;
    int packetCount;

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
            for (auto i = buffer.begin(); i != buffer.end() /*&& packetSize <= n+1*/; i++) {
                packetBuffer.append((unsigned char) *i);
                packetSize++;
            }

            // Add a null char cuz we're expecting null terminated strings? (well we used to i think)
            packetBuffer.append((unsigned char) '\00');
            packetSize++;

            Buffer outbuf;
            outbuf.append(Buffer(Field("id")));
            outbuf.append(Buffer(Field(router->getId())));

            outbuf.append(Buffer(Field("packet")));
            outbuf.append(Buffer(packetSize));
            outbuf.append(packetBuffer);

            delete[] buf;
            return outbuf;
    }

    bool callback(Tins::PDU &pdu) {

        int headerSize = 0;
        try {
            const Tins::IP &ip = pdu.rfind_pdu<Tins::IP>();
            const Tins::TCP &tcp = pdu.rfind_pdu<Tins::TCP>();
            
            // Filter out other
            headerSize += 14 + ip.header_size() + tcp.header_size(); // 14 = ethernet header size

            // Skip if the packet is being sent to our processing server
            if (ip.dst_addr().to_string() == destinationAddr && ip.src_addr().to_string() == "192.168.8.1") {
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
        // cout << someCount << endl;
        return true;
    }

public:
    PacketCap(const std::string& interface, Router *router, const std::string& destinationAddr, int destPort): sniffer(interface), router(router), destinationAddr(destinationAddr), destPort(destPort), packetCount(0) { 
        // sniffer = Tins::Sniffer(interface);
    }

    void processNextPacket() {
            Tins::PDU *pdu = sniffer.next_packet();
            callback(*pdu);
    }
};