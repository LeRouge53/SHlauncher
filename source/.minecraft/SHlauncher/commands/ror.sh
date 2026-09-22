case "$1" in
	"ror")
		log "ERROR" "ror.sh" "command is Return on return, can't operate"
		printf "${RED_BOLD}Please don't use the return on return command with itself"
		return 2
	;;
	"help")
		printf "${CYAN}Usage :${RESET} ror <command>\n"
		printf "Executes the provided command and exit the launcher afterwards\n"
		printf "to actually use help as a command, enter \"\\help\"\n"
        return
	;;
	'\help')
		commandLineHandler "help"
	;;
	"")
		printf "${RED_BOLD}A command is required, type \"ror help\""
	;;
	*)
		commandLineHandler "$@"
esac
history -w
history -c
HISTFILE="$HOME/.bash_history"
history -r
set +x
# shellcheck disable=SC2154
exit "$cmdExitCode"