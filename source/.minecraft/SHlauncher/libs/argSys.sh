function declareArgs() {
	local long="$1" # foo (long parameter name)
	local short="$2" # f (short parameter name linked to the long one). Is optional
	local type="$3" # "value" or "flag" ; value : the user needs to enter a value with the parameter. flag : if the parameter is specified, switch the value to true 
	case "" in
		"$long" | "$short" | "$type")
			printf "${YELLOW_BOLD}[BUG]${YELLOW} Function declareArgs requires 3 arguments but some are missing! Check the log file for more info\n" >&2
			log "ERROR" "init.sh:declareArgs" "BUG : Some argument are missing. Expected argument: long \"$long\", short \"$short\" (optional), type \"$type\""
			return 2
		;;
		*)
			true
	esac

	declaredLongParam["$long"]="$type"

	if [ "$short" != "NoShort" ] || [ -z "$short" ]; then
		declaredShortParam["$short"]="$long"
	fi
	log "DEBUG" "init.sh:declareArgs" "Declared parameter \"$long\" with short \"$short\" and type \"$type\""
}

function globalArgHandler() {
	local -a args=("$@")
	local translatedParam
	local argName
	instructions=()

	for ((i=0;i<"${#args[@]}";i++)); do
		case ${args[i]} in
			--*)
				# if the arg is long
				argName=${args[i]#--}
				log "DEBUG" "init.sh:globalArgHandler" "Found parameter $argName"
				if [ "${declaredLongParam["$argName"]}" == "" ]; then continue; fi # if it's undefined, skip
				if [ "${declaredLongParam["$argName"]}" = "value" ]; then # if it's defined as a value, take the following arg
					if (( i + 1 >= ${#args[@]} )); then
						printf "${RED_BOLD}%s require a value${RESET}\n" "$argName"
						return 2
					fi
					parameter["$argName"]=${args[(( i + 1 ))]}
					((i++)) # skip the value as an argument (as it's already been treated)
				else
					parameter["$argName"]=true # if it's not defined as a value, then it's a flag
				fi
				log "DEBUG" "init.sh:globalArgHandler" "resolved $argName to ${parameter["$argName"]}"
			;;
			-*)
				# if the arg is short, just translate it to the long arg and treat it the exact same way
				translatedParam=${declaredShortParam["${args[i]#-}"]}
				log "DEBUG" "init.sh:globalArgHandler" "Found parameter $translatedParam"
				if [ "$translatedParam" == "" ]; then continue; fi
				if [ "${declaredLongParam["$translatedParam"]}" = "value" ]; then
					if (( i + 1 >= ${#args[@]} )); then
						printf "${RED_BOLD}%s require a value${RESET}\n" "$translatedParam"
						return 2
					fi
					parameter["$translatedParam"]=${args[(( i + 1 ))]}
					((i++))
				else
					parameter["$translatedParam"]=true
				fi
				log "DEBUG" "init.sh:globalArgHandler" "resolved $translatedParam to ${parameter["$translatedParam"]}"
			;;
			*)
				instructions+=("${args[$i]}")
		esac
	done
}