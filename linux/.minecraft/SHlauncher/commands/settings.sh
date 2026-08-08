function list() {
	printf "|=================================================================================================================================================|\n"
	printf "| %-50s | %-30s | %-42s | %-12s |\n" "SETTING NAME" "SETTING ID" "VALUE" "TYPE"
	mapfile -t settingName < <(jq -r '.settings | to_entries[] | .key' "data/user.json")
	for (( i=0; i<${#settingName[@]}; i++ )); do
		log "DEBUG" "settings.sh:list" "Checking settings \"${settingName[i]}\""
		settingName[i]=$(trimCr "${settingName[i]}")

		settingValue=$(trimCr "$(jq -r --argjson i "$i" '.settings | to_entries[$i] | .value' "data/user.json")")
		settingDisplayName=$(trimCr "$(jq -r --arg name "${settingName[i]}" '.settings | to_entries[] | select(.key == $name) | .value.displayName' "data/system.json")")
		settingType=$(trimCr "$(jq -r --arg name "${settingName[i]}" '.settings | to_entries[] | select(.key == $name) | .value.type' "data/system.json")")
		isHidden=$(trimCr "$(jq -r --arg name "${settingName[i]}" '.settings | to_entries[] | select(.key == $name) | .value.hidden' "data/system.json")")
		if [ "$isHidden" != "true" ] || ${parameter[all]}; then
			printf "|-------------------------------------------------------------------------------------------------------------------------------------------------|\n"
			printf "| %-50s | %-30s | %-42s | %-12s |\n" "$settingDisplayName" "${settingName[i]}" "$settingValue" "$settingType"
		else
			log "WARN" "settings.sh:list" "Did not show \"${settingName[i]}\" because it was marked as hidden. Use the parameter \"-a\" view it"
		fi
	done
	printf "|=================================================================================================================================================|\n"
}

function fetch() {
	settingId=$1
	if [ "$settingId" == "" ]; then
		printf "${RED_BOLD}Require a setting ID, use \"settings list\"${RESET}\n"
		return 2
	elif [ "$(jq -r ".settings.$settingId" "data/system.json")" == "null" ]; then
		printf "${RED_BOLD}The entered setting does not exist, use \"settings list\"${RESET}\n"
		return 2
	fi

	log "INFO" "settings.sh:fetch" "Fetching $settingId"
	displayName=$(trimCr "$(jq -r ".settings.$settingId.displayName" "data/system.json")")
	type=$(trimCr "$(jq -r ".settings.$settingId.type" "data/system.json")")
	description=$(trimCr "$(jq -r ".settings.$settingId.description" "data/system.json")")
	default=$(trimCr "$(jq -r ".settings.$settingId.default" "data/system.json")")
	value=$(trimCr "$(jq -r ".settings.$settingId" "data/user.json")")
	getOptionalValues

	log "DEBUG" "settings.sh:fetch" "setting type was resolved as $type"
	case $type in
		"boolean")
			printf "${CYAN}Display name:${RESET} %s\n" "$displayName"
			printf "${CYAN}Setting ID:${RESET} %s\n" "$settingId"
			printf "${CYAN}Value:${RESET} %s\n" "$value"
			printf "${CYAN}Default value:${RESET} %s\n" "$default"
			echo ""
			if $isProtected; then
				printf "${CYAN}Protected:${RED}Yes${RESET}\n"
			else
				printf "${CYAN}Protected:${GREEN}No${RESET}\n"
			fi
			if $requiresRestart; then
				printf "${CYAN}Require restart:${RED}Yes${RESET}\n"
			else
				printf "${CYAN}Require restart:${GREEN}No${RESET}\n"
			fi
			echo ""
			printf "${CYAN}Description:${RESET}\n"
			cat "$description"
			printf "\n\n"
		;;
		"number")
			min=$(trimCr "$(jq -r ".settings.$settingId.min"  "data/system.json")")
			max=$(trimCr "$(jq -r ".settings.$settingId.max"  "data/system.json")")
			step=$(trimCr "$(jq -r ".settings.$settingId.step"  "data/system.json")")

			printf "${CYAN}Display name:${RESET} %s\n" "$displayName"
			printf "${CYAN}Setting ID:${RESET} %s\n" "$settingId"
			printf "${CYAN}Setting type:${RESET} %s\n" "$type"
			printf "${CYAN}Minimum value:${RESET} %s\n" "$min"
			printf "${CYAN}Maximum value:${RESET} %s\n" "$max"
			printf "${CYAN}Step:${RESET} %s\n" "$step"
			printf "${CYAN}Value:${RESET} %s\n" "$value"
			printf "${CYAN}Default value:${RESET} %s\n" "$default"
			echo ""
			if $isProtected; then
				printf "${CYAN}Protected:${RED}Yes${RESET}\n"
			else
				printf "${CYAN}Protected:${GREEN}No${RESET}\n"
			fi
			if $requiresRestart; then
				printf "${CYAN}Require restart:${RED}Yes${RESET}\n"
			else
				printf "${CYAN}Require restart:${RED}No${RESET}\n"
			fi
			echo ""
			printf "${CYAN}Description:${RESET}\n"
			cat "$description"
			printf "\n\n"
		;;
		"string")
			printf "${CYAN}Display name:${RESET} %s\n" "$displayName"
			printf "${CYAN}Setting ID:${RESET} %s\n" "$settingId"
			printf "${CYAN}Setting type:${RESET} %s\n" "$type"
			printf "${CYAN}Value:${RESET} %s\n" "$value"
			printf "${CYAN}Default value:${RESET} %s\n" "$default"
			if $isProtected; then
				printf "${CYAN}Protected:${RED}Yes${RESET}\n"
			else
				printf "${CYAN}Protected:${GREEN}No${RESET}\n"
			fi
			if $requiresRestart; then
				printf "${CYAN}Require restart:${RED}Yes${RESET}\n"
			else
				printf "${CYAN}Require restart:${RED}No${RESET}\n"
			fi
			echo ""
			printf "${CYAN}Description:${RESET}\n"
			cat "$description"
			printf "\n\n"
		;;
		"enum")
			printf "${CYAN}Display name:${RESET} %s\n" "$displayName"
			printf "${CYAN}Setting ID:${RESET} %s\n" "$settingId"
			printf "${CYAN}Setting type:${RESET} %s\n" "$type"
			printf "${CYAN}Default value:${RESET} %s\n" "$default"
			if $isProtected; then
				printf "${CYAN}Protected:${RED}Yes${RESET}\n"
			else
				printf "${CYAN}Protected:${GREEN}No${RESET}\n"
			fi
			if $requiresRestart; then
				printf "${CYAN}Require restart:${RED}Yes${RESET}\n"
			else
				printf "${CYAN}Require restart:${RED}No${RESET}\n"
			fi
			printf "${CYAN}Available options:${RESET}\n"
			while read -r possibleSetting; do
				possibleSetting=$(trimCr "$possibleSetting")
				printf "   ${BLUE}%s${RESET} > " "$possibleSetting"
				printf "%s\n" "$(trimCr "$(jq -r --arg filter "$possibleSetting" ".settings.$settingId.enum[] | select(.displayName ==  "'$filter'") | .id" "data/system.json")")"
			done < <(jq -r ".settings.$settingId.enum[].displayName" "data/system.json")
			printf "${CYAN}Value:${RESET} %s\n" "$value"
			echo ""
			printf "${CYAN}Description:${RESET}\n"
			cat "$description"
			printf "\n\n"
		;;
		"file")
			mustExist=$(trimCr "$(jq -r ".settings.$settingId.mustExist"  "data/system.json")")

			printf "${CYAN}Display name:${RESET} %s\n" "$displayName"
			printf "${CYAN}Setting ID:${RESET} %s\n" "$settingId"
			printf "${CYAN}Setting type:${RESET} %s\n" "$type"
			printf "${CYAN}Value:${RESET} %s\n" "$value"
			printf "${CYAN}Default value:${RESET} %s\n" "$default"
			if $isProtected; then
				printf "${CYAN}Protected:${RED}Yes${RESET}\n"
			else
				printf "${CYAN}Protected:${GREEN}No${RESET}\n"
			fi
			if $requiresRestart; then
				printf "${CYAN}Require restart:${RED}Yes${RESET}\n"
			else
				printf "${CYAN}Require restart:${RED}No${RESET}\n"
			fi
			if [ "$value" != "" ]; then
				if ! [[ -f "$value" ]]; then
					if [ "$mustExist" = "true" ]; then
						printf "${RED}The file does NOT exist but it should${RESET}\n"
					else
						printf "${YELLOW}The file does NOT exist${RESET}\n"
					fi
				else
					printf "${GREEN}The file exist and is valid${RESET}\n"
				fi
			else
				printf "${YELLOW}The file is unspecified${RESET}\n"
			fi

			echo ""
			printf "${CYAN}Description:${RESET}\n"
			cat "$description"
			printf "\n\n"
		;;
		"folder")
			mustExist=$(trimCr "$(jq -r ".settings.$settingId.mustExist"  "data/system.json")")

			printf "${CYAN}Display name:${RESET} %s\n" "$displayName"
			printf "${CYAN}Setting ID:${RESET} %s\n" "$settingId"
			printf "${CYAN}Setting type:${RESET} %s\n" "$type"
			printf "${CYAN}Value:${RESET} %s\n" "$value"
			printf "${CYAN}Default value:${RESET} %s\n" "$default"
			if $isProtected; then
				printf "${CYAN}Protected:${RED}Yes${RESET}\n"
			else
				printf "${CYAN}Protected:${GREEN}No${RESET}\n"
			fi
			if $requiresRestart; then
				printf "${CYAN}Require restart:${RED}Yes${RESET}\n"
			else
				printf "${CYAN}Require restart:${RED}No${RESET}\n"
			fi
			if [ "$value" != "" ]; then
				if ! [[ -d "$value" ]]; then
					if [ "$mustExist" = "true" ]; then
						printf "${RED}The directory does NOT exist but it should${RESET}\n"
					else
						printf "${YELLOW}The directory does NOT exist${RESET}\n"
					fi
				else
					printf "${GREEN}The directory exist and is valid${RESET}\n"
				fi
			else
				printf "${YELLOW}The directory is unspecified${RESET}\n"
			fi

			echo ""
			printf "${CYAN}Description:${RESET}\n"
			cat "$description"
			printf "\n\n"
	esac
	log "DEBUG" "settings.sh:fetch" "Finished fetch for setting $settingId"
}

