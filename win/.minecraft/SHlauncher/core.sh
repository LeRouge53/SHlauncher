#shellcheck source=./commands/profile.sh
# shellcheck disable=SC2059

cd ./commands || ./crashHandler.sh CDFAIL
for Fprof in ../profiles/*.json; do
    if jq -e '.selected' "$Fprof" &>/dev/null; then profile=$(jq -r '.name' "$Fprof"); fi

    if jq -e '.isOnline' "$Fprof" &>/dev/null; then \
        DispProf="${RL_START}${BLUE}${RL_END}${profile}${RL_START}${RESET}${RL_END}"; else \
        DispProf="${RL_START}${YELLOW}${RL_END}${profile}${RL_START}${RESET}${RL_END}"; fi
done
if [ "$profile" == "" ]; then 
    profile="None"
    DispProf="${RL_START}${RED}${RL_END}${profile}${RL_START}${RESET}${RL_END}"
fi


for Finst in ../instances/*.json; do
    if jq -e '.selected' "$Finst" &>/dev/null; then instance=$(jq -r '.name' "$Finst"); fi
    DispInst=$'\001'"${GREEN}"$'\002'${instance}$'\001'"${RESET}"$'\002'
done
if [ "$instance" == "" ]; then 
    instance="None"
    DispInst=$'\001'"${RED}"$'\002'${instance}$'\001'"${RESET}"$'\002'
fi

lastCommandLine=""
while true; do
    # shellcheck disable=SC2154
    cd "$dir/.minecraft/SHlauncher/commands" || ./crashHandler.sh CDFAIL
    # shellcheck disable=SC2154
    IFS=$IFSBak
    read -erp "SHlauncher ${DispProf}:${DispInst}> " commandLine
    commandLine=$(trimCr "$commandLine")
    # shellcheck disable=SC2154
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
        "reset")
            # shellcheck disable=SC2164
            cd "$dir/"
            history -w
            set +x
            exec ./init.sh
        ;;
        "clear")
            clear
        ;;
        "launcherVers")
            # shellcheck disable=SC2154
            echo "$SHlname version $SHlvers"
        ;;
        "echo")
            echo "$1"
        ;;
        "")
            true # pas une erreur tkt
        ;;
        *)
            echo "Unknown command: $cmd"
    esac
done