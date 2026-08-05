#shellcheck shell=bash
# shellcheck disable=SC2059

function terminate() {
    history -w
    history -c
    HISTFILE="$HOME/.bash_history" # à remplacer par un système de backup
    history -r
    set +x
}

printf "${RED_BOLD}[FATAL]${RED} SHlauncher has crashed! :${RESET}\n"
case $1 in 
    "CD_FAIL")
        echo " The launcher failed to start due to a working directory switch error."
        echo " - It could be due to issuficient authorisations, the launcher being missinstalled or issues with the disk."
        terminate
        exit 2
    ;;
    "SIGINT")
        echo " Recieved SIGINT (signal 2), forced to terminate."
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
    *)
        echo " The launcher crashed for an unspecified reason : $1."
        terminate
        exit 255
esac