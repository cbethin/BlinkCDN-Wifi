package main

import (
	"encoding/binary"
	"fmt"
	"net"
	"strings"
)

// Data : Contains size of a data field and the data itself
// type Data struct {
// 	size int
// 	data string
// }

// Field : a field of a datastream (just a string really)
type Field string

// Datastream : Array of Data objects
type Datastream []Field

// ExtractDatastreamFromBuffer : Given a byte array, extract the data list
func ExtractDatastreamFromBuffer(buf []byte) Datastream {
	// Convert data into array of data structures
	var datastream Datastream
	n := 0
	nFields := int(binary.BigEndian.Uint32(buf[n : n+4]))
	n += 4

	for i := 0; i < nFields; i++ {
		dataSize := int(binary.BigEndian.Uint32(buf[n : n+4]))

		if dataSize == 0 {
			return datastream
		} else if (n + 4 + dataSize) > len(buf) {
			fmt.Println("Data out of bounds.", n, buf[n:n+4], dataSize, len(buf))
			break
		}

		iDataStart := n + 4

		field := Field(string(buf[iDataStart : iDataStart+dataSize]))
		field = Field(strings.TrimSuffix(string(field), "\x00"))
		field = Field(strings.TrimSuffix(string(field), "\n"))
		datastream = append(datastream, field)
		n += (4 + dataSize)
	}

	return datastream
}

// DatastreamToByteArray : converts a Datastream object to a byte array
func DatastreamToByteArray(datastream Datastream) []byte {
	output := make([]byte, 0)

	// Convert each field to a byte array encoded with it's size
	dataByteArray := make([]byte, 0)
	for i := range datastream {
		dataByteArray = append(dataByteArray, encodeFieldWithSize(datastream[i])...)
	}

	// Append number of fields to beginning of output
	nFieldsByteArray := make([]byte, 4)
	binary.BigEndian.PutUint32(nFieldsByteArray, uint32(len(datastream)))

	// Then add the rest of the fields as their byte array
	output = append(nFieldsByteArray, dataByteArray...)
	return output
}

func sendDatastream(conn net.Conn, datastream Datastream) error {
	_, err := conn.Write(DatastreamToByteArray(datastream))
	return err
}

func encodeFieldWithSize(message Field) []byte {
	size := make([]byte, 4)
	binary.BigEndian.PutUint32(size, uint32(len([]byte(message))))
	return append(size, []byte(message)...)
}

func fieldListToStringList(fields []Field) []string {
	output := make([]string, 0)
	for i := range fields {
		output = append(output, string(fields[i]))
	}

	return output
}

func stringListToFieldList(strings []string) []Field {
	output := make([]Field, 0)
	for i := range strings {
		output = append(output, Field(strings[i]))
	}

	return output
}
