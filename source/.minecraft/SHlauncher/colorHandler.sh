# shellcheck disable=SC2034
# shellcheck disable=SC2154
log "INFO" "colorHandler.sh" "Started loading colors"
if $color; then
	if [ "${Sett[Color]}" = "use24bit" ] || $force_color; then
		RED=$'\033[38;2;255;20;9m'
		RED_BOLD=${RED}$'\033[1m'
		RED_DIM=${RED}$'\033[2m'
		RED_UNDER=${RED}$'\033[4m'

		GREEN=$'\033[38;2;0;255;0m'
		GREEN_BOLD=${GREEN}$'\033[1m'
		GREEN_DIM=${GREEN}$'\033[2m'
		GREEN_UNDER=${GREEN}$'\033[4m'

		YELLOW=$'\033[38;2;255;250;18m'
		YELLOW_BOLD=${YELLOW}$'\033[1m'
		YELLOW_DIM=${YELLOW}$'\033[2m'
		YELLOW_UNDER=${YELLOW}$'\033[4m'

		BLUE=$'\033[38;2;23;52;180m'
		BLUE_BOLD=${BLUE}$'\033[1m'
		BLUE_DIM=${BLUE}$'\033[2m'
		BLUE_UNDER=${BLUE}$'\033[4m'

		CYAN=$'\033[38;2;23;161;180m'
		CYAN_BOLD=${CYAN}$'\033[1m'
		CYAN_DIM=${CYAN}$'\033[2m'
		CYAN_UNDER=${CYAN}$'\033[4m'
		
		WHITE=$'\033[38;2;255;255;255m'
		WHITE_BOLD=${WHITE}$'\033[1m'
		WHITE_DIM=${WHITE}$'\033[2m'
		WHITE_UNDER=${WHITE}$'\033[4m'

    RESET=$'\033[0m'
	elif [ "${Sett[Color]}" = "use8" ]; then
		RED_BOLD=$'\e[1;31m'
		RED_DIM=$'\e[2;31m'
		RED_UNDER=$'\e[4;31m'
		RED=$'\e[31m'

		GREEN_BOLD=$'\e[1;32m'
		GREEN_DIM=$'\e[2;32m'
		GREEN_UNDER=$'\e[4;32m'
		GREEN=$'\e[32m'

		YELLOW_BOLD=$'\e[1;33m'
		YELLOW_DIM=$'\e[2;33m'
		YELLOW_UNDER=$'\e[4;33m'
		YELLOW=$'\e[33m'

		BLUE_BOLD=$'\e[1;34m'
		BLUE_DIM=$'\e[2;34m'
		BLUE_UNDER=$'\e[4;34m'
		BLUE=$'\e[34m'

		CYAN_BOLD=$'\e[1;36m'
		CYAN_DIM=$'\e[2;36m'
		CYAN_UNDER=$'\e[4;36m'
		CYAN=$'\e[36m'

		WHITE_BOLD=$'\e[1;37m'
		WHITE_DIM=$'\e[2;37m'
		WHITE_UNDER=$'\e[4;37m'
		WHITE=$'\e[37m'

    RESET=$'\033[0m'
	elif [ "${Sett[Color]}" = "NoColor" ]; then
		RED_BOLD=$'\033[1m'
		RED_DIM=$'\033[2m'
		RED_UNDER=$'\033[4m'
		RED=$'\033[0m'
	
		GREEN_BOLD=$'\033[1m'
		GREEN_DIM=$'\033[2m'
		GREEN_UNDER=$'\033[4m'
		GREEN=$'\033[0m'

		YELLOW_BOLD=$'\033[1m'
		YELLOW_DIM=$'\033[2m'
		YELLOW_UNDER=$'\033[4m'
		YELLOW=$'\033[0m'

		BLUE_BOLD=$'\033[1m'
		BLUE_DIM=$'\033[2m'
		BLUE_UNDER=$'\033[4m'
		BLUE=$'\033[0m'

		CYAN_BOLD=$'\033[1m'
		CYAN_DIM=$'\033[2m'
		CYAN_UNDER=$'\033[4m'
		CYAN=$'\033[0m'

		WHITE_BOLD=$'\033[1m'
		WHITE_DIM=$'\033[2m'
		WHITE_UNDER=$'\033[4m'
		WHITE=$'\O33[0m'

    RESET=$'\033[0m'
	fi
fi

log "INFO" "colorHandler.sh" "Colors loaded (${Sett[Color]})"
RL_START=$'\001'
RL_END=$'\002'
log "DEBUG" "colorHandler.sh" "Finished loading colors"
