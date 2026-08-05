# shellcheck disable=SC2154

SettUse24bitColors=true
if $color; then
    if $SettUse24bitColors; then
        RED=$'\033[38;2;255;20;9m'
        RED_BOLD=${RED}$'\033[1m'

        GREEN=$'\033[38;2;0;255;0m'
        GREEN_BOLD=${GREEN}$'\033[1m'

        YELLOW=$'\033[38;2;255;250;18m'
        YELLOW_BOLD=${YELLOW}$'\033[1m'

        BLUE=$'\033[38;2;23;52;180m'
        BLUE_BOLD=${BLUE}$'\033[1m'

        CYAN=$'\033[38;2;23;161;180m'
        CYAN_BOLD=${CYAN}$'\033[1m'
    else
        RED_BOLD=$'\e[1;31m'
        RED=$'\e[31m'

        GREEN_BOLD=$'\e[1;32m'
        GREEN=$'\e[32m'

        YELLOW_BOLD=$'\e[1;33m'
        YELLOW=$'\e[33m'

        BLUE_BOLD=$'\e[1;34m'
        BLUE=$'\e[34m'

        CYAN_BOLD=$'\e[1;36m'
        CYAN=$'\e[36m'
    fi
else
    RED_BOLD=$'\033[0m'
    RED=$'\033[0m'
    
    GREEN_BOLD=$'\033[0m'
    GREEN=$'\033[0m'

    YELLOW_BOLD=$'\033[0m'
    YELLOW=$'\033[0m'

    BLUE_BOLD=$'\033[0m'
    BLUE=$'\033[0m'

    CYAN_BOLD=$'\033[0m'
    CYAN=$'\033[0m'
fi

RESET=$'\033[0m'
RL_START=$'\001'
RL_END=$'\002'
