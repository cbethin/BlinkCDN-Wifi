
#pragma once
#include <string>
#include <map>
#include <fstream>
#include <sstream>
#include <time.h>

class Device {
private:
    std::string name, mac, ip;
    bool isAlive = false;
    clock_t lastAliveAt = 0;
public:
    Device(std::string name="", std::string mac="", std::string ip="") : name(name), mac(mac), ip(ip) { }
    std::string getName() { return name; }
    std::string getMac() { return mac; }
    std::string getIP() { return ip; }
    bool getIsAlive() { return isAlive; }
    clock_t getLastAliveAt() { return lastAliveAt; }
    void setLastAliveAt(clock_t time) { lastAliveAt = time; }

    friend std::ostream& operator <<(std::ostream& s, Device d) {
        return s << "Device: {" << d.name << ", " << d.mac << ", " << d.ip << "}";
    }

    void updateIsAliveStatus() {
        // If the device has been pinged in the last 30 seconds, the device is active
        double timeSinceActiveInSeconds = double(clock() - lastAliveAt) / CLOCKS_PER_SEC;
        if (timeSinceActiveInSeconds < 10 && lastAliveAt != 0) {
            isAlive = true;
        } else {
            isAlive = false;
        }
    }
};

class Router {
private:
    // std::vector<Device> devices;
    std::map<std::string, Device> devices;
    std::vector<std::string> activeIPList;
    std::string publicIP;
    std::string id;

    std::string GetStdoutFromCommand(const std::string& cmd) {
        system((cmd+"> output").c_str());
        std::ifstream file("output");
        std::string output = "";

        while (!file.eof()) {
            std::string linebuf;
            std::getline(file, linebuf);
            output += linebuf;
        }

        system("rm output");
        return output;
    }

public:
    Router(): id("1234") {
    }

    std::string getId() { return id; }

    std::string updatePublicIP() {
        publicIP = GetStdoutFromCommand("curl ipinfo.io/ip");
        return publicIP;
    }

    std::map<std::string, Device> getDevices() { 
        for (auto i = devices.begin(); i != devices.end(); i++) {
            i->second.updateIsAliveStatus();
        }

        return devices; 
    }

    void updateDevicesList() {
        system("cat /tmp/dhcp.leases > dhcpDevices");
        std::ifstream file("dhcpDevices");

        while (!file.eof()) {
            std::string linebuf;
            getline(file, linebuf);
            std::istringstream line(linebuf);

            std::string field1, mac, ip, name, field2;
            line >> field1 >> mac >> ip >> name >> field2;
            if (mac != "") 
                devices[mac] = Device(name, mac, ip);
        }

        system("rm dhcpDevices");
    }

    std::vector<std::string> updateActiveIPList() {
        system("fping -a -q -g 192.168.8.0/24 -i 1 -r 2 1> IPList 2> IPError");
        std::ifstream file("IPList");
        std::vector<std::string> IPList;

        while (!file.eof()) {
            std::string linebuf;
            getline(file, linebuf);
            std::istringstream line(linebuf);
            
            std::string ip;
            line >> ip;
            IPList.push_back(ip);
        }

        for (auto i = IPList.begin(); i != IPList.end(); i++) {
            for (auto j = devices.begin(); j != devices.end(); j++) {
                if (*i == j->second.getIP()) {
                    j->second.setLastAliveAt(clock());
                }
            }
        }
        
        activeIPList = IPList;
        system("rm IPList IPError");
        return IPList;
    }

};