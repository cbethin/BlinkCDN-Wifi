
CreateResponse = (status, data) => {
    var response = {}
    response["Response"] = status
    response["Data"] = data
    
    return response
};


module.exports = {CreateResponse}