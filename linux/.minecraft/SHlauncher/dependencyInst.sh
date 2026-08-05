#!/bin/bash
# shellcheck disable=SC2154
if $depFailed; then
	printf "${RED}[FATAL] Failed to lauch : The following dependency(ies) are missing :${RESET}\n"

	if $jqNotInstalled; then 
		echo "jq : JSON shell interpretor"
		read -rp "Would you like to install jq automatically ?(y/n)>" yn
	fi
	if [ "$yn" = "y" ]; then
		pkexec
		if [ "$EUID" -ne 0 ] ;then
			echo "[ERROR] You do not have admin privileges which are required to install the dependencies"
			echo "[ERROR] please run \"apt install jq\" in an administrative terminal and restart the launcher"
			exit 1
		fi
		if "$ONLINE_MODE"; then
			apt install jq
		else
			echo "[ERROR] Can't install, You are in offline mode"
		fi
	else
		echo "aborting autoinstall"
	fi
	set +x
	exit 1
fi