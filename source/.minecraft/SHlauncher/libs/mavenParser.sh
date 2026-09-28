function mavenParser() {
	local is=$1 # is for "input string"
	log "DEBUG" "init.sh:mavenParser" "mavenParser called with $is"
	if [ "$is" == "" ]; then
		printf "${YELLOW_BOLD}[BUG] function mavenParser require 1 entry argument but none were ever passed! Check the log file for more info${RESET}\n"
		log "ERROR" "init.sh:mavenParser" "BUG : Some argument are missing. Expected argument: is \"$is\""
		return 2
	fi

	is="${is//'['/}" # remove the squares brackets
	is="${is//']'/}"

	local ext="${is##*@}"
	if [[ "$is" == "$ext" ]]; then
		ext="jar" # if the extension is unspecified, then it's a jar file
	else
		is="${is%@*}" # else it's whatever the extension is
	fi

	IFS=':' read -ra parts <<< "$is"
	local group="${parts[0]}"
	local artifact="${parts[1]}"
	local version="${parts[2]}"

	if [ "${#parts[@]}" -ge 4 ]; then
		local classifier="${parts[3]}"
	else
		local classifier=""
	fi

	local groupPath="${group//./\/}" # replace dots with forward slashes 
	local filename="${artifact}-${version}" # build the filename
	if [[ -n "$classifier" ]]; then
		filename+="-$classifier"
	fi
	filename+=".$ext"

	local path="$groupPath/$artifact/$version/$filename" # build the final path
	log "DEBUG" "init.sh:mavenParser" "resolved $is to $path"
	printf '%s' "${path%$'\r'}"
}