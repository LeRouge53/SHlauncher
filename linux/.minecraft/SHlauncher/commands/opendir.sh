# shellcheck disable=SC2154

targetInst=$1
if [ "$targetInst" = "" ]; then
	# shellcheck disable=SC2154
	targetInst=$instance
fi

if [ "$targetInst" == "None" ]; then
	printf "${RED_BOLD}You did not selected or specified any instances, please do!${RESET}\n"
	return 1
elif ! [[ -f "$SHdir/instances/$targetInst.json" ]]; then
	printf "${RED_BOLD}The targeted instance doesn't exist${RESET}\n"
	return 1
fi

path=$(jq -r '.gameDir' "$SHdir/instances/$targetInst.json")
xdg-open "$path"