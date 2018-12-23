const express = require('express')
const bodyParser = require('body-parser') // Setup HTTPS at some point
const blink = require('./blink_response')
var mysql = require('mysql')

// Setup Express
const app = express()
app.use(bodyParser.json())
const port = 8080

// Setup mysql
var con = mysql.createConnection({
    host: "localhost",
    user: "root",
    password: "enter1234"
})

var updates = {
    "Updates": {},
    "LastUpdatedAt": null
}

var customNames = {"38:71:de:b9:c7:fd": "Avery's iPhone"}

var commandsToIssue = []

// ROUTER HANDLING FUNCTIONS
app.post('/router_update', (req, res) => {
    console.log("Req:", req.body);
    if (req.body.hasOwnProperty("bandwidth")) {
        if (!updates.Updates.hasOwnProperty("bandwidth")) {
            updates.Updates["bandwidth"] = {}
        }

        for (var addr in req.body["bandwidth"]) {
            if (!updates.Updates["bandwidth"].hasOwnProperty(addr)) {
                updates.Updates["bandwidth"][addr] = {}
            }

            for (var timestamp in req.body["bandwidth"][addr]) {
                // console.log(timestamp)
                updates.Updates["bandwidth"][addr][timestamp] = req.body["bandwidth"][addr][timestamp]
            }
        }
    }

    if (req.body.hasOwnProperty("devices")) {
        updates.Updates["devices"] = req.body.devices
    }

    var date = new Date();
    updates.LastUpdatedAt = date.getTime();

    console.log(updates.Updates)
    console.log("-----");
    res.send(req.body);
})

var count = 0
app.post('/router_request', (req, res) => {
    console.log("REQ:", req.body);

    commandsObject = {}
    while(commandsToIssue.length > 0) {
        commandsObject["Command"+Object.keys(commandsObject).length.toString()] = commandsToIssue.shift();
    }

    res.send(blink.CreateResponse("Success", commandsObject))
    count += 1
})

// APP HANDLING FUNCTIONS
app.get('/publicapi/bandwidths', (req, res) => {
    var queries = req.query
    if (queries.hasOwnProperty('addr') && updates.Updates.hasOwnProperty("bandwidth") && updates.Updates.bandwidth.hasOwnProperty(queries['addr'])) {
        var addr = queries['addr']
        var times = Object.keys(updates.Updates.bandwidth[addr])
        var timesToSend = times.slice(times.length-10, times.length)

        var output = []
        for (var i in timesToSend) {
            var obj = {}
            obj["Time"] = timesToSend[i]

            if (updates.Updates.bandwidth[addr].hasOwnProperty(timesToSend[i]) && updates.Updates.bandwidth[addr][timesToSend[i]].hasOwnProperty("bandwidth")) {
                obj["bandwidth"] = updates.Updates.bandwidth[addr][timesToSend[i]]["bandwidth"]
                output.push(obj)
            }
        }

        res.send(blink.CreateResponse("Success", output))
        return
    }

    res.send(blink.CreateResponse("Fail", null))
})

app.get('/publicapi/publiccondev', (_, res) => {
    if (updates.Updates.hasOwnProperty("devices")) {
        for (i in updates.Updates.devices) {
            updates.Updates.devices[i].priority = blink.getPriorityForAddr(updates.Updates.devices[i].ip)
            if (customNames[updates.Updates.devices[i].mac] != undefined) {
                updates.Updates.devices[i].name = customNames[updates.Updates.devices[i].mac]
            }
        }

        res.send(blink.CreateResponse("Success", updates.Updates.devices))
    } else {
        res.send(blink.CreateResponse("Fail", null))
    }
})

app.get('/publicapi/lastrouterupdatetime', (_, res) => {
    res.send(res.send(blink.CreateResponse("Success", updates.LastUpdatedAt)))
})

app.get('/publicapi/postcommand', (req, res) => {
    var queries = req.query;
    if (queries["type"] == "setprio") {
        let priority = queries["prio"]
        switch(priority) {
        case "low":
            commandsToIssue.push(blink.Commands.SetLowPriority(queries["addr"]))
            break;
        case "med":
            commandsToIssue.push(blink.Commands.SetMedPriority(queries["addr"]))
            break;
        case "high":
            commandsToIssue.push(blink.Commands.SetHighPriority(queries["addr"]))
            break;
        }

        res.send(blink.CreateResponse("Success", null))
        console.log(commandsToIssue)
        return
    } else if (queries["type"] == "resetprio") {
        commandsToIssue.push(blink.Commands.ResetPrio())
        res.send(blink.CreateResponse("Success", null))
        return
    }

    

    res.send(blink.CreateResponse("Fail", "No command found."))
})


// OTHER NONSENSE
app.get('/', (req, res) => {
    res.send('Hello world!')
})

app.listen(port, () => {
    console.log(`Setup server on port ${port}.`)
})