function edit() {
	settingId=$1
	newValue=$2
	# shellcheck disable=SC2194
	case "" in
		"$settingId" | "$newValue")
			printf "${RED_BOLD}One or more argument were forgotten, this command require a setting ID and a new value to set.${RESET}\n"
			return 2
		;;
		*)
			true
	esac
	if [ "$(jq -r ".settings.$settingId" "data/system.json")" == "null" ]; then
		printf "${RED_BOLD}The entered setting does not exist, use \"settings list\"${RESET}\n"
		return 2
	fi
	log "INFO" "settings.sh:edit" "Modifying $settingId to $newValue"
	type=$(trimCr "$(jq -r ".settings.$settingId.type" "data/system.json")")
	log "DEBUG" "settings.sh:edit" "Setting type was resolved as $type, checking requirements..."
	case $type in
		"boolean")
			newValue=${newValue//"yes"/"true"}
			newValue=${newValue//"no"/"false"}
			if [ "$newValue" != "true" ] && [ "$newValue" != "false" ]; then
				printf "Failed to apply the changes: this setting require a boolean (true or false, yes or no)${RESET}\n"
				log "ERROR" "settings.sh:edit" "Check failed, invalid value"
				return 2
			fi
		;;
		"number")
			min=$(trimCr "$(jq -r ".settings.$settingId.min"  "data/system.json")")
			max=$(trimCr "$(jq -r ".settings.$settingId.max"  "data/system.json")")
			step=$(trimCr "$(jq -r ".settings.$settingId.step"  "data/system.json")")
			if [[ "${newValue}" =~ [^0-9\.] ]]; then
				printf "${RED_BOLD}Failed to apply the changes: this setting require a number${RESET}\n"
				log "ERROR" "settings.sh:edit" "Check failed, invalid value"
				return 2
			elif awk "BEGIN {exit !($newValue > $max)}" || awk "BEGIN {exit !($newValue < $min)}"; then
				printf "${RED_BOLD}Failed to apply the changes: this setting is not contained between the minimum \"%s\" and the maximum \"%s\"${RESET}\n" "$min" "$max"
				log "ERROR" "settings.sh:edit" "Check failed, new value not contained between \"%s\" and \"%s\"" "$min" "$max"
				return 2
			elif [[ "$(awk "BEGIN {print ($newValue + $step)}")" =~ \. ]]; then
				printf "${RED_BOLD}Failed to apply the changes: the number doesn't respect the step \"%s\"${RESET}\n" "$step"
				log "ERROR" "settings.sh:edit" "Check failed, value does not respect the step \"%s\"" "$step"
				return 2
			fi
		;;
		"string")
			true # il n'y a aucune vérification si le type est un string
		;;
		"enum")
			isDone=false
			while read -r possibleSetting; do
				possibleSetting=$(trimCr "$possibleSetting")
				if [ "$newValue" = "$possibleSetting" ]; then
					isDone=true
					break
				fi
			done < <(jq -r ".settings.$settingId.enum[].id" "data/system.json")
			if ! $isDone; then
				printf "${RED_BOLD}Failed to apply the changes: The entered choice does not correspond to any predefined options, type \"settings fetch %s\"${RESET}\n" "$settingId"
				log "ERROR" "settings.sh:edit" "Check failed, value does not correspond to any predefined settings"
				return 1
			fi
		;;
		"file")
			mustExist=$(trimCr "$(jq -r ".settings.$settingId.mustExist"  "data/system.json")")
			createIfMissing=$(trimCr "$(jq -r ".settings.$settingId.createIfMissing"  "data/system.json")")
			if $createIfMissing; then
				command -p install -D "$newValue"
				touch "$newValue"
			elif $mustExist; then
				if ! [ -f "$newValue" ]; then
					printf "${RED_BOLD}Failed to apply the changes: this file need to exist before being set. Create it and retry${RESET}\n"
					log "ERROR" "settings.sh:edit" "Check failed, file does not exist"
					return 1
				fi
			fi
		;;
		"folder")
			mustExist=$(trimCr "$(jq -r ".settings.$settingId.mustExist"  "data/system.json")")
			createIfMissing=$(trimCr "$(jq -r ".settings.$settingId.createIfMissing"  "data/system.json")")
			if $createIfMissing; then
				mkdir -p "$newValue"
			elif $mustExist; then
				if ! [ -d "$newValue" ]; then
					printf "${RED_BOLD}Failed to apply the changes: this directory need to exist before being set. Create it and retry${RESET}\n"
					log "ERROR" "settings.sh:edit" "Check failed, directory does not exist"
					return 1
				fi
			fi
	esac
	log "DEBUG" "settings.sh:edit" "Finished checking requirements"

	getOptionalValues
	if $protectedEdit; then
		writeSettingsValue "$settingId" "$newValue"
		# shellcheck disable=SC2154
		if $requiresRestart; then
			printf "${YELLOW}To apply changes, please reset or restart the launcher${RESET}\n"
		fi
	elif $isProtected; then
		printf "${RED_BOLD}Failed to apply the changes: you are writing a protected value, please use \"settings pedit\"${RESET}\n"
		log "ERROR" "settings.sh:edit" "Failed to write the value. The setting is protected"
		return 1
	else
		writeSettingsValue "$settingId" "$newValue"
		# shellcheck disable=SC2154
		if $requiresRestart; then
			printf "${YELLOW}To apply changes, please reset or restart the launcher${RESET}\n"
		fi
	fi

}

