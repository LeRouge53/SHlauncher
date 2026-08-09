# shellcheck disable=SC2154

function helpPage() {
	printf "${CYAN}Usage :${RESET} opendir [<instance name>]\n"
	printf "Open the directory of the provided instance with your regular file explorer\n"
	printf "Default to the selected instance if <instance name> is unspecified\n"
	printf "To actually use \"help\" as an instance name, type \"\\help\" instead\n"
}

log "INFO" "opendir.sh" "opendir.sh called with instructions ${instructions[*]}"

targetInst=$1
if [ "$targetInst" = "" ]; then
	# shellcheck disable=SC2154
	targetInst=$instance
elif [ "$targetInst" = "help" ]; then
	helpPage
	return
elif [ "$targetInst" = "\help" ]; then
	targetInst="help"
fi

if [ "$targetInst" == "None" ]; then
	printf "${RED_BOLD}You did not selected or specified any instances, please do!${RESET}\n"
	return 1
elif ! [[ -f "$SHdir/instances/$targetInst.json" ]]; then
	printf "${RED_BOLD}The targeted instance doesn't exist${RESET}\n"
	return 1
fi

path=$(jq -r '.gameDir' "$SHdir/instances/$targetInst.json")
log "INFO" "opendir.sh" "Opening directory \"$path\" linked to instance \"$targetInst\""
xdg-open "$path"