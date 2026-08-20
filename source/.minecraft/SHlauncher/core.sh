# shellcheck disable=SC2154

log "DEBUG" "core.sh" "Core.sh successfully called. Starting..."

cd "$SHdir/commands" || "$SHdir/crashHandler.sh" CDFAIL

if [ "$(tput cols)" -lt 150 ]; then
	log "WARN" "core.sh" "Bad terminal size detected, $(tput cols) may be too small"
	if ${Sett[ShowTerminalSizeWarning]}; then
		printf "${YELLOW}It is not recommended to use SHlauncher with a terminal containing less than 150 columns${RESET}\n"
		printf "${YELLOW}Please use a bigger terminal if possible${RESET}\n"
	fi
fi

log "DEBUG" "core.sh" "Started loading display profile"
if [ "${Sett[SelectedProfile]}" == "None" ]; then
	log "WARN" "core.sh" "Display profile was resolved to None"
	DispProf="${RL_START}${RED}${RL_END}${Sett[SelectedProfile]}${RL_START}${RESET}${RL_END}"
else
	profile=$(jq -r '.name' "$SHdir/profiles/${Sett[SelectedProfile]}.json")
	log "INFO" "core.sh" "Display profile was resolved to \"$profile\""
	if jq -e '.isOnline' "$SHdir/profiles/${Sett[SelectedProfile]}.json" &>/dev/null; then \
		DispProf="${RL_START}${BLUE}${RL_END}${profile}${RL_START}${RESET}${RL_END}"
	else
		DispProf="${RL_START}${YELLOW}${RL_END}${profile}${RL_START}${RESET}${RL_END}"
	fi
fi

log "DEBUG" "core.sh" "Started loading display instance"
if [ "${Sett[SelectedInstance]}" == "None" ]; then 
	DispInst="${RL_START}${RED}${RL_END}${Sett[SelectedInstance]}${RL_START}${RESET}${RL_END}"
	log "WARN" "core.sh" "Display instance was resolved to None"
else
	DispInst="${RL_START}${GREEN}${RL_END}${Sett[SelectedInstance]}${RL_START}${RESET}${RL_END}"
	log "INFO" "core.sh" "Display profile was resolved to \"${Sett[SelectedInstance]}\""
fi

lastCommandLine=""
log "INFO" "core.sh" "Entering shell loop!"
while true; do
	cd "$SHdir/commands" || source "$SHdir/crashHandler.sh" CD_FAIL
	IFS=$IFSBak
	log "INFO" "core.sh" "Displaying shell"
	read -erp "SHlauncher ${DispProf}:${DispInst}> " commandLine
	commandLine=$(trimCr "$commandLine")
	log "DEBUG" "core.sh" "Command line is \"$commandLine\""
	if [[ "$commandLine" =~ [\;\&\|\>\<\`\$\(\)\*] ]] && $cip; then
		log "ERROR" "core.sh" "Caught special characters by CIP command injection protection"
		printf "${RED_BOLD}Command injection protection is active, usage of special characters \" ;  &  |  >  <  \`  $  (  ) * \" is forbidden${RESET}\n"
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
			# shellcheck source=commands/profile.sh
			source ./profile.sh "$@"
		;;
		"version" | "versions")
			# shellcheck source=commands/version.sh
			source ./version.sh "$@"
		;;
		"instance" | "instances")
			# shellcheck source=commands/instance.sh
			source ./instance.sh "$@"
		;;
		"java")
			# shellcheck source=commands/java.sh
			source ./java.sh "$@"
		;;
		"launch")
			# shellcheck source=commands/launch.sh
			source ./launch.sh "$@"
		;;
		"opendir")
			# shellcheck source=commands/opendir.sh
			source ./opendir.sh "$@"
		;;
		"settings" | "sett")
			# shellcheck source=commands/settings.sh
			source ./settings.sh "$@"
		;;
		"about")
			# shellcheck source=commands/about.sh
			source ./about.sh "$@"
		;;
		"help")
			# shellcheck source=commands/about.sh
			source ./about.sh "get-started"
		;;
		"reset")
			# shellcheck disable=SC2164
			cd "$dir/"
			history -w
			set +x
			exec ./init.sh "$@"
		;;
		"clear")
			clear
		;;
		"echo")
			echo "$@"
		;;
		"log")
			logLevel=$1
			source=$2
			shift 2
			log "$logLevel" "$source" "$*"
		;;
		"")
			true
		;;
		*)
			echo "Unknown command: $cmd"
      log "ERROR" "core.sh" "Command not found : \"$cmd\""
	esac
done