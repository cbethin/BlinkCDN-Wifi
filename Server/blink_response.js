
CreateResponse = (status, data) => {
    var response = {}
    response["Response"] = status
    response["Data"] = data
    
    return response
};

var Devices = {}

var Commands = {}
var lowprioAddrs = []
var medprioAddrs = []
var highprioAddrs = []

getPriorityForAddr = (addr) => {
    if (lowprioAddrs.includes(addr)) {
        return "low"
    }

    if (medprioAddrs.includes(addr)) {
        return "med"
    }

    if (highprioAddrs.includes(addr)) {
        return "high"
    }

    return "none"
}

generateSetPrioCommandString = () => {
    var output = "./scripts/resetprio.sh "

    if (lowprioAddrs.length > 0) {
        output += "&& /root/scripts/lowprio.sh 3mbit "
        for (i in lowprioAddrs) {
            output +=  lowprioAddrs[i] + " "
        }
    }

    if (medprioAddrs.length > 0) {
        output += "&& /root/scripts/medprio.sh 7mbit "
        for (i in medprioAddrs) {
            output +=  medprioAddrs[i] + " "
        }
    }

    if (highprioAddrs.length > 0) {
        output += "&& /root/scripts/highprio.sh 10mbit "
        for (i in highprioAddrs) {
            output +=  highprioAddrs[i] + " "
        }
    }

    return output
}

Commands.SetLowPriority = (addr) => {
    // Remove addr from  priorities
    lowprioAddrs = lowprioAddrs.filter((val, index, arr) => { return val != addr })
    medprioAddrs = medprioAddrs.filter((val, index, arr) => { return val != addr })
    highprioAddrs = highprioAddrs.filter((val, index, arr) => { return val != addr })

    // Add addr to right priority and output the command
    lowprioAddrs.push(addr)
    return generateSetPrioCommandString()
};

Commands.SetMedPriority = (addr) => {
    lowprioAddrs = lowprioAddrs.filter((val, index, arr) => { return val != addr })
    medprioAddrs = medprioAddrs.filter((val, index, arr) => { return val != addr })
    highprioAddrs = highprioAddrs.filter((val, index, arr) => { return val != addr })

    medprioAddrs.push(addr)
    return generateSetPrioCommandString()
};

Commands.SetHighPriority = (addr) => {
    lowprioAddrs = lowprioAddrs.filter((val, index, arr) => { return val != addr })
    medprioAddrs = medprioAddrs.filter((val, index, arr) => { return val != addr })
    highprioAddrs = highprioAddrs.filter((val, index, arr) => { return val != addr })

    highprioAddrs.push(addr)
    return generateSetPrioCommandString()
}

Commands.ResetPrio = () => {
    return "/root/scripts/resetprio.sh"
}


module.exports = {CreateResponse, Commands, getPriorityForAddr}