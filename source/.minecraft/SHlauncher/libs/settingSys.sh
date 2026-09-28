# shellcheck disable=SC2154

function writeSettingsValue() {
	local settingId=$1 # ID of the setting to write
	local value=$2 # value (can be empty)
	if [[ -z "$settingId" ]]; then
		log "ERROR" "init.sh:writeSettingsValue" "BUG : Some argument are missing, expected argument settingId : \"$settingId\", value (optional): \"$value\""
		printf "${YELLOW_BOLD}[BUG]${RESET}${YELLOW} Function writeSettingsValue requires 2 arguments but some are missing! Check the log file for more info\n" >&2
		return 2
	fi
	tmp=$(mktemp)
	Sett["$settingId"]=$value
	jq ".settings.$settingId = \"$value\"" "$SHdir/settings/data/user.json" > "$tmp" && mv "$tmp" "$SHdir/settings/data/user.json"
	log "DEBUG" "init.sh:writeSettingsValue" "wrote setting value \"$settingId\" with \"$value\""
}