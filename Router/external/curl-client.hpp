#pragma once
#include <iostream>
#include <curl/curl.h>

class HttpClient {
private: 
    std::string addr;
    std::string response;
public:
    HttpClient(std::string addr) : addr(addr) { }

    size_t selfWriteResponse(void *buffer, size_t size, size_t nmemb) {
        size_t realsize = size * nmemb;
        response = std::string((char *) buffer, realsize);
        return realsize;
    }
 
    static size_t writeResponse(void *buffer, size_t size, size_t nmemb, void *userp) {
        return ((HttpClient*)userp)->selfWriteResponse(buffer, size, nmemb);
    }

    void sendData(std::string data) {
        CURL *curl;
        CURLcode res;

        curl = curl_easy_init();
        if (curl) {
            struct curl_slist *headers = nullptr;
            // headers = curl_slist_append(headers, "Expect:");
            headers = curl_slist_append(headers, "Content-Type: application/json");
            curl_easy_setopt(curl, CURLOPT_URL, addr.c_str());
            curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
            curl_easy_setopt(curl, CURLOPT_POSTFIELDS, data.c_str());
            curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, -1L);
            curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, writeResponse);
            curl_easy_setopt(curl, CURLOPT_WRITEDATA, this);
            
            res = curl_easy_perform(curl);
            if (res != CURLE_OK) {
                std::cout << "Error: " << curl_easy_strerror(res) << std::endl;
            }

            curl_easy_cleanup(curl);
        }
    }

    std::string getResponse() { return response; }
};