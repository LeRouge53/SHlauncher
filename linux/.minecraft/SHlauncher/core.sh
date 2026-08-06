#shellcheck source=./commands/profile.sh
# shellcheck disable=SC2059
# shellcheck disable=SC2154

cd ./commands || ./crashHandler.sh CDFAIL

if [ "$(tput cols)" -lt 150 ] && ${Sett[ShowTerminalSizeWarning]}; then
	printf "${YELLOW}It is not recommended to use SHlauncher with a terminal containing less than 150 columns${RESET}\n"
	printf "${YELLOW}Please use a bigger terminal if possible${RESET}\n"
fi

if [ "${Sett[SelectedProfile]}" == "None" ]; then 
	DispProf="${RL_START}${RED}${RL_END}${Sett[SelectedProfile]}${RL_START}${RESET}${RL_END}"
else
	profile=$(jq -r '.name' "$SHdir/profiles/${Sett[SelectedProfile]}.json")
	if jq -e '.isOnline' "$SHdir/profiles/${Sett[SelectedProfile]}.json" &>/dev/null; then \
		DispProf="${RL_START}${BLUE}${RL_END}${profile}${RL_START}${RESET}${RL_END}"
	else
		DispProf="${RL_START}${YELLOW}${RL_END}${profile}${RL_START}${RESET}${RL_END}"
	fi
fi

if [ "${Sett[SelectedInstance]}" == "None" ]; then 
	DispInst="${RL_START}${RED}${RL_END}${Sett[SelectedInstance]}${RL_START}${RESET}${RL_END}"
else
	DispInst="${RL_START}${GREEN}${RL_END}${Sett[SelectedInstance]}${RL_START}${RESET}${RL_END}"
fi

lastCommandLine=""
while true; do
	cd "$SHdir/commands" || ./crashHandler.sh CDFAIL
	IFS=$IFSBak
	read -erp "SHlauncher ${DispProf}:${DispInst}> " commandLine
	commandLine=$(trimCr "$commandLine")
	if [[ "$commandLine" =~ [\;\&\|\>\<\`\$\(\)\*] ]] && $cip; then
		printf "${RED_BOLD}Command injection protection is on, usage of special characters \" ;  &  |  >  <  \`  $  (  ) * \" is forbidden${RESET}\n"
		continue
	fi
	if [ "$commandLine" != "" ] || [ "$lastCommandLine" != "$commandLine" ]; then
		history -s "$commandLine"
	fi
	lastCommandLine=$commandLine
	# shellcheck disable=SC2086
	set -- $commandLine
	cmd=$1
	shift
	case "$cmd" in
		"exit")
			history -w
			history -c
			HISTFILE="$HOME/.bash_history"
			history -r
			set +x
			exit 0
		;;
		"profile" | "profiles")
			source ./profile.sh "$@"
		;;
		"version" | "versions")
			source ./version.sh "$@"
		;;
		"instance" | "instances")
			source ./instance.sh "$@"
		;;
		"java")
			source ./java.sh "$@"
		;;
		"launch")
			source ./launch.sh "$@"
		;;
		"opendir")
			source ./opendir.sh "$@"
		;;
		"settings" | "sett")
			source ./settings.sh "$@"
		;;
		"about")
			source ./about.sh "$@"
		;;
		"reset")
			# shellcheck disable=SC2164
			cd "$dir/"
			history -w
			set +x
			exec ./init.sh
		;;
		"debug")
			# shellcheck disable=SC2164
			cd "$dir/"
			history -w
			set +x
			exec ./init.sh --debug
		;;
		"clear")
			clear
		;;
		"echo")
			echo "$@"
		;;
		"")
			true # pas une erreur tkt
		;;
		*)
			echo "Unknown command: $cmd"
	esac
done