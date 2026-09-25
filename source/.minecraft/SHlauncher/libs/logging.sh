exec 3>&1 # create file descriptor 3 (used to capture stderr only in exceptionCatch)

function log() {
	local level=$1
	local source=$2
	shift 2
	local msg="$*"
	case "" in # check if any arguments is empty, throws an error if yes
		"$level" | "$source")
			printf "${YELLOW_BOLD}[BUG]${YELLOW} Function log require 2 arguments but some are missing! Check the log file for more info${RESET}\n"
			log "ERROR" "init.sh:log" "BUG : Some argument are missing. Expected argument: level \"$level\", source \"$source\""
			return 2
		;;
		*)
			true
	esac

	touch "$SHlogFile"
	# write DEBUG lines only if debug mode is enabled
	if [ "$level" != "DEBUG" ]; then
		printf '[%(%F %T)T] [%s/%s] %s\n' -1 "$level" "$source" "$msg" >> "$SHlogFile"
	elif $debug; then
		printf '[%(%F %T)T] [%s/%s] %s\n' -1 "$level" "$source" "$msg" >> "$SHlogFile"
	fi

	if $verbose || $trace; then
		case $level in
		"INFO")
			printf "${GREEN_BOLD}[%s/%s]"$'\033[0m'"${GREEN} %s\n${RESET}" "$level" "$source" "$msg" >&2
		;;
		"WARN")
			printf "${YELLOW_BOLD}[%s/%s]${RESET}${YELLOW} %s\n${RESET}" "$level" "$source" "$msg" >&2
		;;
		"ERROR")
			printf "${RED_BOLD}[%s/%s]${RESET}${RED} %s\n${RESET}" "$level" "$source" "$msg" >&2
		;;
		"FATAL")
			printf "${RED_BOLD}[%s/%s] %s\n${RESET}" "$level" "$source" "$msg" >&2
		;;
		"DEBUG")
			$debug && printf "${CYAN_BOLD}[%s/%s]${RESET}${CYAN} %s\n${RESET}" "$level" "$source" "$msg" >&2
		;;
		*)
			printf "${WHITE_BOLD}[%s/%s]${RESET}${WHITE} %s\n${RESET}" "$level" "$source" "$msg" >&2
		esac
	fi
}

function exceptionCatch(){
	local source=$1 # requester script (used for logging). Other arguments are the content the command to execute
	shift
	if [[ -z $source || $# -eq 0 ]]; then
		printf '%b\n' "${YELLOW_BOLD}[BUG]${RESET}${YELLOW} Function exceptionCatch requires 2 arguments, but some are missing! Check the log file for more info\n" >&2
		log "ERROR" "init.sh:exceptionCatch" "BUG : Some argument are missing. Expected argument: source \"$source\", "'$*'" \"$*\""
		return 2
	fi
	local output
	output=$("$@" 2>&1 >&3 3>&-) # using file descriptor 3 to get stderr only
	local exitCode=$?
	if (( exitCode != 0 )); then
		log "ERROR" "$source" "Command \"$*\" failed to execute!"
		[[ -n $output ]] && log "ERROR" "$source" "$output" # if there is an output, print it
	fi
	return "$exitCode" # return the command's exit code so the function can be used in if statements
}
