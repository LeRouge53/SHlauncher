function list() {
	printf "|=================================================================================================================================================|\n"
	printf "| %-50s | %-30s | %-42s | %-12s |\n" "SETTING NAME" "SETTING ID" "VALUE" "TYPE"
	mapfile -t settingName < <(jq -r '.settings | to_entries[] | .key' "data/user.json")
	for (( i=0; i<${#settingName[@]}; i++ )); do
		settingName[i]=$(trimCr "${settingName[i]}")

		settingValue=$(trimCr "$(jq -r --argjson i "$i" '.settings | to_entries[$i] | .value' "data/user.json")")
		settingDisplayName=$(trimCr "$(jq -r --arg name "${settingName[i]}" '.settings | to_entries[] | select(.key == $name) | .value.displayName' "data/system.json")")
		settingType=$(trimCr "$(jq -r --arg name "${settingName[i]}" '.settings | to_entries[] | select(.key == $name) | .value.type' "data/system.json")")
		isHidden=$(trimCr "$(jq -r --arg name "${settingName[i]}" '.settings | to_entries[] | select(.key == $name) | .value.hidden' "data/system.json")")
		if [ "$isHidden" != "true" ] || ${parameter[all]}; then
			printf "|-------------------------------------------------------------------------------------------------------------------------------------------------|\n"
			printf "| %-50s | %-30s | %-42s | %-12s |\n" "$settingDisplayName" "${settingName[i]}" "$settingValue" "$settingType"
		fi
	done
	printf "|=================================================================================================================================================|\n"
}

function fetch() {
	settingId=$1
	if [ "$settingId" == "" ]; then
		printf "${RED_BOLD}Require a setting ID, use \"settings list\"${RESET}\n"
		return 1
	elif [ "$(jq -r ".settings.$settingId" "data/system.json")" == "null" ]; then
		printf "${RED_BOLD}The entered setting does not exist, use \"settings list\"${RESET}\n"
		return 1
	fi
	displayName=$(trimCr "$(jq -r ".settings.$settingId.displayName" "data/system.json")")
	type=$(trimCr "$(jq -r ".settings.$settingId.type" "data/system.json")")
	description=$(trimCr "$(jq -r ".settings.$settingId.description" "data/system.json")")
	default=$(trimCr "$(jq -r ".settings.$settingId.default" "data/system.json")")
	value=$(trimCr "$(jq -r ".settings.$settingId" "data/user.json")")
	getOptionnalValues

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
			printf "${CYAN}Avariable options:${RESET}\n"
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
}

function edit() {
	settingId=$1
	newValue=$2
	# shellcheck disable=SC2194
	case "" in
		"$settingId" | "$newValue")
			printf "${RED_BOLD}One or more argument were forgotten, this command require a setting ID and a new value to set.${RESET}\n"
			return 1
		;;
		*)
			true
	esac
	if [ "$(jq -r ".settings.$settingId" "data/system.json")" == "null" ]; then
		printf "${RED_BOLD}The entered setting does not exist, use \"settings list\"${RESET}\n"
		return 1
	fi
	type=$(trimCr "$(jq -r ".settings.$settingId.type" "data/system.json")")
	value=$(trimCr "$(jq -r ".settings.$settingId" "data/user.json")")
	case $type in
		"boolean")
			newValue=${newValue//"yes"/"true"}
			newValue=${newValue//"no"/"false"}
			if [ "$newValue" != "true" ] && [ "$newValue" != "false" ]; then
				printf "Failed to apply the changes: this setting require a boolean (true or false, yes or no)${RESET}\n"
				return 1
			fi
		;;
		"number")
			min=$(trimCr "$(jq -r ".settings.$settingId.min"  "data/system.json")")
			max=$(trimCr "$(jq -r ".settings.$settingId.max"  "data/system.json")")
			step=$(trimCr "$(jq -r ".settings.$settingId.step"  "data/system.json")")
			if [[ "${newValue}" =~ [^0-9\.] ]]; then
				printf "${RED_BOLD}Failed to apply the changes: this setting require a number${RESET}\n"
				return 1
			elif [[ "$(awk -v newValue="$newValue" -v step="$step" 'BEGIN {print (newValue + step)}')" =~ \. ]]; then
				printf "${RED_BOLD}Failed to apply the changes: the number doesn't respect the step \"%s\"${RESET}\n" "$step"
				return 1
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
					return 1
				fi
			fi
	esac

	getOptionnalValues
	if $protectedEdit; then
		writeSettingsValue "$settingId" "$newValue"
		# shellcheck disable=SC2154
		if $requiresRestart; then
			printf "${YELLOW}To apply changes, please reset or restart the launcher${RESET}\n"
		fi
	elif $isProtected; then
		printf "${RED_BOLD}Failed to apply the changes: you are writing a protected value, please use \"settings pedit\"${RESET}\n"
		return 1
	else
		writeSettingsValue "$settingId" "$newValue"
		# shellcheck disable=SC2154
		if $requiresRestart; then
			printf "${YELLOW}To apply changes, please reset or restart the launcher${RESET}\n"
		fi
	fi

}

function getOptionnalValues() {
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
		return 1
	fi
	default=$(jq -r ".settings.$settingId.default" "data/system.json")
	getOptionnalValues
	
	writeSettingsValue "$settingId" "$default"

	# shellcheck disable=SC2154
	if $requiresRestart; then
		printf "${YELLOW}To apply changes, please reset or restart the launcher${RESET}\n"
	fi
}

function init() {
	if [[ -n $AreSettingsInited ]]; then
		printf "${RED_BOLD}\"settings init\" is a command reserved for the launcher's bootstraper, please don't run it as a user${RESET}\n"
	else
		AreSettingsInited="Yh it's done"
	fi
	local currentSettingsVersion="0.0.1"
	if ! [[ -f "data/system.json" ]]; then
		# shellcheck disable=SC2154 disable=SC1091
		source "$SHdir/crashHandler.sh" SETT_LOAD_FAIL
	elif ! [[ -f "data/user.json" ]]; then
		printf "No user setting file detected, creating...\n"
		jq -n --arg SettingsVersion "$currentSettingsVersion" \
		'{
			"settingsVersion": $SettingsVersion,
			"type": "user",
			"settings": {}
		}' > data/user.json
		init

	elif [ "$(jq -r '.settingsVersion' "data/system.json")" != "$currentSettingsVersion" ]; then
		printf "${YELLOW_BOLD}[BUG]${YELLOW} Unsupported setting version %s, not continuing\n${RESET}" "$(jq -r '.settingsVersion' "data/user.json")"
		return 1
	else
		while IFS=$'\n' read -r object; do
			read -r key < <(jq -r '.key' \
				<<- EOF
				$object
				EOF
				)
			if [ "$(jq -r ".settings.$key" "data/user.json")" == "null" ]; then
				writeSettingsValue "$key" "$(jq -r ".settings.$key.default" "data/system.json")"
			else
				IFS= read -r value < <(jq -r ".settings.$key" "data/user.json")
				Sett["$key"]=$value
			fi
		done < <(jq -c '.settings | to_entries[]' "data/system.json")
		export Sett
	fi
}

function argHandler() {
	case $1 in
		"list")
			shift
			list "$@"
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
		"")
			printf "${YELLOW}No instructions given, assuming \"list\"${RESET}\n"
			list
		;;
		*)
			printf "${RED_BOLD}Uknown argument %s${RESET}\n" "$1"
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
argHandler "${instructions[@]}"

unset parameter
declare -gA parameter