function getOptionalValues() {
	isProtected=$(trimCr "$(jq -r ".settings.$settingId.isProtected" "data/system.json")")
	if [ "$isProtected" == "null" ] || [ "$isProtected" == "" ]; then
		isProtected=false
	fi
	requiresRestart=$(jq -r ".settings.$settingId.requiresRestart" "data/system.json")
	if [ "$requiresRestart" == "null" ] || [ "$requiresRestart" == "" ]; then
		requiresRestart=false
	fi
}

function reset() {
	settingId=$1
	if [ "$(jq -r ".settings.$settingId" "data/system.json")" == "null" ]; then
		printf "${RED_BOLD}The entered setting does not exist, use \"settings list\"${RESET}\n"
		return 2
	fi
	log "INFO" "settings.sh:edit" "Resetting $settingId..."
	default=$(jq -r ".settings.$settingId.default" "data/system.json")
	getOptionalValues
	
	writeSettingsValue "$settingId" "$default"

	# shellcheck disable=SC2154
	if $requiresRestart; then
		printf "${YELLOW}To apply changes, please reset or restart the launcher${RESET}\n"
	fi
}

function init() {
	if [[ -n $AreSettingsInited ]]; then
		log "ERROR" "settings.sh:init" "attempted to call settings.sh:init a 2nd time"
		printf "${RED_BOLD}\"settings init\" is a command reserved for the launcher's bootstraper, please don't run it as a user${RESET}\n"
	fi
	local currentSettingsVersion="0.0.1"
	log "INFO" "settings.sh:init" "Started loading settings. Compatible version is $currentSettingsVersion"
	if ! [[ -f "data/system.json" ]]; then
		log "FATAL" "settings.sh:init" "system.json was not found. Crash imminent"
		# shellcheck disable=SC2154 disable=SC1091
		source "$SHdir/crashHandler.sh" SETT_LOAD_FAIL
	elif ! [[ -f "data/user.json" ]]; then
	log "WARN" "settings.sh:init" "No user settings file found. creating..."
		printf "No user setting file detected, creating...\n"
		jq -n --arg SettingsVersion "$currentSettingsVersion" \
		'{
			"settingsVersion": $SettingsVersion,
			"type": "user",
			"settings": {}
		}' > data/user.json
		log "WARN" "settings.sh:init" "restarting settings.sh:init"
		init
	elif [ "$(jq -r '.settingsVersion' "data/system.json")" != "$currentSettingsVersion" ]; then
		log "FATAL" "settings.sh:init" "Encountered an unsupported version $(jq -r '.settingsVersion' "data/user.json"), cannot continue"
		printf "${YELLOW_BOLD}[BUG]${YELLOW} Unsupported setting version %s, not continuing\n${RESET}" "$(jq -r '.settingsVersion' "data/user.json")"
		# shellcheck disable=SC2154 disable=SC1091
		source "$SHdir/crashHandler.sh" SETT_LOAD_FAIL
	else
		while IFS=$'\n' read -r object; do
			read -r key < <(jq -r '.key' \
				<<- EOF
				$object
				EOF
				)
			log "DEBUG" "settings.sh:init" "Found key \"$key\""
			if [ "$(jq -r ".settings.$key" "data/user.json")" == "null" ]; then
				log "INFO" "settings.sh:init" "$key seem to not exist in the user settings file, applying default"
				writeSettingsValue "$key" "$(jq -r ".settings.$key.default" "data/system.json")"
			else
				IFS= read -r value < <(jq -r ".settings.$key" "data/user.json")
				Sett["$key"]=$value
				log "DEBUG" "settings.sh:init" "Applying value \"$value\" for key \"$key\""
			fi
		done < <(jq -c '.settings | to_entries[]' "data/system.json")
		export Sett
		AreSettingsInited="Yh it's done"
		log "DEBUG" "settings.sh:init" "Finished loading settings"
	fi
}

