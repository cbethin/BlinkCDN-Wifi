#pragma once
#include <string>
#include <map>
#include <vector> 

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

    // map<std::string, std::vector<Tins::PDU>> packetList;
    int addFieldToByteArray(const Field& field, uint8_t* const bytes, int startIndex) {
        int intByteArraySize = 4;
        int j = startIndex;

        // Add int array to bytes 
        for (int i = 0; i < intByteArraySize; i++, j++) {
            bytes[j] = (uint8_t)((uint32_t(field.length()) >> (8 * (intByteArraySize-1-i))) & 0xff);
        }

        // add field to bytes 
        for (int i = 0; i < field.length(); i++, j++) {
            bytes[j] = field[i];
        }

        return j;
    }


    int pduToByteArray(Tins::PDU &pdu, uint8_t *bytes) {

            Tins::PDU::serialization_type packetBuffer;
            try {
                packetBuffer = pdu.serialize();
            } catch (Tins::serialization_error err) {
                std::cout << "Error serializing packet.\n";
                return -1;
            }

            int packetSize = packetBuffer.size(); // packetsize

            // Manually add packet 
            int totalBytesSize = 4 + std::string("id").length() + 4 + router->getId().length() + 4 + std::string("packet").length() + packetSize + 1;
            bytes = new uint8_t[totalBytesSize+4];

            // Add total byte size array to bytes 
            for (int i = 0; i < 4; i++) {
                bytes[i] = (uint8_t)((uint32_t(totalBytesSize) >> (8 * (3-i))) & 0xff);
            }

            // Add fields to bytes
            int nextUnusedIndex = addFieldToByteArray("id", bytes, 4);
            nextUnusedIndex = addFieldToByteArray(router->getId(), bytes, nextUnusedIndex);
            nextUnusedIndex = addFieldToByteArray("packet", bytes, nextUnusedIndex);
            
            // Add packet to bytes
            for (int i = 0; i < packetSize; i++, nextUnusedIndex++) {
                bytes[nextUnusedIndex] = packetBuffer[i];
            }
            bytes[nextUnusedIndex] = '\00';

            std::cout << "PACKET: ";
            for (int i = 0; i < totalBytesSize; i++) {
                std::cout << std::hex << (char)bytes[i] << "-";
            }
            std::cout << "\n";

            return totalBytesSize+4+1;
    }

    bool callback(Tins::PDU &pdu) {
        std::string pktDestination;

        int headerSize = 0;
        try {
            const Tins::IP &ip = pdu.rfind_pdu<Tins::IP>();
            const Tins::TCP &tcp = pdu.rfind_pdu<Tins::TCP>();
            
            // Filter out other
            headerSize += 14 + ip.header_size() + tcp.header_size(); // 14 = ethernet header size

            // Skip if the packet is being sent to our processing server
            pktDestination = ip.dst_addr().to_string();
            if (ip.dst_addr().to_string() == destinationAddr) {
                return true;
            }
        } catch (Tins::pdu_not_found err) {
            // Catch PDU_not_found error if there's no IP
        }

        if (headerSize == 0) {
            headerSize = 15000;
        }

        // Buffer outbuf = pduToBuffer(pdu, headerSize);
        uint8_t *bytes; 
        int size = pduToByteArray(pdu, bytes);

        Datastream::sendToAddress(bytes, size, destinationAddr, destPort);
        delete[] bytes;

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