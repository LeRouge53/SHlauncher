#!/bin/bash
# shellcheck disable=SC2154
if $depFailed; then
	printf "${RED}[FATAL] Failed to launch : The following dependency(ies) are missing :${RESET}\n"

	if $jqNotInstalled; then 
		echo "jq : JSON shell interpreter"
		read -rp "Would you like to install jq automatically ?(y/n)>" yn
	fi
	if [ "$yn" = "y" ]; then
		if "$ONLINE_MODE"; then
			if [ "$osName" = "windows" ]; then
				apt install jq
			else
				sudo apt install jq
			fi
		else
			echo "[ERROR] Can't install, You are in offline mode"
		fi
	else
		echo "aborting autoinstall"
	fi
	set +x
	exit 1
fi