function helpPage() {
	printf "${CYAN}Usage : ${RESET} settings [-a] <instruction> [<setting ID>]\n"
	printf "manages the setting used by SHlauncher ; manipulates the \"user.json\" file\nlocated at SHlauncher/settings/data/user.json and can be modified manually.\n"
	printf "this command is made to edit this file more easily\n"
	printf "${CYAN}Argument list${RESET} :\n"
	printf " - list [-a] : Lists all non-hidden settings\n"
	printf " - edit : Edit a setting (apply the modification immediately if possible)\n"
	printf " - pedit : Edit a setting even if it is protected\n"
	printf " - init : Only used by the bootstraper. Loads every settings at the start of the launcher\n"
	printf " - reset : Resets a settings to the default value\n"
	printf " - help : Prints this help\n"
	printf " - \"-a\" | \"--all\" : List every settings, even hidden ones\n"
}

function argHandler() {
	case $1 in
		"list")
			shift
			list
		;;
		"edit" | "set")
			shift
			edit "$@"
		;;
		"pedit" | "pset" | "protected-edit" | "protected-set")
			protectedEdit=true
			shift
			edit "$@"
		;;
		"fetch" | "detail")
			shift
			fetch "$@"
		;;
		"init")
			init
		;;
		"reset")
			shift
			reset "$@"
		;;
		"help")
			helpPage
		;;
		"")
			printf "${YELLOW}No instructions given, assuming \"list\"${RESET}\n"
			list
		;;
		*)
			printf "${RED_BOLD}Unknown argument %s${RESET}\n" "$1"
			return 1
	esac
}
# shellcheck disable=SC2154
mkdir -p "$SHdir/settings"
cd "$SHdir/settings" || return 1
protectedEdit=false
requiresRestart=false

parameter[all]=false

declareArgs all a flag

if ! globalArgHandler "$@"; then
	return 1
fi

# shellcheck disable=SC2154
log "INFO" "settings.sh" "settings.sh called with instructions ${instructions[*]}"

argHandler "${instructions[@]}"

unset parameter
declare -gA parameter