# shellcheck disable=SC2154
cd "$SHdir/profiles" || exit 1
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
	if [ "${Sett[SelectedProfile]}" == "None" ]; then \
		DispProf="${RL_START}${RED}${RL_END}${Sett[SelectedProfile]}${RL_START}${RESET}${RL_END}"
		return
	fi
	profile=$(jq -r '.name' "${Sett[SelectedProfile]}.json")
	if jq -e '.isOnline' "${Sett[SelectedProfile]}.json" &>/dev/null; then \
		DispProf="${RL_START}${BLUE}${RL_END}${profile}${RL_START}${RESET}${RL_END}"; else \
		DispProf="${RL_START}${YELLOW}${RL_END}${profile}${RL_START}${RESET}${RL_END}"; fi
}

isDone=false

mkdir -p "$SHdir/profiles"

function helpPage() {
	printf "${CYAN}Usage${RESET} : profile <instruction> [<username>]\n"
	printf "The profile command allow to create, remove and select profiles used to play the game.\n"
	printf "${CYAN}Argument list :${RESET}\n"
	printf "help : Print this help\n"
	printf "list : List all available profiles (selected or not)\n"
	printf "auth : Create a premium profile using a microsoft account (PLANNED)\n"
	printf "reset : deselect a profile and restore it to \"None\"\n"
	printf "create <username> : create a profile with the username\n"
	printf "select <username> : select the profile corresponding to the username\n"
	printf "remove <username> : delete the profile corresponding to the username\n"
}

log "INFO" "profile.sh" "instance.sh called with instructions $*"

case $1 in
	"list")
		if [ "$(ls)" == "" ]; then
			printf "${YELLOW}No profiles were set up (yet!)${RESET}\n"
		else
			for Fprof in *.json; do
				log "INFO" "profile.sh:list" "Checking profile \"$Fprof\""
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
			return 2
		elif [ "$usrn" == "None" ]; then
			printf "${RED_BOLD}The name of this profile can't be \"None\", please use another name${RESET}\n"
			return 2
		else
			log "INFO" "profile.sh:create" "Creating profile \"$usrn\" \"$(UUIDcalc "$usrn")\""
			echo "creating profile with username: \"$usrn\" and UUID: \"$(UUIDcalc "$usrn")\""
			echo '{"name":"'"$usrn"'" , "isOnline":false , "uuid":"'"$(UUIDcalc "$usrn")"'" , "tuuid":"'"$(trimmedUUIDcalc "$usrn")"'"}' | jq . > "$(UUIDcalc "$usrn")".json
		fi
	;;
	"sel" | "select" | "switch")
		usrn="$2"
		if [ "$usrn" == "" ]; then printf "${RED_BOLD}Require a username as 3rd parameter; type \"profile help\"${RESET}\n"; fi

		for Fprof in *.json; do
			currentUsrn=$(jq -r '.name' "$Fprof")
			if [ "$usrn" == "$currentUsrn" ]; then
				writeSettingsValue SelectedProfile "$(jq -r '.uuid' "$Fprof")"
				log "INFO" "profile.sh:select" "New profile is \"$usrn\" with uuid \"$Fprof\""
				SetColor
				isDone=true
			fi
		done
		if ! $isDone; then echo "The specified profile \"$usrn\" does not exist"; fi
	;;
	"remove" | "delete")
		usrn="$2"
		if [ "$usrn" == "" ]; then echo "Require a username as 3rd argument; type \"profile help\""; fi

		for Fprof in *.json; do
			currentUsrn=$(jq -r '.name' "$Fprof")
			if [ "$usrn" == "$currentUsrn" ]; then
				log "WARN" "profile.sh:delete" "Deleting profile \"$usrn\" with uuid \"$Fprof\""
				command -p rm -- "$(jq -r '.uuid' "$Fprof")".json
				if [ "$usrn" == "$profile" ]; then 
					writeSettingsValue SelectedProfile None
					log "INFO" "profile.sh:delete" "New profile is \"None\""
				fi
				SetColor
				isDone=true
			fi
		done
		if ! $isDone; then echo "The specified profile \"$usrn\" does not exist"; fi
	;;
	"reset")
		log "INFO" "profile.sh:reset" "New profile is \"None\""
		writeSettingsValue SelectedProfile None
		SetColor
	;;
	"help")
		helpPage
	;;
	"")
		printf "${RED_BOLD}require arguments, type \"profile help\"${RESET}\n"
	;;
	*)
		printf "${RED_BOLD}Unknown argument : %s${RESET}\n" "$1"
esac

unset -v isDone