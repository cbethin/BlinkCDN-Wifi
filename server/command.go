package main

import (
	"fmt"
	"net"
	"time"
)

// Command : A command for the router. Involes the command name and any necessary fields
type Command struct {
	name  string
	field string
}

var waitForCommandCompletion chan bool

var commandStackChannel map[string]chan bool
var commandStack []Command

func addCommandToStack(command Command) {
	commandStack = append(commandStack, command)
	commandStackChannel[command.name] = make(chan bool)
}

func sendNextCommand(conn net.Conn) {
	if len(commandStack) > 0 {

		// Convert command to datastream and send it out
		err := sendDatastream(conn, commandToDatastream(commandStack[0]))

		// On failure
		if err != nil {
			fmt.Println("Error responding to server.")
			commandStackChannel[commandStack[0].name] <- false
			commandStack = commandStack[1:]
		}

		// On success
		commandStackChannel[commandStack[0].name] <- true
		commandStack = commandStack[1:]
	} else {
		err := sendMessage(conn, "None")
		if err != nil {
			fmt.Println("Error sending null request resp:", err)
		}
	}
}

func commandToDatastream(command Command) Datastream {
	newDs := Datastream{Field(command.name)}

	if command.field != "" {
		newDs = append(newDs, Field(command.field))
	}

	return newDs
}

func addCommandAndWaitToSend(command Command) bool {
	addCommandToStack(command)
	timerCompletion := make(chan bool)
	go func() {
		time.Sleep(5 * time.Second)
		timerCompletion <- true
	}()

	select {
	case <-timerCompletion:
		return false
	case res := <-commandStackChannel[command.name]:
		delete(commandStackChannel, command.name)
		return res
	}
}

func addCommandAndWaitToSendWithTimeout(command Command, timeout time.Duration) bool {
	addCommandToStack(command)
	timerCompletion := make(chan bool)
	go func() {
		time.Sleep(timeout)
		timerCompletion <- true
	}()

	select {
	case <-timerCompletion:
		return false
	case res := <-commandStackChannel[command.name]:
		delete(commandStackChannel, command.name)
		return res
	}
}
