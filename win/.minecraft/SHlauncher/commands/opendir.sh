targetInst=$1
if [ "$targetInst" = "" ]; then
    # shellcheck disable=SC2154
    targetInst=$instance
fi

if [ "$targetInst" == "None" ]; then
    printf "${RED_BOLD}You did not selected or specified any instances, please do!${RESET}\n"
    return 1
fi

# shellcheck disable=SC2154
path=$(jq -r '.gameDir' "$dir/.minecraft/SHlauncher/instances/$targetInst.json")
path=${path//\//\\}
start "" "$path"