#pragma once
#include <string>
#include <map>
#include <vector> 
#include <chrono>
#include <thread>
#include <mutex>

#include "tins/tins.h"
#include "external/json.hpp"
using JSON = nlohmann::json;

#include "models.hh"

using TimeBandwidthMap = std::map<long, double>;

class PacketCap {
private: 
    Tins::Sniffer sniffer;
    int packetCount;
     std::map<std::string, TimeBandwidthMap> bandwidthCounter;
    JSON bandwidthJson;
    JSON windowSizeJson;
    std::thread captureThread;
    std::mutex bwidthMutex;

    void trackTCPWindowSizeForPacket(const Tins::TCP *tcp) {
        // double windowSize = tcp->window();
        // std::cout << windowSize << std::endl;
    }

    void trackBandwidthForPacket(const Tins::IP *ip) {
        std::string addr = ip->dst_addr().to_string();
        if (addr.find("192.168.") == std::string::npos || addr.find(".255") != std::string::npos) {
            return;
        }

        double packetLen = ip->tot_len();
        
        auto currentTime = std::chrono::system_clock::now();
        long nearestSecond = std::chrono::time_point_cast<std::chrono::seconds>(currentTime).time_since_epoch().count();
        std::string nearestSecondString = std::to_string(nearestSecond);

        // If this addr is not in the bandwidthJson, insert it
        bwidthMutex.lock();
        if (bandwidthJson[addr] == nullptr) {
            bandwidthJson[addr] = JSON();
        }

        // If this second isnt' in the addresses map then add it in 
        auto &bandwidthsForAddr = bandwidthCounter.find(addr)->second;
        if (bandwidthJson[addr][nearestSecondString] == nullptr) {
            bandwidthJson[addr][nearestSecondString] = JSON();
            bandwidthJson[addr][nearestSecondString]["bandwidth"] = 0;
        }

        // Add the packet length to this second's time result
        JSON::number_integer_t& bwidthToUpdate = bandwidthJson[addr][nearestSecondString]["bandwidth"].get_ref<JSON::number_integer_t&>();
        bwidthToUpdate += packetLen;  
        bwidthMutex.unlock();
    }

    bool callback(Tins::PDU &pdu) {

        int headerSize = 0;
        try {
            const Tins::IP &ip = pdu.rfind_pdu<Tins::IP>();
            const Tins::TCP &tcp = pdu.rfind_pdu<Tins::TCP>();
            trackBandwidthForPacket(&ip);
            trackTCPWindowSizeForPacket(&tcp);

        } catch (Tins::pdu_not_found err) {
            // Catch PDU_not_found error if there's no IP
        }

        return true;
    }

public:
    PacketCap(const std::string& interface): sniffer(interface), packetCount(0) { }

    void processNextPacket() {
            Tins::PDU *pdu = sniffer.next_packet();
            callback(*pdu);
    }

    void processPackets() {
        while(true) {
            Tins::PDU *pdu = sniffer.next_packet();
            callback(*pdu);
        }
    }

    void processPacketsAsThread() {
        captureThread = std::thread([this] { this->processPackets(); });
        return;
    }

    void stopThread() {
        if (captureThread.joinable())
            captureThread.join();
    }

    JSON pullAndClearBandwidthJson() {
        JSON bwidths = bandwidthJson;
        bandwidthJson = JSON();
        return bwidths;
    }

    std::string bwidthMapToJson() {
        std::string dump = bandwidthJson.dump();
        if (dump == "null") {
            return "{ }";
        }
        for (JSON::iterator i = bandwidthJson.begin(); i != bandwidthJson.end(); i++) {
            *i = JSON();
        }

        return dump;
    }
};