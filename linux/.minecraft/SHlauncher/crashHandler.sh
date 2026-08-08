#shellcheck shell=bash
# shellcheck disable=SC2059

function terminate() {
	history -w
	history -c
	HISTFILE="$HOME/.bash_history"
	history -r
	set +x
}
log "FATAL" "crashHandler.sh" "crashHandler called with code $1"
printf "${RED}SHlauncher has crashed! :${RESET}\n"
case $1 in 
	"CD_FAIL")
		echo " The launcher failed to start due to a working directory switch error."
		echo " - It could be due to insufficient authorizations, an incomplete installation or issues with the disk."
		terminate
		exit 2
	;;
	"SIGINT")
		echo " Received SIGINT (signal 2), forced to terminate."
		echo " - Do not press control+C"
		terminate
		exit 130
	;;
	"POSIX")
		echo " The launcher is currently being run by an incompatible POSIX shell (like sh, ash or dash)"
		echo " - Please use bash or zsh instead (or disable posix mode if you are already using those)"
		terminate
		exit 3
	;;
	"WSL")
		echo " The launcher is currently being run on a Windows Substitute for Linux (WSL) operating system"
		echo " - This script is NOT compatible with WSL."
		echo " - Use git bash for Windows or a genuine linux distribution with the linux version of the script instead"
		terminate
		exit 4
	;;
	"SETT_LOAD_FAIL")
		echo " The launcher failed to start because it failed to load the main setting file (system.json)"
		echo " - This is most likely caused by an error during installation."
		echo " - please reinstall the launcher or restore the file located at \".minecraft/SHlauncher/settings/data/system.json\""
		terminate
		exit 5
	;;
	*)
		echo " The launcher crashed for an unspecified reason : $1."
		terminate
		exit 255
esac