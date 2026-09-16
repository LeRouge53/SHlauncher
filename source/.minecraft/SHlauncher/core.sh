# shellcheck disable=SC2154
log "DEBUG" "core.sh" "Core.sh successfully called. Starting..."

cd "$SHdir/commands" || "$SHdir/crashHandler.sh" CD_FAIL

columnNumber="$(tput cols)" # checking terminal size
[ "$?" -eq 127 ] && {
  log "ERROR" "core.sh" "Failed to check terminal size, \"tput\" command not found" # only made that because I tried to run the launcher on termux (it doesn't have tput)
}
if [ -n "$columnNumber" ] && [ "$columnNumber" -lt 150 ]; then
	log "WARN" "core.sh" "Bad terminal size detected, $columnNumber columns may be too small"
	if ${Sett[ShowTerminalSizeWarning]}; then
		printf "${YELLOW}It is not recommended to use SHlauncher with a terminal containing less than 150 columns${RESET}\n"
		printf "${YELLOW}Please use a bigger terminal if possible${RESET}\n"
	fi
fi

log "DEBUG" "core.sh" "Started loading display profile"
# alot of chaos there, but it sets colors in the prompt string based on the profile
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
# same but for the instance
if [ "${Sett[SelectedInstance]}" == "None" ]; then 
	DispInst="${RL_START}${RED}${RL_END}${Sett[SelectedInstance]}${RL_START}${RESET}${RL_END}"
	log "WARN" "core.sh" "Display instance was resolved to None"
elif [ "$(jq -r '.side' "$SHdir/instances/${Sett[SelectedInstance]}.json")" = "server" ]; then
	DispInst="${RL_START}${CYAN}${RL_END}${Sett[SelectedInstance]}${RL_START}${RESET}${RL_END}"
else
	DispInst="${RL_START}${GREEN}${RL_END}${Sett[SelectedInstance]}${RL_START}${RESET}${RL_END}"
	log "INFO" "core.sh" "Display profile was resolved to \"${Sett[SelectedInstance]}\""
fi

lastCommandLine=""
declare -g cmdExitCode
cmdExitCode=0
cmdDir="$SHdir/commands"

function commandLineHandler() {
	if [ -z "$*" ]; then
		printf "${YELLOW_BOLD}[BUG]${YELLOW} Function commandLineHandler require 1 arguments but it is missing! Check the log file for more info${RESET}\n"
		log "ERROR" "core.sh:commandLineHandler" "BUG : Some argument are missing. Expected argument: commandLine \"$commandLine\""
	fi
	if [ "$*" != "" ] || [ "$lastCommandLine" != "$*" ]; then
		history -s -- "$*"
	fi
	lastCommandLine="$*"
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
		source "$cmdDir/profile.sh" "$@"
		cmdExitCode=$?
	;;
	"version" | "versions")
		# shellcheck source=commands/version.sh
		source "$cmdDir/version.sh" "$@"
		cmdExitCode=$?
	;;
	"instance" | "instances")
		# shellcheck source=commands/instance.sh
		source "$cmdDir/instance.sh" "$@"
		cmdExitCode=$?
	;;
	"java")
		# shellcheck source=commands/java.sh
		source "$cmdDir/java.sh" "$@"
		cmdExitCode=$?
	;;
	"launch")
		# shellcheck source=commands/launch.sh
		source "$cmdDir/launch2.sh" "$@"
		cmdExitCode=$?
	;;
	"opendir")
		# shellcheck source=commands/opendir.sh
		source "$cmdDir/opendir.sh" "$@"
		cmdExitCode=$?
	;;
	"settings" | "setting")
		# shellcheck source=commands/settings.sh
		source "$cmdDir/settings.sh" "$@"
		cmdExitCode=$?
	;;
	"about")
		# shellcheck source=commands/about.sh
		source "$cmdDir/about.sh" "$@"
		cmdExitCode=$?
	;;
	"ror")
		# shellcheck source=commands/ror.sh
		source "$cmdDir/ror.sh" "$@"
		cmdExitCode=$?
	;;
	"help")
		# shellcheck source=commands/about.sh
		source "$cmdDir/about.sh" "get-started"
		cmdExitCode=$?
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
		cmdExitCode=$?
	;;
	"")
		true
	;;
	*)
		echo "Unknown command: $cmd"
		log "ERROR" "core.sh" "Command not found : \"$cmd\""
		cmdExitCode=2
	esac
}

function launchCommand() {
	if [ -z "$*" ]; then
		printf "${YELLOW_BOLD}[BUG]${YELLOW} Function launchCommand require 1 arguments but it is missing! Check the log file for more info${RESET}\n"
		log "ERROR" "core.sh:launchCommand" "BUG : Some argument are missing. Expected argument: commandLine \"$*\""
		return 1
	fi

	log "DEBUG" "core.sh" "Command line is \"$*\""
	if $cip && [[ "$*" =~ [\;\&\|\>\<\`\$\(\)\*] ]]; then # command injection protection
		log "ERROR" "core.sh" "Caught special characters (command injection protection)"
		printf "${RED_BOLD}Command injection protection is active, usage of special characters \" ;  &  |  >  <  \`  $  (  ) * \" is forbidden${RESET}\n"
		cmdExitCode=1
		return
	fi
	commandLineHandler "$@"
}
[ -n "$*" ] && {
	log "INFO" "core.sh" "Found command \"$*\" to execute"
	launchCommand "$@" # if there is any, execute the command provided by init.sh
	if ${Sett[AutoReturnOnPreCommands]}; then
		history -w
		history -c
		HISTFILE="$HOME/.bash_history"
		history -r
		set +x
		exit "$cmdExitCode"
	fi
}
log "INFO" "core.sh" "Entering shell loop!"
while true; do
	IFS=$IFSBak
	if [ "$cmdExitCode" -ne 0 ]; then # command exit code handling
		dispExitCode="${RL_START}${RED}${RL_END}${cmdExitCode}${RL_START}${RESET}${RL_END}|"
	else
		dispExitCode=""
	fi

	log "INFO" "core.sh" "Displaying shell"
	read -erp "${dispExitCode}SHlauncher ${DispProf}:${DispInst}> " commandLine # command prompt
	# shellcheck disable=SC2086
	[ -n "$commandLine" ] && launchCommand $commandLine
done