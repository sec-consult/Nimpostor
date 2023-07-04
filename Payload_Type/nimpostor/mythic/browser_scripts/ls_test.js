function(task, responses){
	const combined = responses.reduce( (prev, cur) => {
		return prev + cur;
	}, "");
	return {'plaintext': combined};
}
