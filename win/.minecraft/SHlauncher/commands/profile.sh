# shellcheck disable=SC2154
cd "$dir/.minecraft/SHlauncher/profiles" || exit 1
function UUIDcalc() {
    hash=$(echo -n "OfflinePlayer:${1}" | md5sum | cut -d' ' -f1) #maji
    uuid="${hash:0:8}-${hash:8:4}-${hash:12:4}-${hash:16:4}-${hash:20:12}"
    echo "$uuid"
}
function trimmedUUIDcalc() {
    uuid=$(echo -n "OfflinePlayer:${1}" | md5sum | cut -d' ' -f1) #maji(2)
    echo "$uuid"
}

function SetColor() {
    if [ "$profile" == "None" ]; then \
        DispProf="${RL_START}${RED}${RL_END}${profile}${RL_START}${RESET}${RL_END}"
        return 0
    fi

    for Fprof in *.json; do
    if jq -e '.selected' "$Fprof" &>/dev/null; then
        if jq -e '.isOnline' "$Fprof" &>/dev/null; then \
            DispProf="${RL_START}${BLUE}${RL_END}${profile}${RL_START}${RESET}${RL_END}"; else \
            DispProf="${RL_START}${YELLOW}${RL_END}${profile}${RL_START}${RESET}${RL_END}"; fi
    fi
    done
}

isDone=false

mkdir -p "$dir/.minecraft/SHlauncher/profiles"

case $1 in
    "list")
        if [ "$(ls)" == "" ]; then
            printf "${YELLOW}No profiles were set up (yet!)${RESET}\n"
        else
            for Fprof in *.json; do
                printf "${BLUE}%s :${RESET}\n" "$(jq -r '.name' "$Fprof")"
                echo " - UUID: $(jq -r .uuid "$Fprof")"
            done
        fi
    ;;
    "create")
        usrn="$2"
	    if [ "$usrn" == "" ]; then echo "Require a username as 3rd parameter; type \"profile help\""; fi
        if ! [[ "$usrn" =~ ^[A-Za-z0-9_]{3,16}$ ]]; then #bro wtf ?
            printf "${RED_BOLD}Invalid username: The username need to be between 3 to 16 character long and can only contain letters, numbers, \"-\" and \"_\"${RESET}\n"
            return 1
        elif [ "$usrn" == "None" ]; then
            printf "${RED_BOLD}The name of this profile can't be \"None\", please use another name${RESET}\n"
            return 1 
        else
            echo "creating profile with username: \"$usrn\" and UUID: \"$(UUIDcalc "$usrn")\""
            echo '{"name":"'"$usrn"'" , "isOnline":false , "uuid":"'"$(UUIDcalc "$usrn")"'" , "tuuid":"'"$(trimmedUUIDcalc "$usrn")"'" , "selected": false}' | jq . > "$(UUIDcalc "$usrn")".json
        fi
    ;;
    "select" | "switch")
        usrn="$2"
        if [ "$usrn" == "" ]; then echo "Require a username as 3rd parameter; type \"profile help\""; fi

        for Fprof in *.json; do
            currentUsrn=$(jq -r '.name' "$Fprof")
            if [ "$usrn" == "$currentUsrn" ]; then
                if [ "$profile" == "None" ]; then
                    profile=$usrn
                    contents="$(jq '.selected = true' "$Fprof")" && echo -E "${contents}" > "$Fprof"
                    SetColor
                    isDone=true
                else
                    contents="$(jq '.selected = false' "$Fprof")" && echo -E "${contents}" > "$Fprof"
                    profile=$usrn
                    contents="$(jq '.selected = true' "$Fprof")" && echo -E "${contents}" > "$Fprof"
                    SetColor
                    isDone=true
                fi
            fi
        done
        if ! $isDone; then echo "The specified profile \"$usrn\" does not exist"; fi
    ;;
    "remove" | "delete")
        usrn="$2"
        if [ "$usrn" == "" ]; then echo "Require a username as 3rd parameter; type \"profile help\""; fi

        for Fprof in *.json; do
            currentUsrn=$(jq -r '.name' "$Fprof")
            if [ "$usrn" == "$currentUsrn" ]; then
                /usr/bin/rm -- "$(jq -r '.uuid' "$Fprof")".json
                if [ "$usrn" == "$profile" ]; then profile="None"; fi
                SetColor
                isDone=true
            fi
        done
        if ! $isDone; then echo "The specified profile \"$usrn\" does not exist"; fi
    ;;
    "reset")
        for Fprof in *.json; do
            contents="$(jq '.selected = false' "$Fprof")" && echo -E "${contents}" > "$Fprof"
        done
        profile="None"
        SetColor
    ;;
    "help")
        cat ../help/profile.txt
        echo ""
    ;;
    "")
        echo "require arguments, type \"profile help\""
    ;;
    *)
        echo "Uknown argument : $1"
esac

unset -v isDone