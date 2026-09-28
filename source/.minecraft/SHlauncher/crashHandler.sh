function terminate() {
	history -w 2>/dev/null # sometimes (this function can be called before HISTFILE is set. and it creates useless log)
	history -c
	HISTFILE="$HOME/.bash_history"
	history -r
	set +x
}
if type log &>/dev/null; then
	log "FATAL" "crashHandler.sh" "crashHandler called with code $1" # the script can be called very early, so I check if log is defined
fi
printf "${RED}SHlauncher has crashed! :${RESET}\n"
case $1 in 
	"CD_FAIL")
		# triggers if a cd command fails
		echo " The launcher crashe due to a working directory switch error."
		echo " - It could be due to insufficient authorizations, an incomplete installation or issues with the disk."
		terminate
		exit 2
	;;
	"SIGINT")
		# triggers if Ctrl+c is pressed
		echo " Received SIGINT (signal 2), forced to terminate."
		echo " - Do not press control+C"
		terminate
		exit 130
	;;
	"POSIX")
		# triggers if the script is launched with a posix shell
		echo " The launcher is currently being run by an incompatible POSIX shell (like sh, ash or dash)"
		echo " - Please use bash instead (or disable posix mode)"
		exit 3
	;;
	"ZSH")
		# triggers if the shell is launched with zsh
		echo " The launcher is currently being run by ZSH, which is not supported, use bash instead"
		exit 4
	;;
	"SETT_LOAD_FAIL")
		# triggers if settings.sh fails to load the settings 
		echo " The launcher failed to start because it failed to load the settings"
		echo " - There could be multiple causes for this error. Please check the log file"
		set +x
		exit 5
	;;
	"LIB_LOAD_FAIL")
		# triggers if any libraries failed to load for whatever reasons
		echo " The launcher failed to start because there was an error when loading a library. Check the log file for more info"
		echo " - This is most likely caused by missing files in the \".minecraft/SHlauncher/libs\" folder."
		echo " - This crash could also be autonomously triggered"
		set +x
		exit 6
	;;
	*)
		# everything else
		echo " The launcher crashed for an unspecified reason : $1."
		echo " - The log file probably contains more info"
		terminate
		exit 255
esac