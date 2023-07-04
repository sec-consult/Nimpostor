function(task, responses){
	if(responses.length > 0){
	    return {"plaintext": responses[0]}
	}
	else{
	    //this means we shouldn't have any output
	    return {"plaintext": "No response yet from agent..."}
	}
}
