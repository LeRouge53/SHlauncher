#!/bin/bash
# shellcheck disable=SC2154
if [ "${MissingDependencies[*]}" != "" ]; then
	printf "${RED}[FATAL] Failed to launch : The following dependency(ies) are missing :${RESET}\n"

	if [[ "${MissingDependencies[*]}" =~ jq ]]; then 
		echo "jq : JSON shell interpreter"
	fi
	if [[ "${MissingDependencies[*]}" =~ unzip ]]; then
		echo "unzip : ZIP file decompressor"
	fi

	read -rp "Would you like to install the dependencies automatically ?(y/n)>" yn
	if [ "$yn" = "y" ]; then
		if "$ONLINE_MODE"; then
			if [ "$osName" = "windows" ]; then
				[[ "${MissingDependencies[*]}" =~ jq ]] && {
					if ! exceptionCatch "dependencyInst.sh" pacman -S msys/jq; then
						printf "${RED_BOLD}Failed to install jq, check the log file for more info${RESET}\n"
					fi
				}
				[[ "${MissingDependencies[*]}" =~ unzip ]] && {
					if ! exceptionCatch "dependencyInst.sh" pacman -S msys/unzip; then
						printf "${RED_BOLD}Failed to install unzip, check the log file for more info${RESET}\n"
					fi
				}
			else
				printf "${YELLOW}Root access is required for installation${RESET}\n"
				[[ "${MissingDependencies[*]}" =~ jq ]] && { 
					if ! exceptionCatch "dependencyInst.sh" sudo apt install jq; then
						printf "${RED_BOLD}Failed to install jq, check the log file for more info${RESET}\n"
					fi
				}
				[[ "${MissingDependencies[*]}" =~ unzip ]] && {
					if ! exceptionCatch "dependencyInst.sh" sudo apt install unzip; then
						printf "${RED_BOLD}Failed to install unzip, check the log file for more info${RESET}\n"
					fi
				}
			fi
		else
			printf "${RED}Can't install, You are in offline mode${RESET}\n"
		fi
	else
		printf "aborting autoinstall\n"
	fi
	set +x
	exit 1
fi